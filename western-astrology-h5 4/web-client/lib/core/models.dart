import '../app/languages.dart';

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
const westernKeys = ['natal', 'career', 'wealth', 'love', 'risk'];
const personalKeys = [...westernKeys, 'plan'];
const legacyPersonalKeys = ['talent', 'node-1', 'node-2', 'node-3'];
const relationshipKeys = ['judgment', 'basis'];
const marriagePreviewKeys = [
  'birth_details',
  'relationship_style',
  'current_relationship',
  'relationship_snapshot',
  'unlock_offer',
];
const marriageKeys = [
  'how_to_read',
  'long_term_relationship',
  'relationship_chart',
  'relationship_timing',
  'other_areas',
  'relationship_actions',
  'traditional_support',
  'relationship_takeaway',
];

bool _validRelationshipSections(Json sections) =>
    sections.length == relationshipKeys.length &&
    relationshipKeys.every((key) {
      final paragraphs = sections[key];
      return paragraphs is List &&
          paragraphs.isNotEmpty &&
          paragraphs.every((paragraph) => text(paragraph).trim().isNotEmpty);
    });

bool _validMarriageSections(dynamic value, List<String> keys) {
  final sections = objects(value);
  return sections.length == keys.length &&
      sections.asMap().entries.every((entry) {
        final section = entry.value;
        final paragraphs = section['paragraphs'];
        return section['key'] == keys[entry.key] &&
            text(section['title']).trim().isNotEmpty &&
            paragraphs is List &&
            paragraphs.isNotEmpty &&
            paragraphs.every(
              (line) => line is String && line.trim().isNotEmpty,
            );
      });
}

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
      if (report.western) ...object(object(data['western'])[language]),
      if (report.career) ...object(object(data['career'])[language]),
    };
    if (report.western) {
      labels['methodValue'] = forLanguage(language).t('jy', 'chart.western');
      labels['plan'] = forLanguage(
        language,
      ).t('jy', 'report.westernSections.plan');
    }
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
      ? {
          'zh': '$year年运程',
          'th': 'ดวงปี $year',
          'en': '$year yearly themes',
          'vi': 'Chủ đề năm $year',
          'my': '$year နှစ်အလိုက်အကြောင်းအရာ',
          'km': 'ប្រធានបទឆ្នាំ $year',
          'lo': 'ຫົວຂໍ້ປີ $year',
          'ms': 'Tema tahun $year',
          'id': 'Tema tahun $year',
        }[language]!
      : text(object(topic[language])['title']);
}

class Place {
  Place(this.json);
  final Json json;
  String get id => text(json['id']);
  String get country => text(json['countryCode']);
  String get zone => text(json['timeZone']);
  String get english => text(json['nameEnglish']);
  String name(String language) {
    final preferred = language == 'zh'
        ? 'nameChinese'
        : language == 'th'
        ? 'nameThai'
        : 'nameEnglish';
    for (final key in [preferred, 'nameEnglish', 'nameChinese', 'nameThai']) {
      if (text(json[key]).isNotEmpty) return text(json[key]);
    }
    return '';
  }

  bool get representative =>
      json['placeType'] == 'province' ||
      json['coordinateKind'] == 'representative' ||
      json['coordinateKind'] == 'administrative-area';
  String label(String language) => !['zh', 'th'].contains(language)
      ? name(language)
      : text(json[language == 'zh' ? 'labelChinese' : 'labelThai']).isNotEmpty
      ? text(json[language == 'zh' ? 'labelChinese' : 'labelThai'])
      : text(json[language == 'zh' ? 'nameChinese' : 'nameThai']).isNotEmpty
      ? text(json[language == 'zh' ? 'nameChinese' : 'nameThai'])
      : english;
}

String inputSignature(Json input) {
  final p = object(input['profile']),
      career = object(input['career']),
      question = object(input['career_question']),
      relationship = object(input['relationship']);
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
    if (input['relationship'] != null)
      [
        for (final key in ['status', 'source', 'roles', 'event'])
          relationship[key],
      ],
    input['report_kind'],
  ]);
}

