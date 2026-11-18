import 'calculation.dart';

class ReportGenerationProgress {
  const ReportGenerationProgress({
    this.percent = 0,
    this.stage = 'preparing',
    this.completedTopics = const [],
  });
  static const topics = [
    'personality',
    'career',
    'money',
    'relationships',
    'watch',
    'actions',
  ];
  final int percent;
  final String stage;
  final List<String> completedTopics;
  factory ReportGenerationProgress.fromJson(
    dynamic value, {
    required bool ready,
  }) {
    if (ready) {
      return const ReportGenerationProgress(
        percent: 100,
        stage: 'complete',
        completedTopics: topics,
      );
    }
    if (value is! Map) return const ReportGenerationProgress();
    final raw = value['percent'];
    final percent = raw is num && raw.isFinite ? raw.toInt().clamp(0, 99) : 0;
    final stage = value['stage'];
    final completed = value['completed_topics'];
    return ReportGenerationProgress(
      percent: percent,
      stage:
          [
            'preparing',
            'checking_data',
            'writing',
            'reviewing',
            'refining',
            'failed',
          ].contains(stage)
          ? stage as String
          : 'preparing',
      completedTopics: List.unmodifiable(
        topics.where((key) => completed is List && completed.contains(key)),
      ),
    );
  }
}

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
    this.developmentPreview = false,
    this.calculation,
    this.number,
    this.failureReason,
    this.progress = const ReportGenerationProgress(),
  });
  final String id, resultId, locale, summary, previewState, fullState;
  final bool full;
  final bool developmentPreview;
  final CalculationSnapshot? calculation;
  final String? number;
  final String? failureReason;
  final ReportGenerationProgress progress;
  bool get failed => previewState == 'failed' || fullState == 'failed';
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
    final rawCalculation = json['calculation'];
    if (rawCalculation != null && rawCalculation is! Map) {
      throw const FormatException('invalid_report_chart');
    }
    final calculation = rawCalculation == null
        ? null
        : CalculationSnapshot.fromJson(
            Map<String, dynamic>.from(rawCalculation as Map),
          );
    if (calculation != null && calculation.id != resultId) {
      throw const FormatException('report_chart_mismatch');
    }
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

    final previewState = json['preview_state'] as String? ?? 'ready';
    final fullState =
        json['full_state'] as String? ?? (full ? 'ready' : 'locked');
    return ReportSnapshot(
      id: json['report_id'] as String,
      resultId: resultId,
      locale: locale,
      summary: json['summary'] as String? ?? '',
      full: full,
      developmentPreview: json['access_reason'] == 'development_preview',
      calculation: calculation,
      number: json['report_number'] as String?,
      failureReason: json['failure_reason'] as String?,
      previewState: previewState,
      fullState: fullState,
      progress: ReportGenerationProgress.fromJson(
        json['generation_progress'],
        ready:
            previewState == 'ready' &&
            !['running', 'queued', 'failed'].contains(fullState),
      ),
      preview: sections(json['preview']),
      sections: sections(json['sections']),
    );
  }
}
