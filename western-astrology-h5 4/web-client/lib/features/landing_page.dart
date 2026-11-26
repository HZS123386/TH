import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../app/languages.dart';
import '../core/browser_port.dart';
import '../core/models.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({this.topic = 'life', super.key});
  final String topic;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _stages = ['unspecified', 'considering', 'searching', 'offer'];
  BrowserPort? _browser;

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
      h5.stageGeneratedPreview(report);
    }
    // A queued acknowledgement may already be ready by the time Flutter opens it.
    context.go('/report.html?id=${report.id}&lang=${report.language}');
    return '';
  }

  @override
  void dispose() {
    _browser?.detachBirthForm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
