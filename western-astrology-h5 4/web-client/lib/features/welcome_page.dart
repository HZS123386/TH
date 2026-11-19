import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/browser_port.dart';
import '../core/models.dart' show Json, object;
import '../ui/jy_components.dart';
import '../ui/site_header.dart';
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
  static const _portraitHandoff = .79;
  static const _copyFadeThrough = .56;
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _leaving = false;
  double _travel = 0;

  @override
  void initState() {
    super.initState();
    unawaited(widget.h5.recordVisit());
    widget.h5.trackActivity('welcome');
    _motion.addListener(() {
      if (_motion.value >= _portraitHandoff) widget.h5.revealLandingPortrait();
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
    final signatureName = c.t('jy', 'welcome.name');
    final thaiSignature = c.language == 'th';
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
              final artworkWidth = w.clamp(0.0, h5PortraitMaxWidth);
              final portraitWidth = (h * .64).clamp(
                artworkWidth * 1.18,
                artworkWidth * 1.44,
              );
              final from = Rect.fromLTWH(
                (w - portraitWidth) / 2,
                0,
                portraitWidth,
                portraitWidth * 1312 / 1199,
              );
              final to = Rect.fromLTWH(
                (w - artworkWidth) / 2,
                47 + MediaQuery.paddingOf(context).top,
                artworkWidth,
                artworkWidth * 1312 / 1199,
              );
              final heroHeight = landingHeroHeight(w);
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
                  final fade = (1 - _motion.value / _copyFadeThrough).clamp(
                    0.0,
                    1.0,
                  );
                  final imageOpacity =
                      ((1 - _motion.value) / (1 - _portraitHandoff)).clamp(
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
                      if (!_leaving)
                        const Positioned(
                          top: 16,
                          right: 16,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: SiteLanguageMenu(),
                          ),
                        ),
                      if (signatureName.isEmpty &&
                          c.t('jy', 'welcome.guideName').isNotEmpty)
                        Positioned(
                          top: image.top + image.height * .265,
                          right: (w * .045).clamp(14.0, 20.0),
                          width: (w * .24).clamp(78.0, 108.0),
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: fade,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 1,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0xA8E4BC78),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      c.t('jy', 'welcome.guideName'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(0xFFF0DEBF),
                                        fontSize: (w * .035).clamp(13.0, 15.5),
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 2,
                                        height: 1.3,
                                        shadows: const [
                                          Shadow(
                                            color: Color(0xCC160B26),
                                            offset: Offset(0, 1),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      c.t('jy', 'welcome.guideTitle'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(0xFFD1BBD8),
                                        fontSize: (w * .0255).clamp(10.0, 11.5),
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 1.2,
                                        height: 1.4,
                                        shadows: const [
                                          Shadow(
                                            color: Color(0xCC160B26),
                                            offset: Offset(0, 1),
                                            blurRadius: 8,
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
                      Positioned(
                        right: math.max(
                          thaiSignature ? 10 : 13,
                          w -
                              image.right +
                              image.width * (thaiSignature ? .075 : .1),
                        ),
                        top: math.min(
                          image.top + image.width * (thaiSignature ? .3 : .33),
                          math.max(18, h - 245),
                        ),
                        width: thaiSignature
                            ? (w * .29).clamp(112, 144)
                            : (w * .32).clamp(124, 164),
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: fade,
                            child: _WelcomeSignature(
                              key: ValueKey(signatureName),
                              browser: widget.h5.browser,
                              name: signatureName,
                              role: c.t('jy', 'welcome.role'),
                              strokeData: object(
                                object(
                                  widget.h5.translations['welcomeStrokes'],
                                )[signatureName],
                              ),
                              nameSize: thaiSignature
                                  ? (w * .046).clamp(15, 23)
                                  : (w * .055).clamp(17, 27),
                              roleSize: thaiSignature
                                  ? (w * .0255).clamp(9, 11)
                                  : (w * .03).clamp(10, 13),
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
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      (h -
                                              44 -
                                              MediaQuery.paddingOf(
                                                context,
                                              ).bottom)
                                          .clamp(0.0, h),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                            c.t('jy', 'welcome.headline'),
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
                                        c.t('jy', 'welcome.note'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: const Color(0xFFE4CDEA),
                                          fontSize: (w * .036).clamp(
                                            14.08,
                                            16.0,
                                          ),
                                          height: 1.55,
                                        ),
                                      ),
                                      SizedBox(
                                        height: (h * .04).clamp(18.0, 32.0),
                                      ),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 410,
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
                                            key: const ValueKey(
                                              'welcome-start',
                                            ),
                                            onPressed: _leaving
                                                ? null
                                                : () => unawaited(_enter()),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              disabledBackgroundColor:
                                                  Colors.transparent,
                                              foregroundColor: const Color(
                                                0xFFFFF8FF,
                                              ),
                                              minimumSize:
                                                  const Size.fromHeight(55),
                                              shape: const StadiumBorder(),
                                              textStyle: const TextStyle(
                                                fontFamily: h5FontFamily,
                                                fontFamilyFallback:
                                                    h5FontFallback,
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
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Flexible(
                                                  child: Text(
                                                    c.t('jy', 'welcome.start'),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
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

class _WelcomeSignature extends StatefulWidget {
  const _WelcomeSignature({
    required this.browser,
    required this.name,
    required this.role,
    required this.strokeData,
    required this.nameSize,
    required this.roleSize,
    super.key,
  });

  final BrowserPort browser;
  final String name;
  final String role;
  final Json strokeData;
  final double nameSize;
  final double roleSize;

  @override
  State<_WelcomeSignature> createState() => _WelcomeSignatureState();
}

class _WelcomeSignatureState extends State<_WelcomeSignature>
    with SingleTickerProviderStateMixin {
  static const _shimmerPeriod = Duration(milliseconds: 1800);
  late final _clock = AnimationController(vsync: this);
  late final _drawingWidth =
      (widget.strokeData['width'] as num?)?.toDouble() ?? 0.0;
  late final _strokes = _loadStrokes();
  Duration _initialAge = Duration.zero;

  List<PathMetric> _loadStrokes() {
    final paths = widget.strokeData['strokes'];
    if (paths is! List || _drawingWidth <= 0) return const [];
    final strokes = <PathMetric>[];
    for (final points in paths.cast<List>()) {
      final path = Path()
        ..moveTo((points[0] as num).toDouble(), (points[1] as num).toDouble());
      for (var i = 2; i < points.length; i += 2) {
        path.lineTo(
          (points[i] as num).toDouble(),
          (points[i + 1] as num).toDouble(),
        );
      }
      strokes.add(path.computeMetrics().first);
    }
    return strokes;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      // Keep the phase of the signature already shown by the startup HTML.
      _initialAge = widget.browser.welcomeAge;
      _clock.repeat(period: _shimmerPeriod);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final handwriting = _strokes.isNotEmpty;
    final shimmerStart = handwriting ? 1110 : 720;
    return Transform.rotate(
      angle: -.035,
      alignment: Alignment.centerRight,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final clock =
              _initialAge + (_clock.lastElapsedDuration ?? Duration.zero);
          final ms = clock.inMilliseconds;
          double ink(int delay, int duration) => reducedMotion
              ? 1
              : Curves.easeOut.transform(
                  ((ms - delay) / duration).clamp(0.0, 1.0),
                );
          final phase =
              (ms - shimmerStart) %
              _shimmerPeriod.inMilliseconds /
              _shimmerPeriod.inMilliseconds;
          final nameOpacity = reducedMotion || ms < shimmerStart
              ? 1.0
              : 1 - .18 * Curves.easeInOut.transform(1 - (phase * 2 - 1).abs());
          final role = FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.role,
              style: TextStyle(
                color: const Color(0xFFF3CD91),
                fontSize: widget.roleSize,
                height: 1.4,
                shadows: const [
                  Shadow(color: Color(0xDD150A22), blurRadius: 6),
                ],
              ),
            ),
          );
          final name = handwriting
              ? Semantics(
                  label: widget.name,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: widget.nameSize * _drawingWidth / 1024,
                      height: widget.nameSize * 1.28,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey('welcome-name-strokes'),
                          painter: _SignatureHandwriting(
                            _strokes,
                            _drawingWidth,
                            reducedMotion
                                ? 1
                                : ((ms - 60) / 890).clamp(0.0, 1.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : ClipRect(
                  clipper: _SignatureInk(ink(60, 440)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.name,
                      style: TextStyle(
                        color: const Color(0xFFFFE5AA),
                        fontSize: widget.nameSize,
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                        shadows: const [
                          Shadow(color: Color(0xDD190D25), blurRadius: 7),
                          Shadow(color: Color(0x8FE0A54B), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  key: const ValueKey('welcome-name-shimmer'),
                  opacity: nameOpacity,
                  child: name,
                ),
                if (handwriting)
                  Opacity(opacity: ink(950, 150), child: role)
                else
                  ClipRect(clipper: _SignatureInk(ink(200, 450)), child: role),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SignatureHandwriting extends CustomPainter {
  const _SignatureHandwriting(this.strokes, this.drawingWidth, this.progress);

  final List<PathMetric> strokes;
  final double drawingWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / drawingWidth;
    final count = progress * strokes.length;
    final pen = Paint()
      ..color = const Color(0xFFFFE5AA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 68
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate(0, (size.height - 1024 * scale) / 2);
    canvas.scale(scale);
    for (var i = 0; i < count; i++) {
      final stroke = strokes[i];
      final part = math.min(1.0, count - i);
      final end = stroke.length * part;
      canvas.drawPath(stroke.extractPath(0, end), pen);
      if (part < 1) {
        final tip = stroke.getTangentForOffset(end);
        if (tip != null) {
          canvas.drawCircle(
            tip.position,
            46,
            Paint()..color = const Color(0xFFFFF3D4),
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SignatureHandwriting oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokes != strokes ||
      oldDelegate.drawingWidth != drawingWidth;
}

class _SignatureInk extends CustomClipper<Rect> {
  const _SignatureInk(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_SignatureInk oldClipper) =>
      oldClipper.progress != progress;
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
