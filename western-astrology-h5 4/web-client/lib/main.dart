import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app/controller.dart';
import 'app/h5_app.dart';
import 'app/languages.dart';
import 'core/browser_web.dart';
import 'core/models.dart';
import 'core/repository.dart';
import 'ui/language_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final browser = WebBrowserPort();
  try {
    await _startApp(browser);
  } catch (error, stack) {
    browser.startupFailed();
    Error.throwWithStackTrace(error, stack);
  }
}

Future<Json> _loadTranslations(String language) async {
  for (var attempt = 0; ; attempt++) {
    try {
      // Do not reuse a failed loadString future from the asset bundle cache.
      final translations = object(
        jsonDecode(
          await rootBundle.loadString('assets/copy/$language.json', cache: false),
        ),
      );
      if (object(translations['jy'])[language] is! Map) {
        throw const FormatException('Missing H5 translations');
      }
      return translations;
    } catch (_) {
      if (attempt == 2) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
  }
}

Future<void> _startApp(WebBrowserPort browser) async {
  usePathUrlStrategy();
  final language = h5Language(Uri.base.queryParameters['lang']);
  final fonts = LanguageFonts();
  // Both are required before runApp, but neither depends on the other's result.
  final (translations, _) = await (
    _loadTranslations(language),
    fonts.ensure(language),
  ).wait;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans Thai',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL-CJK.txt'));
    yield LicenseEntryWithLineBreaks([
      'Noto Sans Symbols',
      'Noto Sans Symbols 2',
    ], await rootBundle.loadString('assets/fonts/OFL-Symbols.txt'));
    for (final script in ['Myanmar', 'Khmer', 'Lao']) {
      yield LicenseEntryWithLineBreaks([
        'Noto Sans $script',
      ], await rootBundle.loadString('assets/fonts/OFL-$script.txt'));
    }
  });
  final repository = ReportRepository(
    browser,
    baseUrl: const String.fromEnvironment('FATE_API_BASE_URL'),
  );
  final controller = H5Controller(
    translations,
    repository,
    browser,
    language: language,
    loadTranslations: _loadTranslations,
    ensureFont: fonts.ensure,
    ensureTextFont: fonts.ensureText,
    ensureReportFont: fonts.ensureCommon,
  );
  browser.setLanguage(language, controller.copy.t('jy', 'title'));
  runApp(H5App(controller: controller));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized
          .then((_) => fonts.warmSwitchLanguages())
          .catchError((_) {}),
    );
  });
}
