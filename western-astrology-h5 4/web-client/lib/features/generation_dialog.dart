import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'generation_video.dart'
    if (dart.library.js_interop) 'generation_video_web.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
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

class AppLoginCodePanel extends StatefulWidget {
  const AppLoginCodePanel({
    required this.h5,
    required this.reportId,
    this.issueOnOpen = false,
    super.key,
  });

  final H5Controller h5;
  final String reportId;
  final bool issueOnOpen;

  @override
  State<AppLoginCodePanel> createState() => _AppLoginCodePanelState();
}

class _AppLoginCodePanelState extends State<AppLoginCodePanel> {
  Future<AppLoginCode>? _request;
  Timer? _expiry;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _track(
      widget.issueOnOpen
          ? widget.h5.requestAppLoginCode(widget.reportId)
          : widget.h5.currentAppLoginCode,
    );
  }

  void _track(Future<AppLoginCode>? request) {
    _expiry?.cancel();
    _request = request;
    _copied = false;
    unawaited(
      request?.then<void>((code) {
        if (mounted && _request == request && !code.expired) {
          _expiry = Timer(code.expiresAt.difference(DateTime.now()), () {
            if (mounted) setState(() {});
          });
        }
      }, onError: (Object _, StackTrace _) {}),
    );
  }

  Future<void> _copy(AppLoginCode code) async {
    if (code.expired) {
      setState(() {});
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: code.value));
      if (mounted) setState(() => _copied = true);
    } catch (_) {
      // The code can still be selected manually.
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    String label(String key) => c.t('jy', 'appLogin.$key');
    return JYCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label('title'),
            style: const TextStyle(color: gold, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          FutureBuilder<AppLoginCode>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label('loading')),
                );
              }
              final code = snapshot.data;
              return Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  if (snapshot.hasError) Text(label('failed')),
                  if (code?.expired == true) Text(label('expired')),
                  if (code != null && !code.expired) ...[
                    SelectableText(
                      code.value,
                      key: const ValueKey('h5-app-login-code'),
                      style: const TextStyle(
                        fontSize: 21,
                        letterSpacing: 3,
                        color: cream,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _copy(code),
                      child: Text(label(_copied ? 'copied' : 'copy')),
                    ),
                  ],
                  TextButton(
                    onPressed: () => setState(
                      () => _track(
                        widget.h5.requestAppLoginCode(
                          widget.reportId,
                          refresh: true,
                        ),
                      ),
                    ),
                    child: Text(label(_request == null ? 'get' : 'refresh')),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
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
  Timer? _reviewTimer, _stageTimer, _detailsTimer, _finishTimer;
  int _step = 0, _detail = 0;
  bool _prepared = false,
      _reduced = false,
      _reviewDone = false,
      _finishing = false,
      _navigating = false;

  Duration get _finishDuration => _reduced || !widget.full
      ? Duration.zero
      : const Duration(milliseconds: 320);
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) {
      _changed();
      return;
    }
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
    } else {
      _detailsTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
        if (mounted && widget.state.error.isEmpty) {
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
    if (!mounted || !_prepared || _navigating) return;
    if (!widget.state.complete || widget.state.error.isNotEmpty) {
      if (_finishing) {
        _finishTimer?.cancel();
        setState(() => _finishing = false);
      }
      _advance();
      return;
    }
    if (_finishing || ModalRoute.isCurrentOf(context) != true) return;
    _reviewTimer?.cancel();
    _stageTimer?.cancel();
    _detailsTimer?.cancel();
    setState(() => _finishing = true);
    _finishTimer = Timer(_finishDuration, _finish);
  }

  void _advance() {
    if (!mounted ||
        !_reviewDone ||
        _finishing ||
        widget.state.error.isNotEmpty) {
      return;
    }
    if (!_reduced && _step == 0 && widget.state.report != null) {
      setState(() => _step = 1);
      _stageTimer = Timer(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        setState(() => _step = 2);
      });
    }
  }

  void _finish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigating || !_finishing) return;
      if (ModalRoute.isCurrentOf(context) != true ||
          !widget.state.complete ||
          widget.state.error.isNotEmpty) {
        setState(() => _finishing = false);
        return;
      }
      _navigating = true;
      widget.onComplete(widget.state.report!);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    for (final timer in [
      _reviewTimer,
      _stageTimer,
      _detailsTimer,
      _finishTimer,
    ]) {
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
            constraints: const BoxConstraints(maxWidth: h5PageMaxWidth),
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
                    final shortScreen = box.maxHeight < 720;
                    final videoTop =
                        (box.maxHeight * (shortScreen ? .66 : .52) - 40).clamp(
                          0.0,
                          360.0,
                        );
                    final videoHeight =
                        ((box.maxHeight * (shortScreen ? .30 : .4)).clamp(
                                  160.0,
                                  340.0,
                                ) +
                                110)
                            .clamp(0.0, box.maxHeight - videoTop);
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
                                final marriageFailed =
                                    widget.full &&
                                    report?.marriageFullFailed == true &&
                                    state.error.isNotEmpty;
                                final waiting =
                                    !complete &&
                                    state.error.isEmpty &&
                                    state.percent == 0;
                                final status = state.error.isNotEmpty
                                    ? 'interpretation.interrupted'
                                    : complete
                                    ? 'interpretation.complete'
                                    : state.phase == 'reconnecting'
                                    ? 'interpretation.reconnecting'
                                    : state.phase == 'waiting'
                                    ? 'interpretation.waiting'
                                    : state.phase == 'queued'
                                    ? 'interpretation.queued'
                                    : state.phase == 'calculating'
                                    ? 'interpretation.preparing'
                                    : state.percent >= 99
                                    ? 'interpretation.validating'
                                    : state.percent == 0
                                    ? report == null
                                          ? 'interpretation.preparing'
                                          : 'interpretation.awaitingContent'
                                    : 'interpretation.steps.${keys[_step]}.status';
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const FateBrand(compact: true),
                                    const SizedBox(height: 10),
                                    Text(
                                      c.t(
                                        'jy',
                                        state.error.isNotEmpty
                                            ? 'interpretation.interruptedTitle'
                                            : 'interpretation.title',
                                      ),
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
                                    if (report != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: AppLoginCodePanel(
                                          key: ValueKey(report.id),
                                          h5: widget.h5,
                                          reportId: report.id,
                                          issueOnOpen: true,
                                        ),
                                      ),
                                    AnimatedSwitcher(
                                      duration: Duration(
                                        milliseconds: _reduced ? 0 : 380,
                                      ),
                                      child: JYCard(
                                        key: ValueKey(_step),
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
                                                  'interpretation.steps.${keys[_step]}.title',
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
                                              if (_step == 2)
                                                ReportFactors(
                                                  report: report,
                                                  copy: c,
                                                ),
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
                                          Text(
                                            c.t('jy', status),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFFFFF1D9),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (!marriageFailed)
                                            ReadingProgress(
                                              percent: state.percent,
                                              reduced: _reduced || complete,
                                              label: c.t('jy', 'progress'),
                                              waiting: waiting,
                                              waitingLabel: c.t(
                                                'jy',
                                                'interpretation.waitLabel',
                                              ),
                                            ),
                                          if (!complete && state.error.isEmpty)
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
                                          if (!marriageFailed)
                                            errorMessage(state.error),
                                          if (state.error.isNotEmpty)
                                            OutlinedButton(
                                              onPressed: widget.onRetry,
                                              child: Text(
                                                c.t(
                                                  'jy',
                                                  widget.full
                                                      ? 'interpretation.retryFull'
                                                      : 'interpretation.retryFree',
                                                ),
                                              ),
                                            ),
                                        ],
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
                          top: videoTop,
                          height: videoHeight,
                          child: IgnorePointer(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: pad,
                                vertical: 16,
                              ),
                              child: Center(
                                // The video and fallback artwork are both 768 x 512.
                                child: AspectRatio(
                                  aspectRatio: 3 / 2,
                                  child: ListenableBuilder(
                                    listenable: widget.state,
                                    builder: (context, _) => AnimatedOpacity(
                                      opacity: _finishing ? 0 : 1,
                                      duration: _finishDuration,
                                      child: GenerationVideo(
                                        active: widget.state.error.isEmpty,
                                        reduced: _reduced,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!_finishing)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12 + MediaQuery.paddingOf(context).bottom,
                            child: Center(
                              child: TextButton(
                                onPressed: widget.onCancel,
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xB30B0715),
                                ),
                                child: Text(
                                  c.t('generation', 'cancel'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: lavender,
                                  ),
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
    this.waiting = false,
    this.waitingLabel = '',
    super.key,
  });
  final double percent;
  final bool reduced, waiting;
  final String label, waitingLabel;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: percent.clamp(0, 100) / 100),
    duration: Duration(milliseconds: reduced ? 0 : 600),
    curve: Curves.easeOut,
    builder: (context, value, _) => Semantics(
      label: label,
      value: waiting ? waitingLabel : '${(value * 100).round()}%',
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SizedBox(
                height: 26,
                child: waiting
                    ? Center(
                        child: LinearProgressIndicator(
                          value: reduced ? 0 : null,
                          minHeight: 4,
                          color: const Color(0xFFFFDA91),
                          backgroundColor: const Color(0xFF55435C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : Stack(
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
                                BoxShadow(
                                  color: Color(0x9CFFD17E),
                                  blurRadius: 12,
                                ),
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
                                  Shadow(
                                    color: Color(0xFFFFD17E),
                                    blurRadius: 6,
                                  ),
                                  Shadow(
                                    color: Color(0xFFFFB96F),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: waiting ? 58 : 40,
            child: Text(
              waiting ? waitingLabel : '${(value * 100).round()}%',
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
    ),
  );
}