class LifeReport {
  LifeReport._(this.json);
  final Json json;
  String get id => text(json['id']);
  String get claimCode => text(json['claim_code']);
  Json get input => object(json['input']);
  Json get profile => object(input['profile']);
  String get language => text(profile['language']);
  bool get full => json['access'] == 'full';
  bool get previewInProgress =>
      ['queued', 'generating'].contains(json['preview_state']);
  bool get fullInProgress =>
      full && ['queued', 'generating'].contains(json['full_state']);
  bool get ready =>
      full &&
      json['full_state'] == 'ready' &&
      json['preview_state'] == 'ready' &&
      hasPreview &&
      object(json['progress'])['completed'] ==
          object(json['progress'])['total'];
  bool get career => input['career'] != null;
  bool get personalReport => json['format'] == 'western-personal';
  bool get relationshipReport => personalReport && input['relationship'] is Map;
  bool get marriageReport => json['format'] == 'thai-marriage';
  bool get sectionedReport => marriageReport || relationshipReport;
  Json get marriage => object(json['marriage']);
  bool get western => personalReport || json['format'] == 'western-compact';
  Json get personal => object(json['personal']);
  Json get relationshipPreview => object(personal['relationship']);
  Json get relationshipPreviewSections =>
      object(personal['relationship_preview_sections']);
  List<String> get freeLines =>
      (personal['free_lines'] as List? ?? []).map(text).toList();
  List<Json> get freeTraits => objects(personal['traits']);
  String get opportunityAction => text(personal['opportunity_action']);
  bool get hasPreview => marriageReport
      ? _validMarriageSections(marriage['preview'], marriagePreviewKeys)
      : relationshipReport
      ? _validRelationshipSections(relationshipPreviewSections)
      : personalReport
      ? freeLines.length == 3 &&
            freeLines.every((line) => line.trim().isNotEmpty)
      : preview.isNotEmpty;
  Json get talent => full ? object(personal['talent']) : {};
  Json get personalThemes => full ? object(personal['themes']) : {};
  Json get relationshipSections =>
      full ? object(personal['relationship_sections']) : {};
  List<Json> readingSections({bool complete = false, Copy? copy}) {
    final showFull = complete && ready;
    if (marriageReport) {
      final sections = objects(marriage[showFull ? 'full' : 'preview']);
      if (showFull || language != 'zh' || copy == null) return sections;
      // A saved preview can carry headings from an older server release.
      final titles = copy.forLanguage(language).list('marriage', 'preview');
      if (titles.length != sections.length) return sections;
      return [
        for (final (index, section) in sections.indexed)
          if (index > 0 &&
              (section['key'] != 'relationship_style' ||
                  text(profile['birth_time']).isNotEmpty))
            {...section, 'title': titles[index]}
          else
            section,
      ];
    }
    final content = showFull
        ? relationshipSections
        : relationshipPreviewSections;
    return [
      for (final section in catalog)
        {...section, 'paragraphs': content[section['key']]},
    ];
  }

