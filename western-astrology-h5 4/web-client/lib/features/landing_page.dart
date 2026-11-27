import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../app/languages.dart';
import '../core/browser_port.dart';
import '../core/models.dart';
import '../core/repository.dart';
import 'report_chart.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    required this.loadReportPage,
    this.topic = 'life',
    super.key,
  });
  final Future<void> Function() loadReportPage;
  final String topic;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _stages = ['unspecified', 'considering', 'searching', 'offer'];
  BrowserPort? _browser;
  CancelToken? _previewRequest;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_browser != null) return;
    final h5 = H5Scope.of(context);
    _browser = h5.browser;
    final saved = h5.browser.readSetting('active-preview', session: true) ?? '';
    if (!h5.browser.birthFormSubmitting &&
        RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(saved)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/report.html?id=$saved&lang=${h5.language}');
      });
      return;
    }
    unawaited(h5.recordVisit());
    final input = h5.landingInput;
    final restoringCareer =
        input?['report_kind'] == 'fortune' ||
        _stages.contains(object(input?['career_question'])['stage']);
    h5.browser.attachBirthForm({
      'language': h5.language,
      'topic': widget.topic,
      'career': widget.topic == 'career' || restoringCareer,
      if (input != null) 'input': input,
      if (h5.landingPlace != null) 'place': h5.landingPlace!.json,
    }, (values) => _openPage(h5, values));
  }

  Future<String> _openPage(H5Controller h5, Json values) async {
    if (!mounted) return '';
    final language = h5Language(text(values['language']));
    if (language != h5.language && !await h5.changeLanguage(language)) {
      return 'network';
    }
    if (!mounted) return '';
    if (values['page'] != 'report') return 'badResult';
    LifeReport report;
    try {
      report = LifeReport.parse(
        values['report'],
        expectedInput: object(values['input']),
      );
    } on FormatException {
      return 'badResult';
    }
    h5.warmReportFont();
    unawaited(h5.trackReport(report.id, 'submitted'));
    // Load the page while its existing repository waits for the accepted report.
    final library = widget.loadReportPage().then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    if (!report.hasPreview && report.previewInProgress) {
      final token = _previewRequest = CancelToken();
      try {
        report = await h5.repository.resumeGeneration(report, token, (
          latest,
          percent,
          phase,
        ) {
          report = latest;
          _showGenerationProgress(h5, latest, percent, phase);
        }, full: false);
      } on ApiFailure {
        if (!mounted) return '';
        h5.trackActivity('generating_preview', 'generation_failed');
        // A terminal state can use the report page's existing retry controls.
        if (report.previewInProgress) return 'network';
      } finally {
        _previewRequest = null;
      }
    } else if (report.hasPreview) {
      _showGenerationProgress(h5, report, report.percent(false), 'preview');
    }
    if (!mounted) return '';
    if (report.hasPreview) {
      await Future.wait([
        h5.prepareText(jsonEncode(report.json), language: report.language),
        library,
      ]);
      if (!mounted) return '';
      h5.stageGeneratedPreview(report);
    }
    context.go('/report.html?id=${report.id}&lang=${report.language}');
    return '';
  }

  void _showGenerationProgress(
    H5Controller h5,
    LifeReport report,
    double percent,
    String phase,
  ) {
    final copy = h5.copy;
    final placements = placementDetails(report);
    final factors = reportFactors(report);
    h5.browser.updateBirthGeneration({
      'id': report.id,
      'phase': phase,
      'percent': percent,
      'estimated': report.estimated,
      'planetCount': placements.planetCount,
      'houseCount': placements.houseCount,
      'planets': [
        for (final planet in placements.planets)
          {'name': planetName(planet, copy), 'sign': planetSign(planet, copy)},
      ],
      'strengths': factors.strengths
          .take(2)
          .map((p) => text(p['title']))
          .toList(),
      'warnings': factors.warnings
          .take(2)
          .map((p) => text(p['title']))
          .toList(),
    });
  }

  @override
  void dispose() {
    _previewRequest?.cancel();
    _browser?.detachBirthForm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
