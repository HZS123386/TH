import 'dart:async';
import 'package:flutter/material.dart';
import '../core/browser_port.dart';
import '../core/models.dart';
import '../core/repository.dart';

class H5Controller extends ChangeNotifier {
  H5Controller(
    this.translations,
    this.repository,
    this.browser, {
    String language = 'th',
    this.ensureFont,
  }) : _language = language {
    repository.language = language;
    welcomeOpen =
        browser.readSetting('fate-welcome-dismissed', session: true) != '1';
    returningVisitor = browser.readSetting('fate-welcome-seen') == '1';
    noticeAccepted =
        browser.readSetting('fate-data-use-version') == noticeVersion;
  }
  final Json translations;
  final ReportRepository repository;
  final BrowserPort browser;
  final Future<void> Function(String)? ensureFont;
  static const noticeVersion = 'h5-data-use-1';
  late bool welcomeOpen, noticeAccepted;
  late final bool returningVisitor;
  Future<void>? _visitRequest;
  Json _visit = {};
  final _events = <String>{};
  final _submissions = <String, Future<void>>{};
  final _background = CancelToken();

  void enterLanding() {
    welcomeOpen = false;
    browser.writeSetting('fate-welcome-seen', '1');
    browser.writeSetting('fate-welcome-dismissed', '1', session: true);
    notifyListeners();
    unawaited(recordVisit());
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

  Future<void> acceptDataUse() async {
    await repository.request(
      '/api/landing/consents',
      _background,
      body: {'notice_version': noticeVersion, 'granted': true},
    );
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
  Future<bool> changeLanguage(String language) async {
    if (!['zh', 'th'].contains(language)) return false;
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
      for (final group in ['experience', 'generation', 'ui', 'life']) {
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
