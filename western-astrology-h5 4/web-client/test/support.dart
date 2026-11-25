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

Json marriageFixture({Json? input, bool full = false}) {
  final data = fixture();
  final submitted =
      input ?? {...object(data['input']), 'report_kind': 'marriage'};
  final copy = Copy(
    translations(),
    text(object(submitted['profile'])['language']),
  );
  final titles = copy.list('marriage', 'full');
  final freeTitles = copy.list('marriage', 'preview');
  data.remove('generation_progress');
  data.addAll({
    'input': submitted,
    'title': copy.t('marriage', 'title'),
    'format': 'thai-marriage',
    'version': 'thai-marriage-1',
    'preview': null,
    'chapters': <Json>[],
    'plan': null,
    'preview_state': 'ready',
    'full_state': full ? 'ready' : 'not_started',
    'access': full ? 'full' : 'preview',
    'progress': {
      'total': marriageKeys.length,
      'completed': full ? marriageKeys.length : 0,
    },
    'catalog': [
      for (var i = 0; i < marriageKeys.length; i++)
        {'key': marriageKeys[i], 'title': titles[i], 'ready': full},
    ],
    'marriage': {
      'preview': [
        for (var i = 0; i < marriagePreviewKeys.length; i++)
          {
            'key': marriagePreviewKeys[i],
            'title': freeTitles[i],
            'paragraphs': ['Free marriage section ${i + 1}.'],
          },
      ],
      'full': full
          ? [
              for (var i = 0; i < marriageKeys.length; i++)
                {
                  'key': marriageKeys[i],
                  'title': titles[i],
                  'paragraphs': ['Paid marriage section ${i + 1}.'],
                },
            ]
          : null,
    },
    if (object(submitted['profile'])['birth_time'] == null) ...{
      'chart': null,
      'time_accuracy': {'mode': 'estimated', 'assumed_local_time': null},
    },
  });
  return data;
}

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
  bool supportsLineApp = false;
  @override
  Duration get welcomeAge => Duration.zero;
  @override
  void openPage(String path, {bool sameTab = false}) {
    openedPages.add(path);
    if (sameTab) sameTabPages.add(path);
  }
  final sameTabPages = <String>[];
  final settings = <String, String>{'fate-data-use-version': 'h5-data-use-3'};
  Json visit = {};
  @override
  String? readSetting(String key, {bool session = false}) =>
      settings[session ? 'session:$key' : key];
  @override
  void writeSetting(String key, String value, {bool session = false}) =>
      settings[session ? 'session:$key' : key] = value;
  @override
  Json visitContext() => visit;
  final activities = <Json>[];
  @override
  void trackViewReadingClick() {}

  @override
  void trackActivity(String page, String action) =>
      activities.add({'page': page, 'action': action});
  @override
  void trackFailure(String path, String code, String method) =>
      activities.add({'path': path, 'code': code, 'method': method});
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
