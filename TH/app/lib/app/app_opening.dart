import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/theme.dart';

const _lastFrame = AssetImage('assets/opening/last-frame.webp');

class AppOpening extends StatefulWidget {
  const AppOpening({required this.child, super.key});

  final Widget child;

  @override
  State<AppOpening> createState() => _AppOpeningState();
}

class _AppOpeningState extends State<AppOpening>
    with SingleTickerProviderStateMixin {
  late final _handoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..addStatusListener(_onHandoffStatus);
  late final _opacity = _handoff
      .drive(
        CurveTween(curve: const Interval(.23, 1, curve: Curves.easeInOutCubic)),
      )
      .drive(Tween<double>(begin: 1, end: 0));

  VideoPlayerController? _player;
  Timer? _timeout;
  bool _started = false;
  bool _visible = true;
  bool _leaving = false;
  bool _lastFrameReady = false;
  bool _showLastFrame = false;
  bool _openingLaidOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _visible = false;
      return;
    }

    final player = VideoPlayerController.asset('assets/opening/opening.mp4');
    _player = player;
    player.addListener(_onProgress);
    _timeout = Timer(const Duration(seconds: 8), _showHome);
    var failed = false;
    unawaited(
      precacheImage(
        _lastFrame,
        context,
        onError: (_, _) {
          failed = true;
        },
      ).then((_) {
        _lastFrameReady = !failed;
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving) return;
      setState(() => _openingLaidOut = true);
      unawaited(_play(player));
    });
  }

  Future<void> _play(VideoPlayerController player) async {
    try {
      await player.initialize().timeout(const Duration(seconds: 3));
      if (!mounted || _leaving) return;
      await player.setVolume(0);
      if (mounted && !_leaving) await player.play();
    } catch (_) {
      if (mounted) _showHome();
    }
  }

  void _onProgress() {
    final value = _player?.value;
    if (value == null) return;
    final nearEnd =
        value.isInitialized &&
        value.position > Duration.zero &&
        value.duration - value.position <= const Duration(milliseconds: 180);
    if (value.hasError || value.isCompleted || nearEnd) {
      _showHome(useLastFrame: !value.hasError);
    }
  }

  void _showHome({bool useLastFrame = false}) {
    if (!mounted || _leaving) return;
    _leaving = true;
    _timeout?.cancel();
    if (useLastFrame && _lastFrameReady) {
      // Use the final frame for the move so the feathered edges also render on web.
      setState(() => _showLastFrame = true);
    }
    _handoff.forward();
  }

  void _onHandoffStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() => _visible = false);
    _releasePlayer();
  }

  void _releasePlayer() {
    final player = _player;
    _player = null;
    if (player == null) return;
    player.removeListener(_onProgress);
    unawaited(player.dispose());
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeFocus(
        excluding: _visible,
        child: ExcludeSemantics(
          excluding: _visible,
          child: IgnorePointer(ignoring: _visible, child: widget.child),
        ),
      ),
      if (_visible)
        FadeTransition(
          opacity: _opacity,
          child: ColoredBox(
            color: canvasColor,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) => AnimatedBuilder(
                          animation: _handoff,
                          child: _artwork(),
                          builder: (context, child) {
                            // Move the revealed portrait toward its place on the home card.
                            final progress = _showLastFrame
                                ? Curves.easeInOutCubic.transform(
                                    _handoff.value,
                                  )
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(
                                constraints.maxWidth * .17 * progress,
                                -constraints.maxHeight * .27 * progress,
                              ),
                              child: Transform.scale(
                                scale: lerpDouble(1, .58, progress)!,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    child!,
                                    if (progress > 0)
                                      Opacity(
                                        opacity: (progress * 5).clamp(0.0, 1.0),
                                        child: const DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                canvasColor,
                                                Color(0x00130C24),
                                                Color(0x00130C24),
                                                canvasColor,
                                              ],
                                              stops: [0, .14, .86, 1],
                                            ),
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  canvasColor,
                                                  Color(0x00130C24),
                                                  Color(0x00130C24),
                                                  canvasColor,
                                                ],
                                                stops: [0, .13, .81, 1],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        minimum: const EdgeInsets.all(18),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: ExcludeFocus(
                            // The browser can request keyboard focus before the first layout.
                            excluding: !_openingLaidOut,
                            child: TextButton(
                              onPressed: _showHome,
                              style: TextButton.styleFrom(
                                foregroundColor: inkColor,
                                backgroundColor: canvasColor.withValues(
                                  alpha: .75,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context).skipOpening,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _artwork() {
    if (_showLastFrame) {
      return const Image(
        image: _lastFrame,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      );
    }
    final player = _player;
    final poster = Image.asset(
      'assets/opening/poster.webp',
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    );
    if (player == null) return poster;
    return ValueListenableBuilder(
      valueListenable: player,
      child: VideoPlayer(player),
      builder: (context, value, child) {
        if (!value.isInitialized || value.position == Duration.zero) {
          return poster;
        }
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: value.size.width,
            height: value.size.height,
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _handoff.dispose();
    _releasePlayer();
    super.dispose();
  }
}
