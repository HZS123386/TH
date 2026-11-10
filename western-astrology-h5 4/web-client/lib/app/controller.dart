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
  }
  final Json translations;
  final ReportRepository repository;
  final BrowserPort browser;
  final Future<void> Function(String)? ensureFont;
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
      for (final group in ['generation', 'ui', 'life']) {
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
