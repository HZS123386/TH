import 'dart:async';
import 'package:flutter/material.dart';
import '../core/browser_port.dart';
import '../core/models.dart';
import '../core/repository.dart';

class H5Controller extends ChangeNotifier {
  H5Controller(
    Json translations,
    this.repository,
    this.browser, {
    String language = 'th',
    this.loadTranslations,
    this.ensureFont,
    this.ensureTextFont,
  }) : _language = language,
       _translations = {language: translations} {
    repository.language = language;
    repository.visitContext = browser.visitContext;
    repository.onClientFailure = browser.trackFailure;
    welcomeOpen = true;
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
  static const noticeVersion = 'h5-data-use-3';
  static const _visitTimeout = Duration(seconds: 8);
  late bool welcomeOpen, noticeAccepted;
  bool welcomePortraitRevealed = false;
  bool landingPrepared = false;
  Future<void>? _visitRequest;
  Json _visit = {};
  final _events = <String, Future<bool>>{};
  final _background = CancelToken();
  AppLoginCode? _appLoginCode;
  String? _appLoginReport;
  Future<AppLoginCode>? _appLoginRequest;

  Future<AppLoginCode>? get currentAppLoginCode {
    final code = _appLoginCode;
    return _appLoginRequest ?? (code == null ? null : Future.value(code));
  }

  Future<AppLoginCode> requestAppLoginCode(
    String reportId, {
    bool refresh = false,
  }) {
    final cached = _appLoginCode;
    if (!refresh &&
        _appLoginReport == reportId &&
        cached != null &&
        !cached.expired) {
      return Future.value(cached);
    }
    return _appLoginRequest ??= repository
        .createAppLoginCode(reportId, _background)
        .then((code) {
          _appLoginReport = reportId;
          _appLoginCode = code;
          return code;
        })
        .whenComplete(() => _appLoginRequest = null);
  }

  void trackActivity(String page, [String action = 'view']) =>
      browser.trackActivity(page, action);

  void enterLanding() {
    landingPrepared = true;
    welcomeOpen = false;
    welcomePortraitRevealed = true;
    trackActivity('birth_form', 'enter_form');
    notifyListeners();
    unawaited(recordVisit());
    // Warm later place/report text after the welcome is already visible.
    unawaited(ensureFont?.call(language).catchError((_) {}));
  }

  void returnToWelcome() {
    browser.writeSetting('active-preview', '', session: true);
    if (welcomeOpen) return;
    welcomeOpen = true;
    welcomePortraitRevealed = false;
    notifyListeners();
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
  Copy reportCopy(LifeReport report) =>
      Copy(
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
    if (!['zh', 'th'].contains(language)) return false;
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
    browser.setLanguage(
      language,
      language == 'zh' ? '运程解析 · FATE' : 'วิเคราะห์ดวงชะตา · FATE',
    );
    notifyListeners();
    return true;
  }

  String message(Object error, {Copy? labels}) {
    final c = labels ?? copy;
    if (error is FormatException) return c.t('ui', 'badResult');
    if (error is ApiFailure) {
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
