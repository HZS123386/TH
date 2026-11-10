import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../ui/theme.dart';
import 'landing_page.dart';

/// JY's welcome interaction rendered by the existing Flutter application.
class WelcomePage extends StatefulWidget {
  const WelcomePage({required this.h5, super.key});
  final H5Controller h5;
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );
  bool _leaving = false;

  Future<void> _enter() async {
    if (_leaving) return;
    _leaving = true;
    if (!MediaQuery.disableAnimationsOf(context)) await _motion.forward();
    if (mounted) widget.h5.enterLanding();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    return Material(
      type: MaterialType.transparency,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && event.scrollDelta.dy > 12) {
            unawaited(_enter());
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -100) unawaited(_enter());
          },
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth, height = box.maxHeight;
              final from = Rect.fromLTWH(
                -width * .2,
                height * .04,
                width * 1.4,
                width * 1.4 * 1312 / 1199,
              );
              final to = Rect.fromLTWH(
                width - 330,
                kToolbarHeight + MediaQuery.paddingOf(context).top,
                330,
                365,
              );
              return AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final t = Curves.easeInOutCubic.transform(_motion.value);
                  final image = Rect.lerp(from, to, t)!;
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: night.withValues(alpha: 1 - t),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: image,
                        child: const Image(
                          image: heroImage,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1 - t,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x55130C24),
                                    night,
                                  ],
                                  stops: [.25, .58, .86],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 26,
                        top: 28 + MediaQuery.paddingOf(context).top,
                        child: Opacity(
                          opacity: 1 - t,
                          child: const Text(
                            '✧  FATE',
                            style: TextStyle(
                              color: gold,
                              fontSize: 21,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 28,
                        right: 28,
                        bottom: 28 + MediaQuery.paddingOf(context).bottom,
                        child: IgnorePointer(
                          ignoring: _leaving,
                          child: Opacity(
                            opacity: (1 - t * 3).clamp(0, 1),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '✦',
                                  style: TextStyle(color: gold, fontSize: 26),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  c.t(
                                    'experience',
                                    widget.h5.returningVisitor
                                        ? 'welcomeReturning'
                                        : 'welcomeFirst',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 30,
                                    height: 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  c.t(
                                    'experience',
                                    widget.h5.returningVisitor
                                        ? 'welcomeReturningNote'
                                        : 'welcomeFirstNote',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: lavender),
                                ),
                                const SizedBox(height: 26),
                                FilledButton.icon(
                                  key: const ValueKey('welcome-start'),
                                  onPressed: _leaving
                                      ? null
                                      : () => unawaited(_enter()),
                                  icon: const Icon(Icons.auto_awesome_outlined),
                                  label: Text(c.t('experience', 'start')),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '↑ ${c.t('experience', 'swipe')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
