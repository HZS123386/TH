import 'dart:convert';
import 'dart:io';
import 'package:fate_h5/core/browser_port.dart';
import 'package:fate_h5/core/models.dart';

Json fixture({String language = 'zh', bool full = false}) => object(
  jsonDecode(
    File(
      'test/fixtures/$language-${full ? 'full' : 'preview'}.json',
    ).readAsStringSync(),
  ),
);
Json translations() =>
    object(jsonDecode(File('assets/copy.json').readAsStringSync()));

class TestBrowser implements BrowserPort {
  final settings = <String, String>{
    'session:fate-welcome-dismissed': '1',
    'fate-data-use-version': 'h5-data-use-1',
  };
  Json visit = {};
  @override
  String? readSetting(String key, {bool session = false}) =>
      settings[session ? 'session:$key' : key];
  @override
  void writeSetting(String key, String value, {bool session = false}) =>
      settings[session ? 'session:$key' : key] = value;
  @override
  Json visitContext() => visit;
  String key = List.filled(48, 'a').join();
  String title = '', locale = '';
  Json? exported;
  String? exportFormat;
  @override
  String ownerKey() => key;
  @override
  String today(String zone) => '2026-11-10';
  @override
  bool get visible => true;
  @override
  void setLanguage(String language, String value) {
    locale = language;
    title = value;
  }

  @override
  Future<String> exportDocument(LifeReport report, String format) async {
    exported = report.exportPayload();
    exportFormat = format;
    return 'downloaded';
  }

  @override
  void postPayment(String action, Map<String, String> fields) {}
  @override
  void pageReady(String page) {}
}
