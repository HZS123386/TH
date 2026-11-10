import 'dart:async';
import 'package:flutter/material.dart';

/// Poster renderer for environments without an HTML video surface.
class GenerationVideo extends StatefulWidget {
  const GenerationVideo({
    required this.active,
    required this.reduced,
    required this.onFinished,
    super.key,
  });
  final bool active, reduced;
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
    if (oldWidget.active != widget.active) _update();
  }

  void _update() {
    _timer?.cancel();
    if (widget.active) {
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
    scaleY: 1.52,
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [.03, .27, .8, .97],
      ).createShader(rect),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [.03, .18, .82, .97],
        ).createShader(rect),
        child: Image.asset(
          'assets/images/report-loading-poster.webp',
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}
