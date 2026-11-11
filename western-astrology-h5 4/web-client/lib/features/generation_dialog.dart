import 'dart:async';
import 'package:flutter/material.dart';
import 'generation_video.dart'
    if (dart.library.js_interop) 'generation_video_web.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';
import 'report_chart.dart';

class GenerationState extends ChangeNotifier {
  double percent = 0;
  String phase = 'preview', error = '';
  LifeReport? report;
  bool complete = false;
  void retry() {
    error = '';
    complete = false;
    notifyListeners();
  }

  void update(LifeReport report, double value, String phase) {
    this.report = report;
    percent = value;
    this.phase = phase;
    notifyListeners();
  }

  void fail(String value) {
    error = value;
    notifyListeners();
  }

  void ready(LifeReport value) {
    report = value;
    percent = 100;
    phase = 'ready';
    complete = true;
    notifyListeners();
  }
}

class GenerationDialog extends StatefulWidget {
  const GenerationDialog({
    required this.h5,
    required this.state,
    required this.full,
    required this.onCancel,
    required this.onRetry,
    required this.onComplete,
    this.input,
    super.key,
  });
  final H5Controller h5;
  final GenerationState state;
  final bool full;
  final Json? input;
  final VoidCallback onCancel, onRetry;
  final void Function(LifeReport) onComplete;
  @override
  State<GenerationDialog> createState() => _GenerationDialogState();
}

