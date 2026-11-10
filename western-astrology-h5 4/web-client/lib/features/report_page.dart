import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
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
  final _expanded = <String>{};
  bool _reported = false,
      _reportedFull = false,
      _checkoutOpened = false,
      _buying = false,
      _generating = false;
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
    if (!_reported && r.preview.isNotEmpty) {
      _reported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.h5.browser.pageReady('report-content');
      });
    }
    if (!_reportedFull && r.ready) {
      _reportedFull = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.h5.browser.pageReady('report-full-content');
      });
    }
    if (widget.checkout &&
        !_checkoutOpened &&
        !r.full &&
        r.preview.isNotEmpty) {
      _checkoutOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_buy());
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
    _model.removeListener(_changed);
    _model.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _buy() async {
    final r = _model.report;
    if (r == null || r.full || _buying || _generating) return;
    _buying = true;
    try {
      final confirmed = await showCheckout(context, widget.h5, r);
      if (confirmed == true && mounted) await _generate(true);
    } finally {
      _buying = false;
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
        if (mounted && !token.cancelled) state.ready(result);
      } catch (error) {
        if (mounted && !token.cancelled) state.fail(widget.h5.message(error));
      }
    }

    unawaited(run());
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GenerationDialog(
        h5: widget.h5,
        state: state,
        full: full,
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
          if (full && r.catalog.isNotEmpty) {
            final key = text(r.catalog.first['key']);
            setState(() => _expanded.add(key));
            _navigate(key);
          }
        },
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

  Widget _summary(Json value, Copy c) => Panel(
    highlight: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text(value['text']),
          style: const TextStyle(fontSize: 17, height: 1.95),
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
  Widget _actions(Copy c, LifeReport r, {bool compact = false}) => Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          key: ValueKey(compact ? 'life-sticky-app' : 'life-app-button'),
          onPressed: () {},
          icon: const Icon(Icons.download_outlined, size: 17),
          label: Text(
            c.t('report', compact ? 'downloadAppShort' : 'downloadApp'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          key: ValueKey(compact ? 'life-sticky-buy' : 'life-unlock-button'),
          onPressed: () => _buy(),
          icon: const Icon(Icons.lock_outline, size: 16),
          label: Text(
            '${r.priceLabel}\n${c.t('report', 'buyReading')}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ],
  );
  Widget _chapter(LifeReport r, Json item, Copy c) {
    final name = text(item['key']);
    final matching = r.chapters.where((chapter) => chapter['key'] == name);
    final chapter = matching.isEmpty ? null : matching.first;
    final opened = _expanded.contains(name);
    return Padding(
      key: _key(name),
      padding: const EdgeInsets.only(top: 16),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: opened,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: chapter == null
                    ? null
                    : () => setState(() {
                        if (opened) {
                          _expanded.remove(name);
                        } else {
                          _expanded.add(name);
                        }
                      }),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text(item['title']),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (chapter == null)
                              Text(
                                c.t('report', 'states.${r.json['full_state']}'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        opened ? Icons.expand_less : Icons.expand_more,
                        color: gold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (opened && chapter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summary(object(chapter['summary']), c),
                    for (final group in [
                      (
                        'insights',
                        c.language == 'zh'
                            ? '这对你意味着什么'
                            : 'สิ่งนี้มีความหมายกับคุณอย่างไร',
                      ),
                      (
                        'watchpoints',
                        c.language == 'zh' ? '需要留意的地方' : 'สิ่งที่ควรใส่ใจ',
                      ),
                      (
                        'actions',
                        c.language == 'zh' ? '你可以这样做' : 'สิ่งที่คุณลองทำได้',
                      ),
                    ])
                      if (objects(chapter[group.$1]).isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          group.$2,
                          style: const TextStyle(
                            color: gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _plan(LifeReport r, Copy c) {
    if (r.plan.isEmpty) return const SizedBox.shrink();
    final open = _expanded.contains('plan');
    return Padding(
      key: _key('plan'),
      padding: const EdgeInsets.only(top: 20),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() {
                if (open) {
                  _expanded.remove('plan');
                } else {
                  _expanded.add('plan');
                }
              }),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.t('report', 'plan'),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: gold,
                  ),
                ],
              ),
            ),
            if (open)
              for (final phase in objects(r.plan['phases'])) ...[
                _point(phase, c),
                for (final action in objects(phase['actions'])) ...[
                  _point(action, c),
                  TextButton(
                    onPressed: () {
                      final target = text(action['chapter']);
                      setState(() => _expanded.add(target));
                      _navigate('action-$target-${action['index']}');
                    },
                    child: Text('${c.t('report', 'viewAction')} →'),
                  ),
                ],
              ],
          ],
        ),
      ),
    );
  }

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
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FATE · ${c.t('report', 'eyebrow')}',
                          style: const TextStyle(color: gold, fontSize: 11),
                        ),
                      ),
                      IconButton(
                        tooltip: c.t('report', 'exportPdf'),
                        onPressed: _model.exporting
                            ? null
                            : () => _model.export('pdf'),
                        icon: _model.exporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_outlined,
                                color: gold,
                              ),
                      ),
                    ],
                  ),
                  SectionTitle(
                    text(r.json['title']),
                    subtitle: c.t('report', 'subtitle'),
                  ),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.t('report', 'birth'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${r.profile['birth_date']} · ${r.profile['birth_time'] ?? c.t('report', 'timeUnknown')}',
                        ),
                        Text(
                          '${Place(object(r.json['location'])).label(c.language)}\n${r.profile['timezone']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${c.t('report', 'timeRange')} · ${object(r.json['reference_period'])['start'] ?? r.input['year']} ${object(r.json['reference_period'])['end'] ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (r.estimated)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              c.t('ui', 'timeNote'),
                              style: const TextStyle(fontSize: 12, color: gold),
                            ),
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            c.t('report', 'evidence'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: lavender,
                            ),
                          ),
                          children: [
                            Text(c.t('report', 'methodValue')),
                            Text(
                              '${r.json['created_at']}\n${c.t('report', 'number')}: ${r.id}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (r.preview.isNotEmpty) ...[
                    SectionTitle(c.t('report', 'takeaway')),
                    _summary(object(r.preview['summary']), c),
                    if (r.preview['career_answer'] != null) ...[
                      const SizedBox(height: 20),
                      SectionTitle(c.t('report', 'careerQuestionTitle')),
                      _summary(object(r.preview['career_answer']), c),
                    ],
                    if (text(r.input['user_question']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          text(r.input['user_question']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: gold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    SectionTitle(c.t('report', 'traits')),
                    for (final point in objects(r.preview['traits']))
                      Panel(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 15),
                        child: _point(point, c),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      c.t('report', 'feedback'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in [
                          'close',
                          'partly',
                          'different',
                        ].indexed)
                          ChoiceChip(
                            label: Text(
                              c.list('report', 'feedbackOptions')[entry.$1],
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: r.json['feedback'] == entry.$2,
                            onSelected: _model.feedbackBusy
                                ? null
                                : (_) => _model.feedback(entry.$2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.t(
                        'report',
                        r.json['feedback'] == null
                            ? 'feedbackHint'
                            : 'feedbackSaved',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...[
                    Text(
                      c.t('report', 'previewStates.${r.json['preview_state']}'),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => _generate(false),
                      child: Text(c.t('report', 'retryPreview')),
                    ),
                  ],
                  const Divider(),
                  SectionTitle(
                    c.t('report', 'catalog'),
                    subtitle: c.t('report', 'catalogHint'),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      for (final item in r.catalog)
                        ActionChip(
                          avatar: Icon(
                            r.full
                                ? Icons.menu_book_outlined
                                : Icons.lock_outline,
                            size: 15,
                            color: gold,
                          ),
                          label: Text(
                            text(item['title']),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: r.full
                              ? () {
                                  final key = text(item['key']);
                                  setState(() => _expanded.add(key));
                                  _navigate(key);
                                }
                              : null,
                        ),
                    ],
                  ),
                  if (!r.full && r.preview.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ExcludeSemantics(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: Panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final item in r.catalog.take(3))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            text(item['title']),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            (item['questions'] as List? ?? [])
                                                .join(' · '),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: panel,
                          child: Icon(
                            Icons.lock_outline,
                            color: gold,
                            size: 31,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Panel(
                      highlight: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle(
                            c.t('report', 'offerTitle'),
                            subtitle: c.t('report', 'offerText'),
                          ),
                          for (final benefit in c.list('report', 'benefits'))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '✓ $benefit',
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          _actions(c, r),
                          const SizedBox(height: 12),
                          Text(
                            c.t('report', 'once'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (r.full) ...[
                    const SizedBox(height: 20),
                    Text(
                      c.t('report', 'full'),
                      style: const TextStyle(
                        color: gold,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!r.ready) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: r.percent(true) / 100),
                      Text(
                        '${r.percent(true).round()}% · ${c.t('report', 'states.${r.json['full_state']}')}',
                      ),
                      OutlinedButton(
                        onPressed: () => _generate(true),
                        child: Text(c.t('report', 'retry')),
                      ),
                    ],
                    for (final item in r.catalog) _chapter(r, item, c),
                    _plan(r, c),
                  ],
                  const Divider(),
                  Text(
                    c.t('report', 'printHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _model.exporting
                        ? null
                        : () => _model.export('html'),
                    icon: const Icon(Icons.download_outlined, size: 17),
                    label: Text(
                      c.t('report', r.ready ? 'save' : 'savePreview'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _model.exporting
                        ? null
                        : () => _model.export('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: Text(c.t('report', 'exportPdf')),
                  ),
                  if (_model.exportStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _model.exportStatus,
                          style: const TextStyle(color: gold, fontSize: 12),
                        ),
                      ),
                    ),
                  errorMessage(_model.error),
                ],
              ),
            ),
          ),
          if (!r.full && r.preview.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: panel,
                  border: Border(top: BorderSide(color: line)),
                ),
                padding: const EdgeInsets.all(12),
                child: _actions(c, r, compact: true),
              ),
            ),
        ],
      );
    },
  );
}
