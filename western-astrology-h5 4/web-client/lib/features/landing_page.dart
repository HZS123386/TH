import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../app/languages.dart';
import '../core/browser_port.dart';
import '../core/models.dart';
import 'generation_dialog.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({this.topic = 'life', super.key});
  final String topic;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _stages = ['unspecified', 'considering', 'searching', 'offer'];
  BrowserPort? _browser;
  final _generation = GenerationState();
  late H5Controller _h5;
  Json? _generationInput;
  bool _showGeneration = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_browser != null) return;
    final h5 = H5Scope.of(context);
    _h5 = h5;
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
    if (values['page'] == 'generating') {
      final input = object(values['input']);
      if (object(input['profile']).isEmpty) return 'badResult';
      _generation.retry();
      setState(() {
        _generationInput = input;
        _showGeneration = true;
      });
      // Keep the native form covering Flutter until this frame has painted the
      // sole generation screen, so even a cold handoff cannot expose the body.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showGeneration && h5.browser.birthFormSubmitting) {
          h5.browser.setBirthFormVisible(false);
        }
      });
      return '';
    }
    if (values['page'] != 'report') return 'badResult';
    final LifeReport report;
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
    if (report.hasPreview) {
      await h5.prepareText(jsonEncode(report.json), language: report.language);
      if (!mounted) return '';
      if (_showGeneration) {
        _generation.ready(report);
        return '';
      }
      h5.stageGeneratedPreview(report);
    } else if (_showGeneration) {
      // Queued reports continue through ReportPage's polling dialog. Staging
      // the accepted object avoids an extra read during the seamless handoff.
      h5.stageGeneratedPreview(report);
    }
    // A queued acknowledgement may already be ready by the time Flutter opens it.
    context.go('/report.html?id=${report.id}&lang=${report.language}');
    return '';
  }

  @override
  void dispose() {
    _generation.dispose();
    _browser?.detachBirthForm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showGeneration) return const SizedBox.shrink();
    return GenerationDialog(
      h5: _h5,
      state: _generation,
      full: false,
      input: _generationInput,
      showCancel: false,
      embedded: true,
      onCancel: () {},
      onRetry: _generation.retry,
      onComplete: (report) {
        _h5.stageGeneratedPreview(report);
        context.go(
          '/report.html?id=${Uri.encodeComponent(report.id)}&lang=${report.language}&generation_presented=1',
        );
      },
    );
  }
}
