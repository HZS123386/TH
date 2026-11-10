import 'dart:convert';

typedef Json = Map<String, dynamic>;
Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> objects(dynamic value) =>
    value is List ? value.map(object).toList() : [];
String text(dynamic value) => value is String ? value : '';
const fortuneKeys = [
  'annual',
  'overall',
  'pattern',
  'marriage',
  'wealth',
  'risk',
  'romance',
];
const previewKeys = [
  'preview_summary',
  'preview_strength',
  'preview_decisions',
  'preview_relationships',
];

class Copy {
  const Copy(this.data, this.language);
  final Json data;
  final String language;
  dynamic value(String group, String path) {
    dynamic current = object(data[group])[language];
    for (final key in path.split('.')) {
      current = current is Map ? current[key] : null;
    }
    return current;
  }

  String t(String group, String path) => text(value(group, path));
  List<String> list(String group, String path) =>
      (value(group, path) as List? ?? []).map((v) => '$v').toList();
  List<Json> get topics => objects(data['topics']);
  Copy forLanguage(String language) => Copy(data, language);
  Copy forReport(LifeReport report) {
    final language = report.language;
    final labels = <String, dynamic>{
      ...object(object(data['life'])[language]),
      if (report.input['report_kind'] == 'fortune')
        ...object(object(data['fortune'])[language]),
      if (report.career) ...object(object(data['career'])[language]),
    };
    final question = object(report.input['career_question']);
    if (question.isNotEmpty) {
      final situation = object(
        object(
          object(object(data['career'])[language])['situations'],
        )[question['stage']],
      );
      labels['careerQuestionTitle'] = text(
        question['focus'] != null
            ? object(situation['details'])[question['focus']]
            : situation['question'],
      );
    }
    if (report.career) {
      final career = object(report.input['career']);
      final situation = object(
        object(
          object(object(data['career'])[language])['situations'],
        )[career['stage']],
      );
      labels['title'] = career['focus'] != null
          ? text(object(situation['details'])[career['focus']])
          : text(report.json['title']);
    }
    return Copy({
      ...data,
      'report': {language: labels},
    }, language);
  }

  String topicTitle(Json topic, int year) => topic['key'] == 'annual'
      ? language == 'zh'
            ? '$year年运程'
            : 'ดวงปี $year'
      : text(object(topic[language])['title']);
}

class Place {
  Place(this.json);
  final Json json;
  String get id => text(json['id']);
  String get country => text(json['countryCode']);
  String get zone => text(json['timeZone']);
  String get english => text(json['nameEnglish']);
  String get provinceId => text(json['provinceId']);
  String name(String language) =>
      text(json[language == 'zh' ? 'nameChinese' : 'nameThai']).isNotEmpty
      ? text(json[language == 'zh' ? 'nameChinese' : 'nameThai'])
      : english;
  bool get representative =>
      json['placeType'] == 'province' ||
      json['coordinateKind'] == 'representative' ||
      json['coordinateKind'] == 'administrative-area';
  String label(String language) =>
      text(json[language == 'zh' ? 'labelChinese' : 'labelThai']).isNotEmpty
      ? text(json[language == 'zh' ? 'labelChinese' : 'labelThai'])
      : text(json[language == 'zh' ? 'nameChinese' : 'nameThai']).isNotEmpty
      ? text(json[language == 'zh' ? 'nameChinese' : 'nameThai'])
      : english;
  bool matches(String query) => [
    json['nameEnglish'],
    json['nameChinese'],
    json['nameThai'],
    ...(json['aliases'] as List? ?? []),
  ].any((v) => '$v'.toLowerCase().contains(query.trim().toLowerCase()));
}

String inputSignature(Json input) {
  final p = object(input['profile']),
      career = object(input['career']),
      question = object(input['career_question']);
  return jsonEncode([
    for (final key in [
      'birth_date',
      'birth_time',
      'birthplace',
      'timezone',
      'language',
      'country_code',
      'location_id',
      'latitude',
      'longitude',
    ])
      p[key],
    input['year'],
    career['stage'],
    career['start'],
    career['focus'],
    question['stage'],
    question['start'],
    question['focus'],
    input['user_question'],
    input['report_kind'],
  ]);
}

