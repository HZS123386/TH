import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:web/web.dart' as web;
import 'browser_port.dart';
import 'models.dart';
import 'repository.dart';

@JS('fateH5.today')
external JSString _today(JSString zone);
@JS('fateH5.exportDocument')
external JSPromise<JSString> _export(JSString payload, JSString format);
@JS('fateH5.postPayment')
external void _payment(JSString action, JSString fields);
@JS('fateH5.pageReady')
external void _ready(JSString page);
@JS('fateH5.welcomeAge')
external JSNumber _welcomeAge();
@JS('fateH5.trackActivity')
external void _activity(JSString payload, JSString key, JSString endpoint);
@JS('fateH5.trackFailure')
external void _failure(JSString path, JSString code, JSString method);
@JS('fateBoot.fail')
external void _startupFailed();
@JS('fateBoot.connectWelcome')
external void _connectWelcome(JSFunction enter);
@JS('navigator.globalPrivacyControl')
external JSBoolean? get _privacyControl;
@JS('navigator.doNotTrack')
external JSString? get _doNotTrack;

class WebBrowserPort implements BrowserPort {
  final _entryUrl = Uri.base;
  Json? _visitContext;

  void startupFailed() => _startupFailed();
  void connectWelcome(void Function() enter) => _connectWelcome(enter.toJS);

  @override
  Duration get welcomeAge =>
      Duration(microseconds: (_welcomeAge().toDartDouble * 1000).round());

  @override
  void openPage(String path) => web.window.open(
    Uri.base.resolve(path).toString(),
    '_blank',
    'noopener,noreferrer',
  );
  String? _key;
  @override
  String ownerKey() {
    const name = 'astro-life-report-key';
    final stores = <web.Storage>[];
    for (final read in [
      () => web.window.localStorage,
      () => web.window.sessionStorage,
    ]) {
      try {
        final store = read(), saved = store.getItem(name);
        stores.add(store);
        if (_key == null &&
            saved != null &&
            RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(saved)) {
          _key = saved;
        }
      } catch (_) {
        /* Another browser store may still be writable. */
      }
    }
    _key ??= List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    var persisted = false;
    for (final store in stores) {
      try {
        if (store.getItem(name) != _key) store.setItem(name, _key!);
        persisted |= store.getItem(name) == _key;
      } catch (_) {
        /* Preserve a readable existing key. */
      }
    }
    if (!persisted) {
      _key = null;
      throw const ApiFailure('storage');
    }
    return _key!;
  }

  @override
  String today(String zone) => _today(zone.toJS).toDart;
  @override
  bool get visible => web.document.visibilityState == 'visible';
  @override
  void setLanguage(String language, String title) {
    web.document.documentElement?.setAttribute('lang', language);
    web.document.title = title;
  }

  @override
  Future<String> exportDocument(LifeReport report, String format) async =>
      (await _export(
        jsonEncode(report.exportPayload()).toJS,
        format.toJS,
      ).toDart).toDart;
  @override
  void postPayment(String action, Map<String, String> fields) =>
      _payment(action.toJS, jsonEncode(fields).toJS);
  @override
  void pageReady(String page) => _ready(page.toJS);

  @override
  void trackActivity(String page, String action) {
    try {
      final visit = visitContext();
      if (visit.isEmpty) return;
      const base = String.fromEnvironment('FATE_API_BASE_URL');
      _activity(
        jsonEncode({...visit, 'activity': {'page': page, 'action': action}}).toJS,
        ownerKey().toJS,
        '$base/api/landing/visits'.toJS,
      );
    } catch (_) {
      // Optional traffic recording must never interrupt a report or payment.
    }
  }

  @override
  void trackFailure(String path, String code, String method) {
    try {
      if (visitContext().isNotEmpty) _failure(path.toJS, code.toJS, method.toJS);
    } catch (_) {
      // Diagnostics must not change the original request result.
    }
  }

  @override
  String? readSetting(String key, {bool session = false}) {
    try {
      return (session ? web.window.sessionStorage : web.window.localStorage)
          .getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void writeSetting(String key, String value, {bool session = false}) {
    try {
      (session ? web.window.sessionStorage : web.window.localStorage).setItem(
        key,
        value,
      );
    } catch (_) {
      // Optional preferences must not block the report's existing storage check.
    }
  }

  @override
  Json visitContext() {
    if (_privacyControl?.toDart == true || _doNotTrack?.toDart == '1') {
      return {};
    }
    if (_visitContext != null) return _visitContext!;
    String tag(String name) => (_entryUrl.queryParameters[name] ?? '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_.~-]'), '')
        .split('')
        .take(64)
        .join();
    final source = tag('utm_source');
    final campaign = tag('utm_campaign');
    final regionTag = _entryUrl.queryParameters['utm_region']
        ?.trim()
        .toUpperCase();
    final region =
        regionTag != null && RegExp(r'^[A-Z]{2}$').hasMatch(regionTag)
        ? regionTag
        : null;
    final tagged = source.isNotEmpty || campaign.isNotEmpty || region != null;
    const storageKey = 'fate-visit-context';
    Json previous = {};
    try {
      previous = object(
        jsonDecode(readSetting(storageKey, session: true) ?? '{}'),
      );
    } on FormatException {
      // A corrupted session setting must not interrupt the report flow.
    }
    if (text(previous['id']).isNotEmpty &&
        (!tagged ||
            (previous['source'] == source &&
                previous['campaign'] == campaign &&
                previous['region'] == region))) {
      return _visitContext = previous;
    }
    // A different tagged entry in the same tab is a separate visit.
    var id = tagged ? null : readSetting('fate-visit', session: true);
    if (id == null) {
      final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
      id =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    }
    final context = <String, dynamic>{
      'id': id,
      'source': source,
      'campaign': campaign,
      if (region != null) 'region': region,
    };
    writeSetting(storageKey, jsonEncode(context), session: true);
    return _visitContext = context;
  }
}
