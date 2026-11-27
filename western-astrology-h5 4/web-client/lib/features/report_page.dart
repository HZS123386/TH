import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';
import 'report_chart.dart';
import 'checkout_dialog.dart';
import 'generation_dialog.dart';
import 'report_view_model.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    required this.h5,
    required this.id,
    this.paymentReturn = false,
    this.openedFromForm = false,
    super.key,
  });
  final H5Controller h5;
  final String id;
  final bool paymentReturn, openedFromForm;
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with WidgetsBindingObserver {
  late final _model = ReportViewModel(widget.h5, widget.id);
  CancelToken? _generationRequest;
  final _anchors = <String, GlobalKey>{};
  final _deleteRequest = CancelToken();
  bool _deleting = false, _paying = false;
  String _deleteError = '';
  bool _reported = false, _reportedFull = false, _generating = false;
  bool _resumedPreview = false,
      _checkedPaymentReturn = false,
      _openedPresentationScheduled = false;
  late bool _openingPresentation, _presentInitialGeneration;

  bool _usesCheckout(LifeReport report) =>
      report.sectionedReport || report.personalReport;

  void _backHome() {
    widget.h5.restoreLandingFromReport(_model.report);
    context.go('/?lang=${widget.h5.language}');
  }

  @override
  void initState() {
    super.initState();
    if (widget.h5.browser.readSetting('active-preview', session: true) ==
        widget.id) {
      widget.h5.browser.writeSetting('active-preview', '', session: true);
    }
    WidgetsBinding.instance.addObserver(this);
    widget.h5.trackActivity('report_loading');
    _model.addListener(_changed);
    final generated = widget.h5.takeGeneratedPreview(widget.id);
    _presentInitialGeneration = widget.openedFromForm || generated != null;
    _openingPresentation = _presentInitialGeneration;
    if (generated != null) {
      // From the form, this report was already fetched, validated, and prepared for display.
      _model.accept(generated);
    } else {
      unawaited(_model.load());
    }
  }

  void _changed() {
    final r = _model.report;
    if (r == null) {
      if (_model.error.isNotEmpty) {
        widget.h5.trackActivity('report_loading', 'report_failed');
      }
      return;
    }
    if (_presentInitialGeneration &&
        !_openedPresentationScheduled &&
        r.hasPreview) {
      _openedPresentationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_presentReadyReport(r));
      });
    }
    if (!_resumedPreview && !r.hasPreview && r.previewInProgress) {
      _resumedPreview = true;
      _openedPresentationScheduled = _presentInitialGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_generating) unawaited(_generate(false));
      });
    } else if (_presentInitialGeneration &&
        !_openedPresentationScheduled &&
        !r.hasPreview) {
      _openedPresentationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _openingPresentation = false);
      });
    }
    if (!_checkedPaymentReturn &&
        _usesCheckout(r) &&
        r.orderOnly &&
        r.hasPreview) {
      _checkedPaymentReturn = true;
      final browser = widget.h5.browser;
      final pending = browser.readSetting(
        ReportPaymentDialog.pendingReportKey,
        session: true,
      );
      if (widget.paymentReturn || r.id == pending) {
        if (r.id == pending) {
          browser.writeSetting(
            ReportPaymentDialog.pendingReportKey,
            '',
            session: true,
          );
        }
        if (!r.full) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_pay(returning: true));
          });
        }
      }
    }
    if (!_reported && r.hasPreview) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.h5.browser.pageReady('report-content');
          unawaited(widget.h5.trackReport(r.id, 'seen'));
          if (!r.ready) {
            widget.h5.trackActivity('preview_report', 'report_ready');
          }
        }
      });
    }
    if (!_reportedFull && r.ready) {
      _reportedFull = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.h5.browser.pageReady('report-full-content');
          widget.h5.trackActivity('full_report', 'report_ready');
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_generating) {
      _model.resume();
    } else {
      _model.pause();
    }
  }

  @override
  void dispose() {
    _generationRequest?.cancel();
    _deleteRequest.cancel();
    _model.removeListener(_changed);
    _model.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _erase() async {
    if (_deleting) return;
    final c = widget.h5.copy;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c.t('experience', 'deleteTitle')),
        content: Text(c.t('experience', 'deleteNotice')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(c.t('experience', 'keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(c.t('experience', 'delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _deleting = true;
      _deleteError = '';
    });
    try {
      await widget.h5.repository.request(
        '/api/life-reports/${widget.id}',
        _deleteRequest,
        method: 'DELETE',
      );
      if (mounted) context.go('/?lang=${widget.h5.language}');
    } catch (error) {
      if (mounted && !_deleteRequest.cancelled) {
        setState(() => _deleteError = widget.h5.message(error));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pay({bool returning = false}) async {
    final report = _model.report;
    if (report == null ||
        !report.canPay ||
        report.full ||
        _paying ||
        _deleting) {
      return;
    }
    setState(() => _paying = true);
    try {
      final latest = await _model.load(background: true);
      if (!mounted || latest == null || !latest.canPay || latest.full) return;
      final paid = await showDialog<bool>(
        context: context,
        builder: (_) => ReportPaymentDialog(
          h5: widget.h5,
          report: latest,
          returning: returning,
        ),
      );
      if (!mounted) return;
      widget.h5.trackActivity(
        _model.report?.ready == true ? 'full_report' : 'preview_report',
        'close_payment',
      );
      if (paid == true) {
        await _model.load(background: true);
        if (mounted && _model.report?.fullInProgress == true) {
          await _generate(true);
        }
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _generate(bool full) async {
    final initial = _model.report;
    if (initial == null || _generating) return;
    setState(() => _generating = true);
    _model.pause();
    final state = GenerationState()..phase = full ? 'full' : 'preview';
    final page = full ? 'generating_full' : 'generating_preview';
    var attempts = 0;
    Future<void> run() async {
      _generationRequest?.cancel();
      final token = CancelToken();
      _generationRequest = token;
      state.retry();
      final first = attempts++ == 0;
      try {
        // After a lost progress response, check the original ID before retrying generation.
        final current = !full && !first
            ? await widget.h5.repository.load(initial.id, token)
            : initial;
        final resume = full
            ? first && current.fullInProgress
            : current.previewInProgress || current.hasPreview;
        final action = !first
            ? 'retry_generation'
            : !full && resume
            ? 'view'
            : 'generate';
        widget.h5.trackActivity(page, action);
        final result = resume
            ? await widget.h5.repository.resumeGeneration(
                current,
                token,
                state.update,
                full: full,
              )
            : full
            ? await widget.h5.repository.unlock(initial, token, state.update)
            : await widget.h5.repository.generate(
                initial.input,
                token,
                state.update,
              );
        await widget.h5.prepareText(
          jsonEncode(result.json),
          language: result.language,
        );
        if (mounted && !token.cancelled) state.ready(result);
      } catch (error) {
        if (mounted && !token.cancelled) {
          state.fail(widget.h5.message(error));
          widget.h5.trackActivity(page, 'generation_failed');
        }
      }
    }

    unawaited(run());
    final completed = await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<bool>(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) => GenerationDialog(
          h5: widget.h5,
          state: state,
          full: full,
          input: initial.input,
          onCancel: () {
            _generationRequest?.cancel();
            Navigator.of(context, rootNavigator: true).pop(false);
          },
          onRetry: () => unawaited(run()),
          onComplete: (r) {
            Navigator.of(context, rootNavigator: true).pop(true);
            if (r.id != widget.id) {
              context.go(
                '/report.html?id=${Uri.encodeComponent(r.id)}&lang=${r.language}',
              );
              return;
            }
            _model.accept(r);
          },
        ),
      ),
    );
    _generationRequest?.cancel();
    state.dispose();
    if (mounted) {
      setState(() {
        _generating = false;
        _openingPresentation = false;
      });
      _model.resume();
      // The first displayed preview or full report records its own ready event.
      if (completed != true) {
        final report = _model.report;
        final returnedPage = report?.ready == true
            ? 'full_report'
            : report?.hasPreview == true
            ? 'preview_report'
            : 'report_loading';
        widget.h5.trackActivity(returnedPage, 'cancel_generation');
      }
    }
  }

  Future<void> _presentReadyReport(LifeReport report) async {
    final state = GenerationState()..ready(report);
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<bool>(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            GenerationDialog(
              h5: widget.h5,
              state: state,
              full: false,
              input: report.input,
              onCancel: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
              onRetry: () {},
              onComplete: (_) =>
                  Navigator.of(context, rootNavigator: true).pop(true),
            ),
      ),
    );
    state.dispose();
    if (mounted) setState(() => _openingPresentation = false);
  }

  void _navigate(String key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _anchors[key]?.currentContext;
      if (mounted && target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 280),
            alignment: .05,
          ),
        );
      }
    });
  }

  GlobalKey _key(String value) =>
      _anchors.putIfAbsent(value, () => GlobalKey());
  Widget _evidence(dynamic value, Copy c) {
    final items = objects(value);
    if (items.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
      title: Text(
        c.t('report', 'summaryEvidence'),
        style: const TextStyle(fontSize: 12, color: lavender),
      ),
      children: [
        for (final item in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: night.withValues(alpha: .45),
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text(item['title']),
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text(item['detail']),
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: lavender,
                    fontSize: 12,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _summary(Json value, Copy c) => JYCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _window(value, c),
        Text(
          text(value['text']),
          style: const TextStyle(fontSize: 14, height: 1.65),
        ),
        _evidence(value['evidence'], c),
      ],
    ),
  );

  Json _mergePreviewParts(List<Json> parts, Copy c) {
    final paragraphs = parts
        .map(
          (part) => text(part['text']).trim().replaceAll(RegExp(r'\s+'), ' '),
        )
        .where((value) => value.isNotEmpty)
        .toSet();
    final seen = <String>{};
    final evidence = <Json>[];
    for (final part in parts) {
      for (final item in objects(part['evidence'])) {
        final id = text(item['id']);
        final key = id.isNotEmpty
            ? 'id:$id'
            : jsonEncode([item['title'], item['detail']]);
        if (seen.add(key)) evidence.add(item);
      }
    }
    return {
      'text': paragraphs.join(c.language == 'zh' ? '' : ' '),
      'evidence': evidence,
    };
  }

  List<Widget> _westernPreview(LifeReport report, Copy c) {
    final preview = report.preview;
    final colon = c.language == 'zh' ? '：' : ': ';
    Json point(String key) => object(preview[key]);
    bool present(String key) => text(point(key)['text']).trim().isNotEmpty;
    Json note(String value) => {'text': value};
    final identity = _mergePreviewParts([
      point('summary'),
      ...objects(preview['traits']),
    ], c);
    final environment = _mergePreviewParts([
      if (present('environment')) point('environment'),
      for (final key in ['favorable', 'unfavorable'])
        if (present(key))
          {
            ...point(key),
            'text':
                '${c.t('jy', 'report.questions.$key')}$colon${point(key)['text']}',
          },
      if ([
        'environment',
        'favorable',
        'unfavorable',
      ].any((key) => !present(key)))
        note(c.t('jy', 'report.previewParagraphs.legacyEnvironment')),
    ], c);
    final recent = point('recent');
    final state = text(object(report.json['outlook'])['state']);
    final window = object(recent['window']);
    final timeUnknown =
        text(report.profile['birth_time']).isEmpty ||
        report.estimated ||
        state == 'time_unknown';
    final hasWindow =
        !timeUnknown &&
        state != 'unavailable' &&
        present('recent') &&
        [
          'start',
          'end',
          'event_date',
          'timezone',
        ].every((key) => text(window[key]).trim().isNotEmpty);
    final timing = _mergePreviewParts([
      if (hasWindow)
        {
          ...recent,
          'text':
              '${preview['sample_topic'] == 'career' ? '${c.t('jy', 'report.questions.freePeriod')}$colon' : ''}${recent['text']}',
        }
      else
        note(
          c.t(
            'jy',
            timeUnknown
                ? 'report.questions.timeUnknown'
                : state == 'ready'
                ? 'report.questions.empty'
                : state == 'unavailable'
                ? 'report.questions.unavailable'
                : 'report.previewParagraphs.legacyRecent',
          ),
        ),
      if (hasWindow && present('response'))
        {
          ...point('response'),
          'text':
              '${c.t('jy', 'report.questions.freeResponse')}$colon${point('response')['text']}',
        },
      if (hasWindow) note(c.t('jy', 'report.questions.timingNote')),
    ], c);
    if (hasWindow) timing['window'] = recent['window'];
    return [
      for (final entry in [
        ('identity', identity),
        ('environment', environment),
        ('recent', timing),
      ])
        if (entry.$1 == 'recent' && !hasWindow)
          Padding(
            key: const ValueKey('preview-timing-unavailable'),
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text(entry.$2['text']),
                  style: const TextStyle(
                    color: lavender,
                    fontSize: 12,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _backHome,
                  child: Text(c.t('generation', 'back')),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(top: entry.$1 == 'identity' ? 0 : 14),
            child: JYCard(
              key: ValueKey('preview-paragraph-${entry.$1}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    c.t('jy', 'report.previewParagraphs.${entry.$1}'),
                    style: const TextStyle(
                      color: gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _window(entry.$2, c),
                  Text(
                    text(entry.$2['text']),
                    key: ValueKey('preview-paragraph-${entry.$1}-text'),
                    style: const TextStyle(fontSize: 14, height: 1.8),
                  ),
                  _evidence(entry.$2['evidence'], c),
                ],
              ),
            ),
          ),
    ];
  }

  Widget _window(Json point, Copy c) {
    final window = object(point['window']);
    if (window.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c.t('jy', 'report.questions.window')} · ${window['start']} – ${window['end']} (${window['timezone']})',
            style: const TextStyle(color: gold, fontSize: 12, height: 1.6),
          ),
          Text(
            '${c.t('jy', 'report.questions.eventDate')} · ${window['event_date']}',
            style: const TextStyle(color: lavender, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _freePreview(LifeReport report, Copy c) => JYCard(
    key: const ValueKey('free-report-content'),
    padding: const EdgeInsets.all(20),
    radius: 18,
    borderColor: line,
    colors: const [panel, panel],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (report.marriageReport) ...[
          Text(
            text(report.json['title']),
            style: const TextStyle(
              color: gold,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (report.sectionedReport)
          ..._readingSections(report.readingSections(copy: c))
        else if (!report.full) ...[
          Text(
            c.t(
              'jy',
              report.personalReport ? 'personal.freeTitle' : 'report.freeTitle',
            ),
            style: const TextStyle(
              color: gold,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!report.personalReport) ...[
            const SizedBox(height: 8),
            Text(
              c.t('jy', 'report.freeHint'),
              style: const TextStyle(
                color: lavender,
                fontSize: 12,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 16),
        ],
        if (!report.sectionedReport &&
            report.personalReport &&
            report.relationshipPreview.isNotEmpty) ...[
          JYCard(
            key: const ValueKey('free-relationship-preview'),
            radius: 14,
            borderColor: const Color(0xFFB878A4),
            colors: const [Color(0xFF3D2445), Color(0xFF24182F)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      color: Color(0xFFF3BDDB),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.t('jy', 'personal.relationshipTitle'),
                        style: const TextStyle(
                          color: Color(0xFFFFD6EC),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  text(report.relationshipPreview['text']),
                  key: const ValueKey('free-relationship-text'),
                  style: const TextStyle(
                    color: cream,
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  c.t('jy', 'personal.relationshipAction'),
                  style: const TextStyle(
                    color: gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text(report.relationshipPreview['action']),
                  key: const ValueKey('free-relationship-action'),
                  style: const TextStyle(
                    color: cream,
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),
                _evidence(report.relationshipPreview['evidence'], c),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (!report.sectionedReport)
          if (report.personalReport)
            ..._personalPreview(report, c)
          else if (report.western)
            ..._westernPreview(report, c)
          else ...[
            Text(
              text(report.input['user_question']).isNotEmpty
                  ? text(report.input['user_question'])
                  : c.t('report', 'takeaway'),
              style: const TextStyle(
                color: cream,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _summary(object(report.preview['summary']), c),
            if (report.preview['career_answer'] != null) ...[
              const SizedBox(height: 16),
              Text(
                c.t('report', 'careerQuestionTitle'),
                style: const TextStyle(color: gold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              _summary(object(report.preview['career_answer']), c),
            ],
            const SizedBox(height: 24),
            Text(
              c.t('report', 'traits'),
              style: const TextStyle(
                color: gold,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final trait in objects(report.preview['traits']))
              _point(trait, c),
          ],
      ],
    ),
  );
  List<Widget> _personalPreview(LifeReport report, Copy c) {
    final traits = report.freeTraits;
    final structured = traits.length == 3;
    final separator = report.language == 'zh' ? '' : ' ';
    final signs = [
      if (text(report.personal['sun_sign']).isNotEmpty)
        '${c.t('reading', 'planets.sun')}$separator${report.personal['sun_sign']}',
      if (text(report.personal['ascendant_sign']).isNotEmpty)
        '${c.t('reading', 'planets.ascendant')}$separator${report.personal['ascendant_sign']}',
    ];
    return [
      for (final entry in report.freeLines.indexed)
        Padding(
          padding: EdgeInsets.only(bottom: entry.$1 == 2 ? 0 : 16),
          child: JYCard(
            key: ValueKey('personal-free-zone-${entry.$1}'),
            padding: const EdgeInsets.all(16),
            radius: 14,
            borderColor: const Color(0x99D5AE70),
            colors: entry.$1 == 0
                ? const [Color(0xFF422650), Color(0xFF251733)]
                : entry.$1 == 2
                ? const [Color(0xFF463344), Color(0xFF2B1C35)]
                : const [Color(0xFF241930), Color(0xFF21162E)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.t(
                    'jy',
                    'personal.${['keywords', 'traits', 'opportunity'][entry.$1]}',
                  ),
                  style: const TextStyle(
                    color: gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (structured && entry.$1 == 0) ...[
                  Wrap(
                    key: const ValueKey('personal-signs'),
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      for (final sign in signs.indexed)
                        Text(
                          '${sign.$1 == 0 ? '' : '+ '}${sign.$2}',
                          style: const TextStyle(
                            color: cream,
                            fontSize: 22,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final trait in traits.take(2))
                        Container(
                          key: ValueKey(
                            'personal-keyword-${text(trait['title'])}',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xBBD5AE70)),
                            borderRadius: BorderRadius.circular(30),
                            color: const Color(0x22E4BC78),
                          ),
                          child: Text(
                            text(trait['title']),
                            style: const TextStyle(
                              color: gold,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // The sign overview is already expressed by the title and trait rows.
                  Text(
                    report.freeLines[1],
                    key: const ValueKey('personal-free-summary'),
                    style: const TextStyle(
                      color: lavender,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                ] else if (structured && entry.$1 == 1)
                  for (final trait in traits.indexed) ...[
                    if (trait.$1 > 0)
                      const Divider(height: 22, color: Color(0x44D5AE70)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          margin: const EdgeInsets.only(right: 12, top: 3),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Color(0x55D5AE70)),
                            ),
                          ),
                          child: Icon(
                            [
                              Icons.wb_sunny_outlined,
                              Icons.auto_awesome_outlined,
                              Icons.hub_outlined,
                            ][trait.$1],
                            color: gold,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                text(trait.$2['title']),
                                key: ValueKey(
                                  'personal-trait-title-${trait.$1}',
                                ),
                                style: const TextStyle(
                                  color: cream,
                                  fontSize: 15,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                text(trait.$2['text']),
                                key: ValueKey(
                                  'personal-trait-text-${trait.$1}',
                                ),
                                style: const TextStyle(
                                  color: lavender,
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]
                else
                  Text(
                    entry.$2,
                    key: ValueKey('personal-free-line-${entry.$1}'),
                    style: TextStyle(
                      color: cream,
                      fontSize: entry.$1 == 2 ? 17 : 15,
                      height: 1.65,
                      fontWeight: entry.$1 == 1
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                if (entry.$1 == 2 && report.opportunityAction.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.opportunityAction,
                    key: const ValueKey('personal-opportunity-action'),
                    style: const TextStyle(
                      color: lavender,
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  Widget _point(Json point, Copy c, {String? anchor}) => Padding(
    key: anchor == null ? null : _key(anchor),
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _window(point, c),
        if (text(point['title']).isNotEmpty)
          Text(
            text(point['title']),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: cream,
            ),
          ),
        if (point['period'] != null)
          Text(
            '${object(point['period'])['year']}-${'${object(point['period'])['month']}'.padLeft(2, '0')}',
            style: const TextStyle(color: gold, fontSize: 11),
          ),
        const SizedBox(height: 8),
        Text(text(point['text'])),
        if ((point['signals'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          for (final signal in point['signals'] as List)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• $signal',
                style: const TextStyle(color: lavender, height: 1.9),
              ),
            ),
        ],
        if (text(point['response']).isNotEmpty)
          Text(
            text(point['response']),
            style: const TextStyle(color: gold, height: 1.9),
          ),
        for (final entry in (point['steps'] as List? ?? []).indexed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${entry.$1 + 1}. ${entry.$2}',
              style: const TextStyle(height: 1.95),
            ),
          ),
        for (final field in ['example', 'pitfall', 'check'])
          if (text(point[field]).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${c.t('jy', 'pointFields.$field')}\n${point[field]}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        _evidence(point['evidence'], c),
      ],
    ),
  );
  Widget _chapter(LifeReport r, Json item, Copy c) {
    final name = text(item['key']);
    final chapter = r.chapters
        .where((value) => value['key'] == name)
        .firstOrNull;
    if (chapter == null) return const SizedBox.shrink();
    return Padding(
      key: _key(name),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!r.western)
            Text(
              text(chapter['title']).isEmpty
                  ? text(item['title'])
                  : text(chapter['title']),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: gold,
              ),
            ),
          const SizedBox(height: 8),
          _summary(object(chapter['summary']), c),
          for (final group in ['insights', 'watchpoints', 'actions'])
            for (final entry in objects(chapter[group]).indexed)
              _point(
                entry.$2,
                c,
                anchor: group == 'actions' ? 'action-$name-${entry.$1}' : null,
              ),
        ],
      ),
    );
  }

  Widget _plan(LifeReport r, Copy c) => r.plan.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          key: _key('plan'),
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!r.western)
                Text(
                  c.t('report', 'plan'),
                  style: const TextStyle(
                    color: gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              for (final phase in objects(r.plan['phases'])) ...[
                _point(phase, c),
                for (final action in objects(phase['actions'])) ...[
                  if (r.western) _window(action, c),
                  if (r.western)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        text(action['title']),
                        style: const TextStyle(color: cream, fontSize: 13),
                      ),
                    )
                  else
                    _point(action, c),
                  TextButton(
                    onPressed: () => _navigate(
                      'action-${action['chapter']}-${action['index']}',
                    ),
                    child: Text('${c.t('report', 'viewAction')} →'),
                  ),
                ],
              ],
            ],
          ),
        );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final r = _model.report,
          c = r == null ? widget.h5.copy : widget.h5.reportCopy(r);
      if (_openingPresentation && _model.error.isEmpty) {
        return const ColoredBox(color: Color(0xFF0B0715));
      }
      if (r == null) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FateBrand(compact: true),
                const SizedBox(height: 30),
                if (_model.loading) const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(c.t('life', 'loading')),
                errorMessage(_model.error),
                if (!_model.loading)
                  OutlinedButton(
                    onPressed: () => _model.load(),
                    child: Text(c.t('generation', 'retry')),
                  ),
              ],
            ),
          ),
        );
      }
      if (!r.full &&
          r.hasPreview &&
          (!r.personalReport || r.json['preview_state'] == 'ready')) {
        return ReportPreview(
          h5: widget.h5,
          reportId: r.id,
          claimCode: r.claimCode,
          marriage: r.marriageReport,
          relationshipOffer:
              r.sixPersonalThemes && r.relationshipPreview.isNotEmpty,
          onPay: _usesCheckout(r) && r.canPay ? _pay : null,
          priceLabel: _usesCheckout(r) && r.canPay ? r.priceLabel : '',
          freePreview: _freePreview(r, c),
          onExportPdf: r.relationshipReport && !_model.exporting
              ? () => _model.export('pdf')
              : null,
          exportStatus: r.relationshipReport ? _model.exportStatus : '',
          busy: _deleting || _generating || _paying,
          error: _deleteError.isNotEmpty ? _deleteError : _model.error,
          onErase: () => _erase(),
        );
      }
      if (!r.hasPreview ||
          r.personalReport && r.json['preview_state'] != 'ready') {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FateBrand(compact: true),
                const SizedBox(height: 24),
                Text(c.t('report', 'previewStates.${r.json['preview_state']}')),
                const SizedBox(height: 18),
                JYButton(
                  label: c.t(
                    'report',
                    r.previewInProgress ? 'viewProgress' : 'retryPreview',
                  ),
                  onPressed: _generating ? null : () => _generate(false),
                ),
              ],
            ),
          ),
        );
      }
      final groups = r.personalReport || r.marriageReport
          ? <(String, List<String>)>[]
          : r.western
          ? [
              ('natal', ['natal']),
              ('career', ['career']),
              ('wealth', ['wealth']),
              ('love', ['love']),
              ('risk', ['risk']),
              ('plan', <String>[]),
            ]
          : [
              ('natal', ['pattern']),
              ('love', ['marriage']),
              ('career', ['wealth']),
              ('opportunities', ['risk']),
              ('partnership', ['romance']),
            ];
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const FateBrand(),
                const Spacer(),
                IconButton(
                  tooltip: c.t('report', 'exportPdf'),
                  onPressed: _model.exporting
                      ? null
                      : () => _model.export('pdf'),
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: gold,
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            JYCard(
              padding: const EdgeInsets.all(24),
              radius: 20,
              borderColor: line,
              colors: const [panel, panel],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!r.sectionedReport) ...[
                    Text(
                      'FATE / ${c.t('jy', 'topics.life.label')}',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    r.personalReport && !r.sectionedReport
                        ? c.t('jy', 'personal.title')
                        : text(r.json['title']),
                    style: const TextStyle(
                      color: Color(0xFFFFEAC5),
                      fontSize: 23,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!r.personalReport) ...[
                    const SizedBox(height: 8),
                    Text(
                      r.western
                          ? text(r.profile['birthplace'])
                          : '${r.profile['birthplace']} · ${r.estimated ? c.t('jy', 'chart.dateOnly') : c.t('jy', 'chart.exact')}',
                      style: const TextStyle(color: lavender, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (r.sectionedReport)
                    ..._readingSections(r.readingSections(complete: true))
                  else ...[
                    if (r.western) ...[
                      ExpansionTile(
                        key: const ValueKey('saved-free-report'),
                        tilePadding: EdgeInsets.zero,
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        childrenPadding: const EdgeInsets.only(bottom: 16),
                        title: Text(
                          c.t('jy', 'report.freeTitle'),
                          style: const TextStyle(
                            color: gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [_freePreview(r, c)],
                      ),
                      const SizedBox(height: 12),
                    ],
                    JYCard(
                      radius: 15,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            c.t('jy', 'report.contents'),
                            style: const TextStyle(
                              fontSize: 15,
                              color: gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (r.personalReport && !r.sixPersonalThemes)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final key in r.progressKeys)
                                  ActionChip(
                                    label: Text(c.t('jy', 'personal.$key')),
                                    onPressed: () => _navigate('report-$key'),
                                  ),
                              ],
                            )
                          else
                            ReportBadges(
                              copy: c,
                              locked: false,
                              western: r.western,
                              onTap: (key) => _navigate('report-$key'),
                            ),
                        ],
                      ),
                    ),
                    if (r.personalReport) ..._personalSections(r, c),
                  ],
                  if (!r.western && !r.marriageReport)
                    _sectionTitle(
                      'overall',
                      c.t('jy', 'report.sections.overall'),
                    ),
                  for (final key
                      in r.western || r.marriageReport
                          ? <String>[]
                          : ['annual', 'overall'])
                    for (final item in r.catalog.where(
                      (item) => item['key'] == key,
                    ))
                      _chapter(r, item, c),
                  for (final group in groups) ...[
                    _sectionTitle(
                      group.$1,
                      c.t(
                        'jy',
                        'report.${r.western ? 'westernSections' : 'sections'}.${group.$1}',
                      ),
                    ),
                    if (group.$1 == 'natal' && !r.western) ...[
                      _summary(object(r.preview['summary']), c),
                      if (r.preview['career_answer'] != null)
                        _summary(object(r.preview['career_answer']), c),
                      for (final item in objects(r.preview['traits']))
                        _point(item, c),
                    ],
                    if (group.$1 == 'opportunities')
                      ReportFactors(report: r, copy: c),
                    for (final key in group.$2)
                      for (final item in r.catalog.where(
                        (item) => item['key'] == key,
                      ))
                        _chapter(r, item, c),
                    if (group.$1 == 'opportunities' || group.$1 == 'plan')
                      _plan(r, c),
                  ],
                  if (!r.ready) ...[
                    const SizedBox(height: 16),
                    Text(
                      c.t('report', 'states.${r.json['full_state']}'),
                      style: const TextStyle(fontSize: 12, color: lavender),
                    ),
                    ReadingProgress(
                      percent: r.percent(true),
                      reduced: MediaQuery.disableAnimationsOf(context),
                      label: c.t('jy', 'progress'),
                    ),
                    OutlinedButton(
                      onPressed: _generating ? null : () => _generate(true),
                      child: Text(
                        c.t(
                          'report',
                          r.fullInProgress ? 'viewProgress' : 'retry',
                        ),
                      ),
                    ),
                  ],
                  if (!r.sectionedReport) ...[
                    const SizedBox(height: 20),
                    Text(
                      c.t('jy', 'chart.note'),
                      style: const TextStyle(fontSize: 12, color: lavender),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _model.exporting ? null : () => _model.export('pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
              label: Text(c.t('report', 'exportPdf')),
            ),
            OutlinedButton.icon(
              onPressed: _model.exporting ? null : () => _model.export('html'),
              icon: const Icon(Icons.download_outlined, size: 17),
              label: Text(c.t('report', 'save')),
            ),
            if (_model.exportStatus.isNotEmpty)
              Text(
                _model.exportStatus,
                style: const TextStyle(color: gold, fontSize: 12),
              ),
            TextButton(
              onPressed: _deleting ? null : () => _erase(),
              child: Text(c.t('jy', 'erase')),
            ),
            errorMessage(_deleteError),
            errorMessage(_model.error),
          ],
        ),
      );
    },
  );
  List<Widget> _readingSections(Iterable<Json> sections) => [
    for (final section in sections) ...[
      _sectionTitle(text(section['key']), text(section['title'])),
      for (final paragraph in (section['paragraphs'] as List? ?? []))
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(
            text(paragraph),
            style: const TextStyle(fontSize: 14, height: 1.8),
          ),
        ),
    ],
  ];

  List<Widget> _personalSections(LifeReport report, Copy c) => [
    _sectionTitle(
      report.sixPersonalThemes ? 'natal' : 'talent',
      c.t(
        'jy',
        report.sixPersonalThemes
            ? 'report.westernSections.natal'
            : 'personal.talent',
      ),
    ),
    if (report.talent.isNotEmpty) ...[
      Text(
        text(report.talent['text']),
        style: const TextStyle(fontSize: 14, height: 1.8),
      ),
      if (report.sixPersonalThemes)
        _sectionTitle('career', c.t('jy', 'report.westernSections.career')),
      for (final direction in objects(report.talent['directions']))
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text(direction['title']),
                style: const TextStyle(
                  color: gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text(direction['text']),
                style: const TextStyle(fontSize: 14, height: 1.8),
              ),
            ],
          ),
        ),
    ],
    if (report.sixPersonalThemes) ...[
      for (final key in ['wealth', 'love', 'risk']) ...[
        _sectionTitle(key, c.t('jy', 'report.westernSections.$key')),
        Text(
          text(object(report.personalThemes[key])['text']),
          style: const TextStyle(fontSize: 14, height: 1.8),
        ),
        _evidence(object(report.personalThemes[key])['evidence'], c),
      ],
      _sectionTitle('plan', c.t('jy', 'report.westernSections.plan')),
    ],
    for (final node in report.nodes.indexed) ...[
      _sectionTitle(
        'node-${node.$1 + 1}',
        '${node.$2['month']} · ${node.$2['theme']}',
      ),
      for (final field in ['benefit', 'caution', 'action'])
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.t('jy', 'personal.$field'),
                style: const TextStyle(
                  color: gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text(node.$2[field]),
                style: const TextStyle(fontSize: 14, height: 1.8),
              ),
            ],
          ),
        ),
      _evidence(node.$2['evidence'], c),
    ],
  ];

  Widget _sectionTitle(String key, String title) => Container(
    key: _key('report-$key'),
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.only(top: 15, bottom: 10),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: line)),
    ),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xFFF4D399),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
