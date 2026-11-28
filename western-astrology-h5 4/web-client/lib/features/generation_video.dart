import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ui/jy_components.dart';

/// Poster renderer for environments without an HTML video surface.
class GenerationVideo extends StatelessWidget {
  const GenerationVideo({
    required this.active,
    required this.reduced,
    super.key,
  });
  final bool active, reduced;

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: active ? 1 : 0, child: const GenerationPoster());
}

class GenerationPoster extends StatelessWidget {
  const GenerationPoster({
    this.lightweight = false,
    this.animate = true,
    super.key,
  });
  final bool lightweight, animate;
  @override
  Widget build(BuildContext context) {
    const image = FateImage(
      'assets/images/report-loading-poster.webp',
      fit: BoxFit.contain,
    );
    if (lightweight) {
      return animate ? const _LightweightGenerationPoster(child: image) : image;
    }
    return Transform.scale(
      scaleX: 1.06,
      scaleY: 1.06,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          // Stretch the radial mask to the poster's edges on both axes.
          final ellipse = Matrix4.diagonal3Values(
            rect.width / 2,
            rect.height / 2,
            1,
          )..setTranslationRaw(rect.center.dx, rect.center.dy, 0);
          return ui.Gradient.radial(
            Offset.zero,
            1,
            const [
              Colors.black,
              Color(0xEE000000),
              Color(0x88000000),
              Colors.transparent,
            ],
            const [.64, .77, .89, 1],
            TileMode.clamp,
            ellipse.storage,
          );
        },
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, .18, .82, 1],
          ).createShader(rect),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Color(0xBB000000), Colors.transparent],
              stops: [.76, .90, 1],
            ).createShader(rect),
            child: image,
          ),
        ),
      ),
    );
  }
}

class _LightweightGenerationPoster extends StatefulWidget {
  const _LightweightGenerationPoster({required this.child});
  final Widget child;

  @override
  State<_LightweightGenerationPoster> createState() =>
      _LightweightGenerationPosterState();
}

class _LightweightGenerationPosterState
    extends State<_LightweightGenerationPoster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(
    begin: .985,
    end: 1.015,
  ).animate(CurvedAnimation(parent: _motion, curve: Curves.easeInOut));

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}