  bool get sixPersonalThemes =>
      personalReport &&
      !relationshipReport &&
      catalog.length == personalKeys.length;
  List<Json> get nodes => full ? objects(personal['nodes']) : [];
  String get availabilityReason =>
      text(object(personal['availability'])['reason']);
  Json get preview => object(json['preview']);
  List<Json> get catalog => objects(json['catalog']);
  List<Json> get chapters => full ? objects(json['chapters']) : [];
  Json get plan => full ? object(json['plan']) : {};
  Json get price => object(json['price']);
  String get priceLabel => text(price['display']);
  bool get paysoTest => price['mode'] == 'payso_test';
  bool get orderOnly => price['mode'] == 'sunlands_order_only';
  bool get canPay =>
      (!personalReport ||
          object(personal['availability'])['full_report'] == true) &&
      (orderOnly || paysoTest || json['payment_simulation'] == true);
  bool get estimated => object(json['time_accuracy'])['mode'] == 'estimated';
  List<String> get progressKeys => career
      ? ['work']
      : marriageReport
      ? marriageKeys
      : relationshipReport
      ? relationshipKeys
      : personalReport
      ? (sixPersonalThemes ? personalKeys : legacyPersonalKeys)
      : western
      ? [...westernKeys, 'plan']
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
    final isPersonal = row['format'] == 'western-personal';
    final isRelationship = isPersonal && input['relationship'] is Map;
    final isMarriage = row['format'] == 'thai-marriage';
    final personalCatalog = isRelationship
        ? relationshipKeys
        : catalog.length == legacyPersonalKeys.length
        ? legacyPersonalKeys
        : personalKeys;
    final expectedCount = input['career'] != null
        ? 1
        : isMarriage
        ? marriageKeys.length
        : isPersonal
        ? personalCatalog.length
        : row['format'] == 'western-compact'
        ? 5
        : input['report_kind'] == 'fortune'
        ? 7
        : 5;
    if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(text(row['id'])) ||
        !h5Languages.any((option) => option.$1 == language) ||
        (id != null && row['id'] != id) ||
        (expectedInput != null &&
            inputSignature(input) != inputSignature(expectedInput)) ||
        !['preview', 'full'].contains(row['access']) ||
        catalog.length != expectedCount ||
        row['chapters'] is! List ||
        ![
          'direct',
          'payso_test',
          'sunlands_order_only',
        ].contains(price['mode']) ||
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
    if (row['format'] == 'western-compact' &&
        (catalog.map((c) => c['key']).toSet().length != 5 ||
            catalog.any((c) => !westernKeys.contains(c['key'])))) {
      throw const FormatException('invalid_catalog');
    }
    if (isPersonal &&
        (catalog.map((c) => c['key']).toSet().length != expectedCount ||
            catalog.any((c) => !personalCatalog.contains(c['key'])))) {
      throw const FormatException('invalid_catalog');
    }
    if (!isPersonal &&
        row['format'] != 'western-compact' &&
        input['report_kind'] == 'fortune' &&
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
    if (isMarriage &&
        (input['report_kind'] != 'marriage' ||
            !catalog.asMap().entries.every(
              (entry) => entry.value['key'] == marriageKeys[entry.key],
            ) ||
            row['preview'] != null ||
            report.chapters.isNotEmpty ||
            row['plan'] != null ||
            row['preview_state'] == 'ready' && !report.hasPreview ||
            report.full &&
                row['full_state'] == 'ready' &&
                !_validMarriageSections(
                  report.marriage['full'],
                  marriageKeys,
                ))) {
      throw const FormatException('invalid_marriage_report');
    }
    if (isPersonal) {
      final personal = report.personal;
      final lines = personal['free_lines'];
      final traits = personal['traits'];
      final opportunityAction = personal['opportunity_action'];
      final relationship = report.relationshipPreview;
      final relationshipVersion = RegExp(
        r'^western-personal-(\d+)$',
      ).firstMatch(text(row['version']));
      final requiresRelationship =
          (int.tryParse(relationshipVersion?.group(1) ?? '') ?? 0) >= 8;
      if (personal['relationship'] != null ||
          requiresRelationship && row['preview_state'] == 'ready') {
        final facts = objects(relationship['evidence']);
        if (text(relationship['text']).trim().isEmpty ||
            text(relationship['action']).trim().isEmpty ||
            relationship['evidence'] is! List ||
            facts.length != 2 ||
            facts.map((fact) => fact['id']).toSet().length != 2 ||
            facts.any(
              (fact) => [
                'id',
                'title',
                'detail',
              ].any((field) => text(fact[field]).trim().isEmpty),
            )) {
          throw const FormatException('invalid_relationship_preview');
        }
      }
      final availability = object(personal['availability']);
      if (traits != null &&
              (traits is! List ||
                  ![0, 3].contains(traits.length) ||
                  traits.any(
                    (item) =>
                        item is! Map ||
                        item['title'] is! String ||
                        text(item['title']).trim().isEmpty ||
                        item['text'] is! String ||
                        text(item['text']).trim().isEmpty,
                  )) ||
          opportunityAction != null && opportunityAction is! String) {
        throw const FormatException('invalid_personal_preview');
      }
      if (row['preview'] != null ||
          objects(row['chapters']).isNotEmpty ||
          row['plan'] != null ||
          personal.isNotEmpty &&
              (lines is! List ||
                  lines.length > 3 ||
                  lines.any((line) => line is! String) ||
                  availability['full_report'] is! bool ||
                  ![
                    'ready',
                    'not_started',
                    'time_unknown',
                    'unavailable',
                    'insufficient_periods',
                  ].contains(availability['reason'])) ||
          row['preview_state'] == 'ready' &&
              (!report.hasPreview ||
                  text(personal['sun_sign']).isEmpty ||
                  personal['ascendant_sign'] != null &&
                      personal['ascendant_sign'] is! String) ||
          text(profile['birth_time']).isEmpty &&
              personal['ascendant_sign'] != null) {
        throw const FormatException('invalid_personal_report');
      }
      if (row['full_state'] == 'ready' && report.full && isRelationship) {
        if (!_validRelationshipSections(report.relationshipSections)) {
          throw const FormatException('invalid_relationship_report');
        }
      } else if (row['full_state'] == 'ready' && report.full) {
        if (report.sixPersonalThemes) {
          final themes = report.personalThemes;
          if (themes.length != 3 ||
              ['wealth', 'love', 'risk'].any((key) {
                final point = object(themes[key]);
                final facts = objects(point['evidence']);
                return text(point['text']).trim().isEmpty ||
                    point['evidence'] is! List ||
                    facts.length != 2 ||
                    facts.any(
                      (fact) => [
                        'id',
                        'title',
                        'detail',
                      ].any((field) => text(fact[field]).trim().isEmpty),
                    );
              })) {
            throw const FormatException('invalid_personal_themes');
          }
        }
        final talent = report.talent,
            directions = objects(report.talent['directions']),
            nodes = report.nodes;
        if (text(talent['text']).isEmpty ||
            directions.length != 3 ||
            directions.any(
              (item) =>
                  text(item['title']).isEmpty || text(item['text']).isEmpty,
            ) ||
            nodes.length != 3 ||
            nodes.map((item) => item['month']).toSet().length != 3 ||
            nodes.any(
              (item) =>
                  !RegExp(
                    r'^\d{4}-(0[1-9]|1[0-2])$',
                  ).hasMatch(text(item['month'])) ||
                  [
                    'theme',
                    'benefit',
                    'caution',
                    'action',
                  ].any((key) => text(item[key]).trim().isEmpty) ||
                  item['evidence'] is! List,
            )) {
          throw const FormatException('invalid_personal_content');
        }
      }
    }
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
        : hasPreview && json['preview_state'] == 'ready';
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
    if (marriageReport && !ready) 'marriage': {...marriage, 'full': null},
    if (personalReport && !ready)
      'personal': {
        ...personal,
        'talent': null,
        'themes': null,
        'nodes': <Json>[],
        if (relationshipReport) 'relationship_sections': null,
      },
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
