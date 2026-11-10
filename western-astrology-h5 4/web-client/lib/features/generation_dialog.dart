import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../ui/theme.dart';

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

class _GenerationDialogState extends State<GenerationDialog>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _prepared = false, _navigating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(_changed);
    _changed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prepared) {
      _prepared = true;
      if (!MediaQuery.disableAnimationsOf(context)) unawaited(_prepareVideo());
    }
  }

  Future<void> _prepareVideo() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.base.resolve('media/report-loading-web.mp4'),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = controller;
    try {
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.initialize();
      if (mounted) {
        await controller.play();
        setState(() {});
      }
    } catch (_) {
      /* The poster remains visible if inline video is unavailable. */
    }
  }

  void _changed() {
    if (widget.state.complete && !_navigating) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete(widget.state.report!);
      });
    }
    if (widget.state.error.isNotEmpty) {
      unawaited(_video?.pause());
    } else if (widget.h5.browser.visible) {
      unawaited(_video?.play());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.state.error.isEmpty) {
      unawaited(_video?.play());
    } else {
      unawaited(_video?.pause());
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: ListenableBuilder(
                listenable: widget.state,
                builder: (context, _) {
                  final state = widget.state;
                  final report = state.report;
                  final sections = object(
                    report?.json[widget.full
                        ? 'generation_progress'
                        : 'preview_generation_progress'],
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.t(
                          'generation',
                          widget.full ? 'title' : 'previewTitle',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (widget.input != null || report != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: _BirthSummary(
                            input: widget.input ?? report!.input,
                            c: c,
                          ),
                        ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/report-loading-poster.webp',
                                fit: BoxFit.cover,
                              ),
                              if (_video?.value.isInitialized ?? false)
                                FittedBox(
                                  fit: BoxFit.cover,
                                  clipBehavior: Clip.hardEdge,
                                  child: SizedBox(
                                    width: _video!.value.size.width,
                                    height: _video!.value.size.height,
                                    child: VideoPlayer(_video!),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${state.percent.round()}%',
                        style: const TextStyle(
                          fontSize: 36,
                          color: gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: state.percent / 100,
                        backgroundColor: line,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        c.t('generation', state.phase),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final section in objects(sections['sections']))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.t(
                                    'generation',
                                    'sections.${section['key']}',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                '${(section['percent'] as num).round()}%',
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      errorMessage(state.error),
                      if (state.error.isNotEmpty)
                        FilledButton(
                          onPressed: widget.onRetry,
                          child: Text(c.t('generation', 'retry')),
                        ),
                      TextButton(
                        onPressed: widget.onCancel,
                        child: Text(c.t('generation', 'cancel')),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BirthSummary extends StatelessWidget {
  const _BirthSummary({required this.input, required this.c});
  final Json input;
  final Copy c;
  @override
  Widget build(BuildContext context) {
    final p = object(input['profile']);
    final career = object(input['career_question']);
    final question = text(input['user_question']).isNotEmpty
        ? text(input['user_question'])
        : career.isEmpty
        ? ''
        : c.t('career', 'situations.${career['stage']}.question');
    return Panel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.t('experience', 'birthSummary'),
            style: const TextStyle(color: gold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '${text(p['birth_date'])} · ${text(p['birth_time']).isEmpty ? c.t('ui', 'unknown') : text(p['birth_time'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            text(p['birthplace']),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (question.isNotEmpty)
            Text(
              '${c.t('experience', 'question')}：$question',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
