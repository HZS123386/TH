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
    this.checkout = false,
    super.key,
  });
  final H5Controller h5;
  final String id;
  final bool checkout;
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with WidgetsBindingObserver {
  late final _model = ReportViewModel(widget.h5, widget.id);
  CancelToken? _generationRequest;
  final _anchors = <String, GlobalKey>{};
  final _deleteRequest = CancelToken();
  bool _deleting = false;
  String _deleteError = '';
  bool _reported = false, _reportedFull = false, _generating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model.addListener(_changed);
    unawaited(_model.load());
  }

  void _changed() {
    final r = _model.report;
    if (r == null) return;
    if (!_reported && r.full && r.preview.isNotEmpty) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.h5.browser.pageReady('report-content');
          unawaited(widget.h5.trackReport(r.id, 'seen'));
        }
      });
    }
    if (!_reportedFull && r.ready) {
      _reportedFull = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.h5.browser.pageReady('report-full-content');
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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

  Future<void> _generate(bool full) async {
    final initial = _model.report;
    if (initial == null || _generating) return;
    _generating = true;
    final state = GenerationState()..phase = full ? 'full' : 'preview';
    Future<void> run() async {
      _generationRequest?.cancel();
      final token = CancelToken();
      _generationRequest = token;
      state.retry();
      try {
        final result = full
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
        if (mounted && !token.cancelled) state.fail(widget.h5.message(error));
      }
    }

    unawaited(run());
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) => GenerationDialog(
          h5: widget.h5,
          state: state,
          full: full,
          input: initial.input,
          onCancel: () {
            _generationRequest?.cancel();
            Navigator.of(context, rootNavigator: true).pop();
          },
          onRetry: () => unawaited(run()),
          onComplete: (r) {
            Navigator.of(context, rootNavigator: true).pop();
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
    _generating = false;
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
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        c.t('report', 'summaryEvidence'),
        style: const TextStyle(fontSize: 11, color: lavender),
      ),
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text(item['title']),
                  style: const TextStyle(color: gold, fontSize: 12),
                ),
                Text(
                  text(item['detail']),
                  style: Theme.of(context).textTheme.bodySmall,
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
        Text(
          text(value['text']),
          style: const TextStyle(fontSize: 14, height: 1.65),
        ),
        _evidence(value['evidence'], c),
      ],
    ),
  );
  Widget _point(Json point, Copy c, {String? anchor}) => Padding(
    key: anchor == null ? null : _key(anchor),
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                '${c.language == 'zh' ? {'example': '生活中的例子', 'pitfall': '避免这样做', 'check': '怎样检查效果'}[field] : {'example': 'ตัวอย่างในชีวิต', 'pitfall': 'สิ่งที่ควรเลี่ยง', 'check': 'วิธีสังเกตผล'}[field]}\n${point[field]}',
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
          for (final group in [
            (
              'insights',
              c.language == 'zh'
                  ? '这对你意味着什么'
                  : 'สิ่งนี้มีความหมายกับคุณอย่างไร',
            ),
            ('watchpoints', c.language == 'zh' ? '需要留意的地方' : 'สิ่งที่ควรใส่ใจ'),
            ('actions', c.language == 'zh' ? '你可以这样做' : 'สิ่งที่คุณลองทำได้'),
          ])
            if (objects(chapter[group.$1]).isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                group.$2,
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              for (final entry in objects(chapter[group.$1]).indexed)
                _point(
                  entry.$2,
                  c,
                  anchor: group.$1 == 'actions'
                      ? 'action-$name-${entry.$1}'
                      : null,
                ),
            ],
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
          c = r == null ? widget.h5.copy : widget.h5.copy.forReport(r);
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
                TextButton(
                  onPressed: () => context.go('/?lang=${widget.h5.language}'),
                  child: Text(c.t('jy', 'checkout.back')),
                ),
              ],
            ),
          ),
        );
      }
      if (!r.full && r.preview.isNotEmpty) {
        return ReportCheckout(
          h5: widget.h5,
          report: r,
          busy: _deleting,
          error: _deleteError.isNotEmpty ? _deleteError : _model.error,
          onBack: () => context.go('/?lang=${widget.h5.language}'),
          onErase: () => _erase(),
        );
      }
      if (r.preview.isEmpty) {
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
                  label: c.t('report', 'retryPreview'),
                  onPressed: _generating ? null : () => _generate(false),
                ),
                TextButton(
                  onPressed: () => context.go('/?lang=${widget.h5.language}'),
                  child: Text(c.t('jy', 'checkout.back')),
                ),
              ],
            ),
          ),
        );
      }
      const groups = [
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
                  tooltip: c.t('jy', 'checkout.back'),
                  onPressed: () => context.go('/?lang=${widget.h5.language}'),
                  icon: const Icon(Icons.arrow_back, color: gold, size: 19),
                ),
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
            const SizedBox(height: 18),
            JYCard(
              padding: const EdgeInsets.all(24),
              radius: 20,
              borderColor: line,
              colors: const [panel, panel],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FATE / ${c.t('jy', 'topics.life.label')}',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.t('jy', 'report.title'),
                    style: const TextStyle(
                      color: Color(0xFFFFEAC5),
                      fontSize: 23,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${r.profile['birthplace']} · ${c.t('jy', r.estimated ? 'chart.dateOnly' : 'chart.exact')}',
                    style: const TextStyle(color: lavender, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  JYCard(
                    radius: 15,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    child: Column(
                      children: [
                        Text(
                          c.t('jy', 'report.contents'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ReportBadges(copy: c, locked: false, onTap: _navigate),
                      ],
                    ),
                  ),
                  _sectionTitle('overall', c.t('jy', 'chart.title')),
                  ChartView(report: r, copy: c),
                  for (final key in ['annual', 'overall'])
                    for (final item in r.catalog.where(
                      (item) => item['key'] == key,
                    ))
                      _chapter(r, item, c),
                  for (final group in groups) ...[
                    _sectionTitle(
                      group.$1,
                      c.t('jy', 'report.sections.${group.$1}'),
                    ),
                    if (group.$1 == 'natal') ...[
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
                    if (group.$1 == 'opportunities') _plan(r, c),
                  ],
                  if (!r.ready) ...[
                    const SizedBox(height: 16),
                    ReadingProgress(
                      percent: r.percent(true),
                      reduced: MediaQuery.disableAnimationsOf(context),
                      label: c.t('jy', 'progress'),
                    ),
                    OutlinedButton(
                      onPressed: _generating ? null : () => _generate(true),
                      child: Text(c.t('report', 'retry')),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    c.t('jy', 'chart.note'),
                    style: const TextStyle(fontSize: 12, color: lavender),
                  ),
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
