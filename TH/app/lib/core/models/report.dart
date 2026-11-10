class ReportSection {
  const ReportSection(this.key, this.title, this.paragraphs);
  final String key, title;
  final List<String> paragraphs;
  factory ReportSection.fromJson(Map<String, dynamic> json) {
    if (json['key'] is! String ||
        json['title'] is! String ||
        json['paragraphs'] is! List ||
        (json['paragraphs'] as List).length > 20) {
      throw const FormatException('invalid_report_section');
    }
    final paragraphs = List<String>.from(json['paragraphs'] as List);
    if (paragraphs.any((p) => p.length > 20000)) {
      throw const FormatException('report_section_too_long');
    }
    return ReportSection(
      json['key'] as String,
      json['title'] as String,
      List.unmodifiable(paragraphs),
    );
  }
}

class ReportSnapshot {
  const ReportSnapshot({
    required this.id,
    required this.resultId,
    required this.locale,
    required this.summary,
    required this.full,
    required this.previewState,
    required this.fullState,
    required this.preview,
    required this.sections,
  });
  final String id, resultId, locale, summary, previewState, fullState;
  final bool full;
  final List<ReportSection> preview, sections;
  bool get generating =>
      ['queued', 'running'].contains(previewState) ||
      ['queued', 'running'].contains(fullState);
  factory ReportSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String resultId,
    required String locale,
  }) {
    if (json['system'] != 'western_natal' ||
        json['report_id'] is! String ||
        json['calculation_result_id'] != resultId ||
        json['locale'] != locale ||
        !['preview', 'full'].contains(json['access']) ||
        json['preview'] is! List ||
        json['sections'] is! List) {
      throw const FormatException('invalid_report');
    }
    final full = json['access'] == 'full';
    if (!full && (json['sections'] as List).isNotEmpty) {
      throw const FormatException('paid_body_in_preview');
    }
    List<ReportSection> sections(dynamic raw) {
      if ((raw as List).length > 20) {
        throw const FormatException('too_many_sections');
      }
      return List.unmodifiable(
        raw.map(
          (value) =>
              ReportSection.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      );
    }

    return ReportSnapshot(
      id: json['report_id'] as String,
      resultId: resultId,
      locale: locale,
      summary: json['summary'] as String? ?? '',
      full: full,
      previewState: json['preview_state'] as String? ?? 'ready',
      fullState: json['full_state'] as String? ?? (full ? 'ready' : 'locked'),
      preview: sections(json['preview']),
      sections: sections(json['sections']),
    );
  }
}