class LifeReport {
  LifeReport._(this.json);
  final Json json;
  String get id => text(json['id']);
  Json get input => object(json['input']);
  Json get profile => object(input['profile']);
  String get language => text(profile['language']);
  bool get full => json['access'] == 'full';
  bool get ready =>
      full &&
      json['full_state'] == 'ready' &&
      json['preview_state'] == 'ready' &&
      preview.isNotEmpty &&
      object(json['progress'])['completed'] ==
          object(json['progress'])['total'];
  bool get career => input['career'] != null;
  Json get preview => object(json['preview']);
  List<Json> get catalog => objects(json['catalog']);
  List<Json> get chapters => full ? objects(json['chapters']) : [];
  Json get plan => full ? object(json['plan']) : {};
  Json get price => object(json['price']);
  String get priceLabel => text(price['display']);
  bool get estimated => object(json['time_accuracy'])['mode'] == 'estimated';
  List<String> get progressKeys => career
      ? ['work']
      : input['report_kind'] == 'fortune'
      ? [...fortuneKeys, 'plan']
      : ['work', 'money', 'relationships', 'annual', 'plan'];
  static LifeReport parse(dynamic value, {String? id, Json? expectedInput}) {
    final row = object(value),
        input = object(row['input']),
        profile = object(input['profile']);
    final catalog = objects(row['catalog']), progress = object(row['progress']);
    final language = profile['language'];
    final price = object(row['price']);
    final expectedCount = input['career'] != null
        ? 1
        : input['report_kind'] == 'fortune'
        ? 7
        : 5;
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(text(row['id'])) ||
        !['zh', 'th'].contains(language) ||
        (id != null && row['id'] != id) ||
        (expectedInput != null &&
            inputSignature(input) != inputSignature(expectedInput)) ||
        !['preview', 'full'].contains(row['access']) ||
        catalog.length != expectedCount ||
        row['chapters'] is! List ||
        !['direct', 'payso_test'].contains(price['mode']) ||
        price['amount'] is! num ||
        price['amount'] < 0 ||
        price['currency'] != 'THB' ||
        text(price['display']).isEmpty ||
        progress['completed'] is! int ||
        progress['total'] is! int ||
        progress['total'] < 1 ||
        progress['completed'] < 0 ||
        progress['completed'] > progress['total']) {
      throw const FormatException('invalid_report');
    }
    if (input['report_kind'] == 'fortune' &&
        input['career'] == null &&
        (catalog.map((c) => c['key']).toSet().length != 7 ||
            catalog.any((c) => !fortuneKeys.contains(c['key'])))) {
      throw const FormatException('invalid_catalog');
    }
    final preview = object(row['preview']);
    if (row['preview'] != null &&
        (preview['traits'] is! List ||
            (preview['traits'] as List).length != 3)) {
      throw const FormatException('invalid_preview');
    }
    final report = LifeReport._(row);
    if (row['chart'] != null) {
      final chart = object(row['chart']);
      final planets = objects(chart['planets']),
          houses = objects(chart['houses']);
      final exact = text(profile['birth_time']).isNotEmpty;
      bool number(dynamic value, num min, num max) =>
          value is num && value.isFinite && value >= min && value < max;
      if (chart['precision'] != (exact ? 'exact' : 'estimated') ||
          text(chart['engine']).isEmpty ||
          chart['planets'] is! List ||
          planets.length > 32 ||
          chart['houses'] is! List ||
          chart['aspects'] is! List ||
          planets.map((p) => p['id']).toSet().length != planets.length ||
          planets.any(
            (p) =>
                !RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(text(p['id'])) ||
                text(p['label']).isEmpty ||
                !number(p['longitude'], 0, 360) ||
                !number(p['degree'], 0, 30) ||
                p['sign_index'] is! int ||
                !number(p['sign_index'], 0, 12) ||
                p['house'] != null &&
                    (p['house'] is! int || !number(p['house'], 1, 13)),
          ) ||
          houses.length > 12 ||
          houses.map((h) => h['number']).toSet().length != houses.length ||
          houses.any(
            (h) =>
                h['number'] is! int ||
                !number(h['number'], 1, 13) ||
                !number(h['longitude'], 0, 360),
          ) ||
          !exact &&
              (houses.isNotEmpty ||
                  planets.any(
                    (p) => p['id'] == 'ascendant' || p['house'] != null,
                  ))) {
        throw const FormatException('invalid_chart');
      }
    }
    for (final entry in [
      ('preview_generation_progress', previewKeys),
      ('generation_progress', report.progressKeys),
    ]) {
      if (row[entry.$1] == null) continue;
      final p = object(row[entry.$1]), sections = objects(p['sections']);
      if (p['percent'] is! int ||
          p['percent'] < 0 ||
          p['percent'] > 100 ||
          sections.length != entry.$2.length ||
          sections.map((s) => s['key']).toSet().length != entry.$2.length ||
          sections.any(
            (s) =>
                !entry.$2.contains(s['key']) ||
                s['percent'] is! num ||
                !((s['percent'] as num).isFinite) ||
                s['percent'] < 0 ||
                s['percent'] > 100,
          )) {
        throw const FormatException('invalid_progress');
      }
    }
    return report;
  }

  double percent(bool complete) {
    final done = complete
        ? ready
        : preview.isNotEmpty && json['preview_state'] == 'ready';
    if (done) return 100;
    final detail = object(
      json[complete ? 'generation_progress' : 'preview_generation_progress'],
    );
    final progress = object(json['progress']);
    final fallback = complete
        ? (progress['completed'] as int) / (progress['total'] as int) * 100
        : 0.0;
    return ((detail['percent'] as num?)?.toDouble() ?? fallback)
        .clamp(0, 99)
        .toDouble();
  }

  Json exportPayload() => {
    ...json,
    if (!ready) 'access': 'preview',
    if (!ready) 'chapters': <Json>[],
    if (!ready) 'plan': null,
  };
}

bool validBirthDate(String date, String today) {
  final parsed = DateTime.tryParse(date);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) &&
      parsed != null &&
      parsed.toIso8601String().substring(0, 10) == date &&
      date.compareTo('1901-01-01') >= 0 &&
      date.compareTo(today) <= 0 &&
      date.compareTo('2099-12-31') <= 0;
}
