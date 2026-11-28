import 'dart:async';

import 'package:flutter/material.dart';

import '../core/browser_port.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'languages.dart';

class H5Controller extends ChangeNotifier {
  H5Controller(
    Json translations,
    this.repository,
    this.browser, {
    String language = 'th',
    this.loadTranslations,
    this.ensureFont,
    this.ensureTextFont,
    this.ensureReportFont,
  }) : _language = h5Language(language),
       _translations = {h5Language(language): translations} {
    repository.language = _language;
    repository.visitContext = browser.visitContext;
    repository.onClientFailure = browser.trackFailure;
    noticeAccepted =
        browser.readSetting('fate-data-use-version') == noticeVersion;
  }
  final Map<String, Json> _translations;
  final Future<Json> Function(String)? loadTranslations;
  Json get translations => _translations[_language]!;
  final ReportRepository repository;
  final BrowserPort browser;
  final Future<void> Function(String)? ensureFont;
  final Future<void> Function(String, String)? ensureTextFont;
  final Future<void> Function(String)? ensureReportFont;
  static const noticeVersion = 'h5-data-use-3';
  static const _visitTimeout = Duration(seconds: 8);
  late bool noticeAccepted;
  Json? landingInput;
  Place? landingPlace;
  LifeReport? _generatedPreview;
  Future<void>? _visitRequest;
  Json _visit = {};
  final _events = <String, Future<bool>>{};
  final _background = CancelToken();
  void trackActivity(String page, [String action = 'view']) =>
      browser.trackActivity(page, action);

  void stageGeneratedPreview(LifeReport report) => _generatedPreview = report;

  LifeReport? takeGeneratedPreview(String id) {
    final report = _generatedPreview;
    _generatedPreview = null;
    return report?.id == id && report?.language == language ? report : null;
  }

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
  }

  Future<void> prepareText(String value, {String? language}) async {
    await ensureTextFont?.call(language ?? this.language, value);
  }

  void warmReportFont() {
    final load = ensureReportFont;
    if (language == 'zh' && load != null) {
      unawaited(load(language).catchError((_) {}));
    }
  }

  Future<void> recordVisit() async {
    if (_visit.isNotEmpty) return;
    final request = _visitRequest ??= _recordVisit();
    try {
      await request;
    } finally {
      if (identical(_visitRequest, request)) _visitRequest = null;
    }
  }

  Future<void> _recordVisit() async {
    try {
      final value = browser.visitContext();
      if (value.isEmpty) return;
      await repository.request(
        '/api/landing/visits',
        _background,
        body: value,
        timeout: _visitTimeout,
      );
      _visit = value;
    } catch (_) {
      // First-party counts are best effort and never delay report generation.
    }
  }

  Future<void> trackReport(String id, String event) async {
    if (event == 'seen' &&
        _events.containsKey('submitted:$id') &&
        !await _recordReportEvent(id, 'submitted')) {
      return;
    }
    await _recordReportEvent(id, event);
  }

  Future<bool> _recordReportEvent(String id, String event) async {
    final key = '$event:$id';
    final previous = _events[key];
    if (previous != null) {
      if (await previous) return true;
      if (!identical(_events[key], previous)) return _events[key]!;
    }
    return _events[key] = _sendReportEvent(id, event);
  }

  Future<bool> _sendReportEvent(String id, String event) async {
    await recordVisit();
    if (_visit.isEmpty) return false;
    try {
      final result = object(
        await repository.request(
          '/api/landing/visits/${_visit['id']}/events',
          _background,
          body: {'report_id': id, 'event': event},
          timeout: _visitTimeout,
        ),
      );
      return result['recorded'] == true;
    } catch (_) {
      // The report remains usable when traffic counting is unavailable.
      return false;
    }
  }

  Future<void> acceptDataUse() async {
    final config = object(
      await repository.request(
        '/api/landing/config',
        _background,
        owned: false,
      ),
    );
    if (text(config['notice_version']).isEmpty) {
      throw const ApiFailure('landing_consent_failed');
    }
    if (config['notice_version'] != noticeVersion) {
      throw const ApiFailure('landing_notice_outdated', status: 409);
    }
    final result = object(
      await repository.request(
        '/api/landing/consents',
        _background,
        body: {'notice_version': noticeVersion, 'granted': true},
      ),
    );
    if (result['accepted'] != true ||
        result['notice_version'] != noticeVersion) {
      throw const ApiFailure('landing_consent_failed');
    }
    browser.writeSetting('fate-data-use-version', noticeVersion);
    noticeAccepted = true;
    notifyListeners();
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
  Copy reportCopy(LifeReport report) => Copy(
    _translations[report.language] ?? translations,
    report.language,
  ).forReport(report);

  Future<Json> _copyForLanguage(String language) async {
    final cached = _translations[language];
    if (cached != null) return cached;
    final load = loadTranslations;
    return _translations[language] = load == null
        ? translations
        : await load(language);
  }

  Future<bool> changeLanguage(String language) async {
    if (!h5Languages.any((item) => item.$1 == language)) return false;
    final revision = ++_languageRevision;
    if (language == _language && !languageLoading) return true;
    languageLoading = true;
    notifyListeners();
    try {
      await (
        _copyForLanguage(language),
        ensureFont?.call(language) ?? Future<void>.value(),
      ).wait;
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
      if (error.code == 'life_personal_time_required') {
        return c.t('jy', 'personal.timeUnknown');
      }
      if (error.code == 'life_personal_periods_unavailable') {
        return c.t('jy', 'personal.unavailable');
      }
      for (final group in [
        'checkout',
        'experience',
        'generation',
        'ui',
        'life',
      ]) {
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
