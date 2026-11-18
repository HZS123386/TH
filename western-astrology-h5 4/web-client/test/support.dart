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

Json personalFixture({String language = 'zh', bool full = false}) {
  final data = fixture(language: language);
  data.addAll({
    'format': 'western-personal',
    'version': 'western-personal-8',
    'preview': null,
    'chapters': <Json>[],
    'plan': null,
    'preview_state': 'ready',
    'full_state': full ? 'ready' : 'not_started',
    'access': full ? 'full' : 'preview',
    'price': {
      'amount': 3000,
      'currency': 'THB',
      'display': '฿30',
      'mode': 'sunlands_order_only',
    },
    'progress': {
      'completed': full ? personalKeys.length : 0,
      'total': personalKeys.length,
    },
    'catalog': [
      for (final key in personalKeys)
        {
          'key': key,
          'title': key,
          'questions': <String>[],
          'houses': <int>[],
          'ready': full,
        },
    ],
    'personal': {
      'relationship': {
        'text':
            'A distinct view of closeness, needs and relationship boundaries.',
        'action':
            'Ask which pace of contact feels comfortable for both people.',
        'evidence': [
          for (var i = 0; i < 2; i++)
            {
              'id': 'relationship-$i',
              'title': 'Relationship factor $i',
              'detail': 'Verified natal relationship factor $i',
            },
        ],
      },
      'free_lines': [
        'Synthetic free line one.',
        'Synthetic free line two.',
        'Synthetic free line three.',
      ],
      'traits': [
        for (var i = 0; i < 3; i++)
          {'title': 'Personal trait $i', 'text': 'Everyday behavior $i.'},
      ],
      'opportunity_action': 'Prepare one example to share.',
      'sun_sign': 'Cancer',
      'ascendant_sign': 'Leo',
      'availability': {'full_report': true, 'reason': 'ready'},
      'talent': full
          ? {
              'text': 'Synthetic personal talent.',
              'directions': [
                for (var i = 0; i < 3; i++)
                  {
                    'title': 'Direction $i',
                    'text': 'Synthetic direction detail $i.',
                  },
              ],
            }
          : null,
      'themes': full
          ? {
              for (final key in ['wealth', 'love', 'risk'])
                key: {
                  'text': 'Synthetic $key reading.',
                  'evidence': [
                    for (var i = 0; i < 2; i++)
                      {
                        'id': '$key-$i',
                        'title': 'Factor $i',
                        'detail': 'Verified natal factor $i',
                      },
                  ],
                },
            }
          : null,
      'nodes': full
          ? [
              for (var i = 1; i <= 3; i++)
                {
                  'month': '2027-0$i',
                  'theme': 'Synthetic theme $i',
                  'benefit': 'Synthetic benefit $i',
                  'caution': 'Synthetic gentle reminder $i',
                  'action': 'Synthetic small action $i',
                  'evidence': <Json>[],
                },
            ]
          : <Json>[],
    },
  });
  data.remove('generation_progress');
  return data;
}

class TestBrowser implements BrowserPort {
  final openedPages = <String>[];
  @override
  void openPage(String path) => openedPages.add(path);
  final settings = <String, String>{
    'session:fate-welcome-dismissed': '1',
    'fate-data-use-version': 'h5-data-use-2',
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
