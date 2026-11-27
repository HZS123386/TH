import 'dart:convert';
import 'dart:js_interop';
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
@JS('fateH5.trackActivity')
external void _activity(JSString payload, JSString key, JSString endpoint);
@JS('fateH5.trackFailure')
external void _failure(JSString path, JSString code, JSString method);
@JS('fateBoot.fail')
external void _startupFailed();
@JS('fateBoot.openingReportId')
external JSString? get _openingReportId;
@JS('fateH5.trackRuntime')
external void _runtimeError(JSString action);
@JS('fateH5.ownerKey')
external JSString? _ownerKey();
@JS('fateH5.visitContext')
external JSString _visitContext();
@JS('fateBirthForm.attach')
external void _attachBirthForm(JSString initial, JSFunction submit);
@JS('fateBirthForm.submitting')
external JSBoolean get _birthFormSubmitting;
@JS('fateBirthForm.setVisible')
external void _setBirthFormVisible(JSBoolean visible);
@JS('fateBirthForm.detach')
external void _detachBirthForm();

class WebBrowserPort implements BrowserPort {
  String? get openingReportId => _openingReportId?.toDart;
  void startupFailed() => _startupFailed();
  void trackFrameworkError(String? library) {
    final action = switch (library) {
      'widgets library' => 'runtime_flutter_widgets',
      'rendering library' => 'runtime_flutter_rendering',
      _ => 'runtime_flutter_framework',
    };
    try {
      _runtimeError(action.toJS);
    } catch (_) {
      // Flutter still handles the error when diagnostics are unavailable.
    }
  }

  @override
  bool get supportsLineApp {
    final navigator = web.window.navigator;
    final agent = navigator.userAgent;
    // iPadOS can identify itself as a Mac in desktop browsing mode.
    return RegExp(r'Android|iPhone|iPad|iPod').hasMatch(agent) ||
        (agent.contains('Macintosh') && navigator.maxTouchPoints > 1);
  }

  @override
  void openPage(String path, {bool sameTab = false}) {
    final url = Uri.base.resolve(path).toString();
    if (sameTab) {
      web.window.location.assign(url);
    } else {
      web.window.open(url, '_blank', 'noopener,noreferrer');
    }
  }

  @override
  String ownerKey() {
    final key = _ownerKey()?.toDart;
    if (key == null) throw const ApiFailure('storage');
    return key;
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
  void attachBirthForm(Json initial, Future<String> Function(Json) submit) {
    JSPromise<JSString> receive(JSString payload) => submit(
      object(jsonDecode(payload.toDart)),
    ).then((value) => value.toJS).toJS;
    _attachBirthForm(jsonEncode(initial).toJS, receive.toJS);
  }

  @override
  bool get birthFormSubmitting => _birthFormSubmitting.toDart;

  @override
  void setBirthFormVisible(bool visible) => _setBirthFormVisible(visible.toJS);

  @override
  void detachBirthForm() => _detachBirthForm();

  @override
  void trackActivity(String page, String action) {
    try {
      final visit = visitContext();
      if (visit.isEmpty) return;
      const base = String.fromEnvironment('FATE_API_BASE_URL');
      _activity(
        jsonEncode({
          ...visit,
          'activity': {'page': page, 'action': action},
        }).toJS,
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
      if (visitContext().isNotEmpty) {
        _failure(path.toJS, code.toJS, method.toJS);
      }
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
  Json visitContext() => object(jsonDecode(_visitContext().toDart));
}