class _GenerationDialogState extends State<GenerationDialog> {
  Timer? _reviewTimer, _stageTimer, _detailsTimer, _fallback;
  int _step = 0, _detail = 0;
  bool _prepared = false,
      _reduced = false,
      _reviewDone = false,
      _presentationDone = false,
      _loading = false,
      _playbackStarted = false,
      _navigating = false;
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    final input = widget.input ?? widget.state.report?.input ?? {};
    final count =
        text(input['user_question']).isNotEmpty ||
            object(input['career_question']).isNotEmpty
        ? 4
        : 3;
    if (_reduced) {
      _step = 2;
      _reviewDone = true;
      _presentationDone = true;
    } else {
      _detailsTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
        if (mounted && !_loading && widget.state.error.isEmpty) {
          setState(() => _detail = (_detail + 1) % count);
        }
      });
      _reviewTimer = Timer(Duration(milliseconds: 650 * count), () {
        _reviewDone = true;
        _advance();
      });
    }
    _changed();
  }

  void _changed() {
    if (!mounted || !_prepared) return;
    if (widget.state.error.isNotEmpty) {
      return;
    }
    _advance();
  }

  void _advance() {
    if (!mounted || !_reviewDone || widget.state.error.isNotEmpty) return;
    if (!_reduced && _step == 0 && widget.state.report != null) {
      setState(() => _step = 1);
      _stageTimer = Timer(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        setState(() => _step = 2);
        _stageTimer = Timer(const Duration(milliseconds: 2600), () {
          _presentationDone = true;
          _advance();
        });
      });
    }
    if (_presentationDone && widget.state.complete && !_loading) {
      _loading = true;
      _detailsTimer?.cancel();
      setState(() {});
      _stageTimer = Timer(Duration(milliseconds: _reduced ? 250 : 500), () {
        if (!mounted) return;
        if (_reduced) {
          _finishSoon();
          return;
        }
        setState(() => _playbackStarted = true);
      });
    }
  }

  void _finishSoon() {
    _fallback ??= Timer(const Duration(milliseconds: 550), _finish);
  }

  void _finish() {
    if (!mounted || _navigating || !widget.state.complete) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete(widget.state.report!);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    for (final timer in [_reviewTimer, _stageTimer, _detailsTimer, _fallback]) {
      timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    const keys = ['basics', 'placements', 'reading'];
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF0B0715),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.84),
                  radius: 1.4,
                  colors: [
                    Color(0xFF392353),
                    Color(0xFF160D29),
                    Color(0xFF0C0816),
                  ],
                  stops: [0, .5, 1],
                ),
              ),
              child: SizedBox.expand(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final pad = (box.maxWidth * .05).clamp(14.0, 24.0);
                    return Stack(
                      children: [
                        SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              pad,
                              44 + MediaQuery.paddingOf(context).top,
                              pad,
                              24,
                            ),
                            child: ListenableBuilder(
                              listenable: widget.state,
                              builder: (context, _) {
                                final state = widget.state,
                                    report = state.report,
                                    input = widget.input ?? report?.input ?? {};
                                final complete = state.complete;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const FateBrand(compact: true),
                                    const SizedBox(height: 10),
                                    Text(
                                      c.t('jy', 'interpretation.title'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: (box.maxWidth * .06).clamp(
                                          20.0,
                                          28.0,
                                        ),
                                        height: 1.3,
                                        color: const Color(0xFFFFEDCC),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    AnimatedSwitcher(
                                      duration: Duration(
                                        milliseconds: _reduced ? 0 : 380,
                                      ),
                                      child: JYCard(
                                        key: ValueKey(
                                          _loading ? 'loading' : _step,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 122,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                c.t(
                                                  'jy',
                                                  _loading
                                                      ? 'generation.method'
                                                      : 'interpretation.steps.${keys[_step]}.title',
                                                ),
                                                style: const TextStyle(
                                                  color: Color(0xFFF4D399),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (_step == 0)
                                                _BirthDetails(
                                                  input: input,
                                                  copy: c,
                                                  index: _detail,
                                                  reduced: _reduced,
                                                ),
                                              if (_step == 1 && report != null)
                                                PlacementMetrics(
                                                  report: report,
                                                  copy: c,
                                                ),
                                              if (_step == 2 && !_loading)
                                                ReportFactors(
                                                  report: report,
                                                  copy: c,
                                                ),
                                              if (_loading) ...[
                                                Text(
                                                  c.t('jy', 'chart.wheel'),
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  c.t(
                                                    'jy',
                                                    report?.estimated == true
                                                        ? 'chart.dateOnly'
                                                        : 'chart.exact',
                                                  ),
                                                  style: const TextStyle(
                                                    color: gold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  c.t('jy', 'generation.basis'),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: lavender,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    JYCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              for (final entry in keys.indexed)
                                                Expanded(
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        width: 19,
                                                        height: 19,
                                                        alignment:
                                                            Alignment.center,
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color:
                                                              !complete &&
                                                                  entry.$1 ==
                                                                      _step
                                                              ? const Color(
                                                                  0xFFF4D399,
                                                                )
                                                              : const Color(
                                                                  0xFF150D25,
                                                                ),
                                                        ),
                                                        child: Text(
                                                          complete ||
                                                                  entry.$1 <
                                                                      _step
                                                              ? '✓'
                                                              : '${entry.$1 + 1}',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                !complete &&
                                                                    entry.$1 ==
                                                                        _step
                                                                ? const Color(
                                                                    0xFF281733,
                                                                  )
                                                                : gold,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Expanded(
                                                        child: Text(
                                                          c.t(
                                                            'jy',
                                                            'interpretation.steps.${entry.$2}.title',
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            height: 1.4,
                                                            color:
                                                                entry.$1 <=
                                                                    _step
                                                                ? const Color(
                                                                    0xFFF4D399,
                                                                  )
                                                                : const Color(
                                                                    0xFFC1B2D4,
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(
                                            height: 1,
                                            color: Color(0x33E4BC78),
                                          ),
                                          const SizedBox(height: 14),
                                          AnimatedOpacity(
                                            opacity: _loading ? 0 : 1,
                                            duration: Duration(
                                              milliseconds: _reduced ? 0 : 550,
                                            ),
                                            child: Text(
                                              c.t(
                                                'jy',
                                                complete
                                                    ? 'interpretation.complete'
                                                    : 'interpretation.steps.${keys[_step]}.status',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFFFFF1D9),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          ReadingProgress(
                                            percent: state.percent,
                                            reduced: _reduced,
                                            label: c.t('jy', 'progress'),
                                          ),
                                          if (!complete)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Text(
                                                '${c.t('jy', 'interpretation.next')} · ${_step < 2 ? c.t('jy', 'interpretation.steps.${keys[_step + 1]}.title') : c.t('jy', 'checkout.title')}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: lavender,
                                                ),
                                              ),
                                            ),
                                          errorMessage(state.error),
                                          if (state.error.isNotEmpty)
                                            OutlinedButton(
                                              onPressed: widget.onRetry,
                                              child: Text(
                                                c.t('generation', 'retry'),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!_loading)
                                      Align(
                                        alignment: Alignment.center,
                                        child: TextButton(
                                          onPressed: widget.onCancel,
                                          child: Text(
                                            c.t('generation', 'cancel'),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: lavender,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: box.maxHeight * .52,
                          height: (box.maxHeight * .4).clamp(180.0, 340.0),
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: .78,
                              child: GenerationVideo(
                                active: true,
                                finishing:
                                    _loading && (_reduced || _playbackStarted),
                                reduced: _reduced,
                                onFinished: _finish,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BirthDetails extends StatelessWidget {
  const _BirthDetails({
    required this.input,
    required this.copy,
    required this.index,
    required this.reduced,
  });
  final Json input;
  final Copy copy;
  final int index;
  final bool reduced;
  @override
  Widget build(BuildContext context) {
    final p = object(input['profile']),
        career = object(input['career_question']);
    final question = text(input['user_question']).isNotEmpty
        ? text(input['user_question'])
        : career.isNotEmpty
        ? copy.t('career', 'situations.${career['stage']}.question')
        : '';
    final rows = [
      (copy.t('jy', 'date'), text(p['birth_date'])),
      (
        copy.t('jy', 'time'),
        text(p['birth_time']).isEmpty
            ? copy.t('jy', 'unknown')
            : text(p['birth_time']),
      ),
      (copy.t('jy', 'generation.birthplace'), text(p['birthplace'])),
      if (question.isNotEmpty) (copy.t('jy', 'generation.question'), question),
    ];
    Widget row((String, String) item) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            item.$1,
            style: const TextStyle(color: Color(0xFFF4D399), fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.$2,
              style: const TextStyle(fontSize: 14, color: Color(0xFFFFF1D9)),
            ),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 108),
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          child: reduced
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows.map(row).toList(),
                )
              : TweenAnimationBuilder<double>(
                  key: ValueKey(index),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  builder: (context, t, child) => Opacity(
                    opacity: t < .2
                        ? t / .2
                        : t > .72
                        ? (1 - t) / .28
                        : 1,
                    child: Transform.translate(
                      offset: Offset(0, 22 - 44 * t),
                      child: child,
                    ),
                  ),
                  child: row(rows[index % rows.length]),
                ),
        ),
      ),
    );
  }
}

class ReadingProgress extends StatelessWidget {
  const ReadingProgress({
    required this.percent,
    required this.reduced,
    required this.label,
    super.key,
  });
  final double percent;
  final bool reduced;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${percent.round()}%',
    child: Row(
      children: [
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100),
            duration: Duration(milliseconds: reduced ? 0 : 450),
            curve: Curves.easeOut,
            builder: (context, value, _) => LayoutBuilder(
              builder: (context, box) => SizedBox(
                height: 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF55435C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: box.maxWidth * value,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF976234), Color(0xFFFFDA91)],
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x9CFFD17E), blurRadius: 12),
                        ],
                      ),
                    ),
                    Positioned(
                      left: box.maxWidth * value - 12,
                      child: const Text(
                        '✦',
                        style: TextStyle(
                          color: Color(0xFFFFF2CB),
                          fontSize: 26,
                          height: 1,
                          shadows: [
                            Shadow(color: Color(0xFFFFD17E), blurRadius: 6),
                            Shadow(color: Color(0xFFFFB96F), blurRadius: 15),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 40,
          child: Text(
            '${percent.round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFFFE3AE),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
