import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Poster renderer for environments without an HTML video surface.
class GenerationVideo extends StatefulWidget {
  const GenerationVideo({
    required this.active,
    required this.reduced,
    required this.onFinished,
    this.finishing = false,
    super.key,
  });
  final bool active, reduced, finishing;
  final VoidCallback onFinished;
  @override
  State<GenerationVideo> createState() => _GenerationVideoState();
}

class _GenerationVideoState extends State<GenerationVideo> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(covariant GenerationVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.finishing != widget.finishing) {
      _update();
    }
  }

  void _update() {
    _timer?.cancel();
    if (widget.active && widget.finishing) {
      _timer = Timer(const Duration(milliseconds: 550), () {
        if (mounted) widget.onFinished();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: widget.active ? 1 : 0, child: const GenerationPoster());
}

class GenerationPoster extends StatelessWidget {
  const GenerationPoster({super.key});
  @override
  Widget build(BuildContext context) => Transform.scale(
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
          child: Image.asset(
            'assets/images/report-loading-poster.webp',
            fit: BoxFit.fill,
          ),
        ),
      ),
    ),
  );
}
