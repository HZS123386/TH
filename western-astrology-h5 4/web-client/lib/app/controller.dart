import 'dart:async';
import 'package:flutter/material.dart';
import '../core/browser_port.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'languages.dart';

class H5Controller extends ChangeNotifier {
  H5Controller(
    this.translations,
    this.repository,
    this.browser, {
    String language = 'th',
    this.ensureFont,
    this.ensureTextFont,
  }) : _language = h5Language(language) {
    repository.language = _language;
    welcomeOpen = true;
    returningVisitor = browser.readSetting('fate-welcome-seen') == '1';
    browser.writeSetting('fate-welcome-seen', '1');
  }
  final Json translations;
  final ReportRepository repository;
  final BrowserPort browser;
  final Future<void> Function(String)? ensureFont;
  final Future<void> Function(String, String)? ensureTextFont;
  late bool welcomeOpen;
  late final bool returningVisitor;
  bool welcomePortraitRevealed = false;
  bool landingPrepared = false;
  Json? landingInput;
  Place? landingPlace;
  Future<void>? _visitRequest;
  Json _visit = {};
  final _events = <String>{};
  final _submissions = <String, Future<void>>{};
  final _background = CancelToken();

  void restoreLandingFromReport(LifeReport? report) {
    if (report != null) {
      landingInput = report.input;
      final location = object(report.json['location']);
      final profile = report.profile;
      landingPlace = Place({
        ...location,
        'id': text(profile['location_id']).isNotEmpty
            ? profile['location_id']
            : text(location['id']),
        'countryCode': text(location['countryCode']).isNotEmpty
            ? location['countryCode']
            : text(profile['country_code']).isNotEmpty
            ? profile['country_code']
            : text(location['country']),
        'timeZone': profile['timezone'] ?? location['timeZone'],
        'nameEnglish': text(location['nameEnglish']).isEmpty
            ? profile['birthplace']
            : location['nameEnglish'],
      });
    }
    enterLanding();
  }

  void enterLanding() {
    landingPrepared = true;
    welcomeOpen = false;
    welcomePortraitRevealed = true;
    notifyListeners();
    unawaited(recordVisit());
    // Warm later place/report text after the welcome is already visible.
    unawaited(ensureFont?.call(language).catchError((_) {}));
  }

  void prepareLanding() {
    if (landingPrepared) return;
    landingPrepared = true;
    notifyListeners();
  }

  Future<void> prepareText(String value, {String? language}) async {
    await ensureTextFont?.call(language ?? this.language, value);
  }

  void revealLandingPortrait() {
    if (welcomePortraitRevealed) return;
    welcomePortraitRevealed = true;
    notifyListeners();
  }

  Future<void> recordVisit() => _visitRequest ??= _recordVisit();
  Future<void> _recordVisit() async {
    try {
      final value = browser.visitContext();
      if (value.isEmpty) return;
      await repository.request('/api/landing/visits', _background, body: value);
      _visit = value;
    } catch (_) {
      // First-party counts are best effort and never delay report generation.
    }
  }

  Future<void> trackReport(String id, String event) async {
    if (event == 'submitted') {
      await _submissions.putIfAbsent(id, () => _sendReportEvent(id, event));
      return;
    }
    await _submissions[id];
    await _sendReportEvent(id, event);
  }

  Future<void> _sendReportEvent(String id, String event) async {
    await recordVisit();
    if (_visit.isEmpty || !_events.add('$event:$id')) return;
    try {
      await repository.request(
        '/api/landing/visits/${_visit['id']}/events',
        _background,
        body: {'report_id': id, 'event': event},
      );
    } catch (_) {
      // The report remains usable when traffic counting is unavailable.
    }
  }

  @override
  void dispose() {
    _background.cancel();
    super.dispose();
  }

  bool languageLoading = false;
  int _languageRevision = 0;
  String _language;
  String get language => _language;
  Copy get copy => Copy(translations, language);
  Future<bool> changeLanguage(String language) async {
    if (!h5Languages.any((item) => item.$1 == language)) return false;
    final revision = ++_languageRevision;
    if (language == _language && !languageLoading) return true;
    languageLoading = true;
    notifyListeners();
    try {
      await ensureFont?.call(language);
    } catch (_) {
      if (revision == _languageRevision) {
        languageLoading = false;
        notifyListeners();
      }
      return false;
    }
    if (revision != _languageRevision) return false;
    languageLoading = false;
    _language = language;
    repository.language = language;
    browser.setLanguage(language, copy.t('jy', 'title'));
    notifyListeners();
    return true;
  }

  String message(Object error, {Copy? labels}) {
    final c = labels ?? copy;
    if (error is FormatException) return c.t('ui', 'badResult');
    if (error is ApiFailure) {
      for (final group in ['checkout', 'experience', 'generation', 'ui', 'life']) {
        final value = c.t(group, error.code);
        if (value.isNotEmpty) return value;
      }
      if (error.status == 404) return c.t('generation', 'missing');
      if (error.status == 429) return c.t('generation', 'busy');
      if (error.status == 422) return c.t('ui', 'badResult');
      return c.t('ui', 'network');
    }
    return c.t('ui', 'network');
  }
}

class H5Scope extends InheritedNotifier<H5Controller> {
  const H5Scope({
    required H5Controller controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static H5Controller of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<H5Scope>()!.notifier!;
}
