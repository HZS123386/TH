import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../ui/jy_components.dart';
import '../ui/theme.dart';

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
  double _travel = 0;

  @override
  void initState() {
    super.initState();
    unawaited(widget.h5.recordVisit());
    _motion.addListener(() {
      if (_motion.value >= 650 / 820) widget.h5.revealLandingPortrait();
    });
  }

  Future<void> _enter() async {
    if (_leaving) return;
    widget.h5.prepareLanding();
    setState(() => _leaving = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _motion.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }
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
          onVerticalDragStart: (_) => _travel = 0,
          onVerticalDragUpdate: (event) => _travel -= event.delta.dy,
          onVerticalDragEnd: (_) {
            if (_travel > 48) unawaited(_enter());
          },
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final portraitWidth = (h * .64).clamp(w * 1.18, w * 1.44);
              final from = Rect.fromLTWH(
                (w - portraitWidth) / 2,
                0,
                portraitWidth,
                portraitWidth * 1312 / 1199,
              );
              final to = Rect.fromLTWH(
                0,
                47 + MediaQuery.paddingOf(context).top,
                w,
                w * 1312 / 1199,
              );
              final heroHeight = w <= 360
                  ? 276.0
                  : MediaQuery.sizeOf(context).width >= 700
                  ? 326.0
                  : 304.0;
              return AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final t = const Cubic(
                    .24,
                    .62,
                    .32,
                    1,
                  ).transform(_motion.value);
                  final image = Rect.lerp(from, to, t)!;
                  final fade = (1 - _motion.value * 820 / 460).clamp(0.0, 1.0);
                  final imageOpacity = _motion.value < 650 / 820
                      ? 1.0
                      : (1 - (_motion.value - 650 / 820) * 820 / 170).clamp(
                          0.0,
                          1.0,
                        );
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 1 - t,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, -.52),
                                radius: 1.1,
                                colors: [Color(0xFF271342), Color(0xFF0A0612)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: image,
                        child: Opacity(
                          opacity: imageOpacity,
                          child: ClipRect(
                            clipper: _PortraitCrop(
                              11 * t,
                              (to.height - heroHeight - 11).clamp(0.0, 1000.0) *
                                  t,
                            ),
                            child: const FateImage(
                              'assets/images/astrologer-900.webp',
                              fit: BoxFit.fill,
                            ),
                          ),
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
                                    Color(0x2211071D),
                                    Color(0xB5120820),
                                    Color(0xFF100717),
                                  ],
                                  stops: [.34, .49, .66, .83],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 23,
                        top: 25 + MediaQuery.paddingOf(context).top,
                        child: Opacity(
                          opacity: fade,
                          child: const Text(
                            '✦',
                            style: TextStyle(
                              color: Color(0xFFF8DA9D),
                              fontSize: 22,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFA3FB),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 22 + MediaQuery.paddingOf(context).bottom,
                        child: Transform.translate(
                          offset: Offset(0, -12 * (1 - fade)),
                          child: IgnorePointer(
                            ignoring: _leaving,
                            child: Opacity(
                              opacity: fade,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 62,
                                        height: 1,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Color(0xFFC36BFA),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '✦',
                                          style: TextStyle(
                                            color: Color(0xFFF3B5FF),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 62,
                                        height: 1,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFFC36BFA),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 10,
                                    ),
                                    child: ShaderMask(
                                      shaderCallback: (rect) =>
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFFFFD0F6),
                                              Color(0xFFF78DF8),
                                              Color(0xFFED23ED),
                                            ],
                                          ).createShader(rect),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        c.t(
                                          'jy',
                                          'welcome.${widget.h5.returningVisitor ? 'returning' : 'first'}',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: (w * .088).clamp(
                                            30.4,
                                            45.6,
                                          ),
                                          height: 1.23,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    c.t(
                                      'jy',
                                      'welcome.${widget.h5.returningVisitor ? 'returningNote' : 'firstNote'}',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFFE4CDEA),
                                      fontSize: (w * .036).clamp(14.08, 16.0),
                                    ),
                                  ),
                                  SizedBox(height: (h * .05).clamp(24.0, 44.0)),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 310,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0x6BFCA4FF),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF7B14E8),
                                            Color(0xFFCA0AF1),
                                            Color(0xFFE900CE),
                                          ],
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x4DB900F3),
                                            offset: Offset(0, 7),
                                            blurRadius: 30,
                                          ),
                                        ],
                                      ),
                                      child: FilledButton(
                                        key: const ValueKey('welcome-start'),
                                        onPressed: _leaving
                                            ? null
                                            : () => unawaited(_enter()),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          disabledBackgroundColor:
                                              Colors.transparent,
                                          foregroundColor: const Color(
                                            0xFFFFF8FF,
                                          ),
                                          minimumSize: const Size.fromHeight(
                                            55,
                                          ),
                                          shape: const StadiumBorder(),
                                          textStyle: const TextStyle(
                                            fontFamily: h5FontFamily,
                                            fontFamilyFallback: h5FontFallback,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              '✧',
                                              style: TextStyle(fontSize: 22),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(c.t('jy', 'welcome.start')),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '↑ ${c.t('jy', 'welcome.swipe')}',
                                    style: const TextStyle(
                                      color: Color(0xFFD5B7E0),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
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

class _PortraitCrop extends CustomClipper<Rect> {
  _PortraitCrop(this.top, this.bottom);
  final double top, bottom;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, top, size.width, size.height - bottom);
  @override
  bool shouldReclip(_PortraitCrop oldClipper) =>
      oldClipper.top != top || oldClipper.bottom != bottom;
}
