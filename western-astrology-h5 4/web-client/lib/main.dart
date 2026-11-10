import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app/controller.dart';
import 'app/h5_app.dart';
import 'core/browser_web.dart';
import 'core/models.dart';
import 'core/repository.dart';
import 'ui/language_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final browser = WebBrowserPort();
  final language = Uri.base.queryParameters['lang'] == 'zh' ? 'zh' : 'th';
  final translations = object(
    jsonDecode(await rootBundle.loadString('assets/copy.json')),
  );
  final fonts = LanguageFonts();
  await fonts.ensure(language);
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
    ensureFont: fonts.ensureCommon,
    ensureTextFont: fonts.ensureText,
  );
  browser.setLanguage(
    language,
    language == 'zh' ? '运程解析 · FATE' : 'วิเคราะห์ดวงชะตา · FATE',
  );
  runApp(H5App(controller: controller));
}
