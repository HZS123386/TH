import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import 'action_ledger.dart';

class ActionOfferingCard extends StatefulWidget {
  const ActionOfferingCard({
    required this.energy,
    required this.onEnergyGained,
    super.key,
  });

  final int energy;
  final VoidCallback onEnergyGained;

  @override
  State<ActionOfferingCard> createState() => _ActionOfferingCardState();
}

class _ActionOfferingCardState extends State<ActionOfferingCard>
    with SingleTickerProviderStateMixin {
  static const _goal = ActionLedger.energyPerOffering;
  late int _from = widget.energy, _to = widget.energy;
  late final _motion = AnimationController(vsync: this, value: 1)
    ..addStatusListener(_advance);
  bool _reduced = false;

  bool get _completesOffering => _to > _from && _to % _goal == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = FateMotion.reduced(context);
    if (_reduced && _motion.isAnimating) _showSavedEnergy();
  }

  @override
  void didUpdateWidget(covariant ActionOfferingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.energy == oldWidget.energy) return;
    if (widget.energy > oldWidget.energy) widget.onEnergyGained();
    if (_reduced || widget.energy < _to) {
      _showSavedEnergy();
    } else if (!_motion.isAnimating) {
      _advance(AnimationStatus.completed);
    }
  }

  void _showSavedEnergy() {
    _motion.stop();
    _from = _to = widget.energy;
    _motion.value = 1;
  }

  void _advance(AnimationStatus status) {
    if (status != AnimationStatus.completed || _to >= widget.energy) return;
    _from = _to;
    _to = math.min(widget.energy, _from + ActionLedger.energyPerAction);
    _motion.duration = Duration(milliseconds: _completesOffering ? 4400 : 950);
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), theme = Theme.of(context);
    return FateCard(
      gold: true,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final index = _to == 0 ? 0 : (_to - 1) ~/ _goal;
          final (asset, name) = switch (index % 3) {
            0 => ('jasmine', s.offeringJasmine),
            1 => ('lotus', s.offeringLotus),
            _ => ('marigold', s.offeringMarigold),
          };
          final base = index * _goal;
          final motion = _motion.value;
          final fillTime = Curves.easeInOutCubic.transform(
            _completesOffering
                ? _phase(motion, .13, .28)
                : _phase(motion, .38, .94),
          );
          final amount = lerpDouble(
            (_from - base).clamp(0, _goal),
            _to - base,
            fillTime,
          )!;
          final full = amount >= _goal;
          final completion = _completesOffering
              ? motion
              : full
              ? 1.0
              : 0.0;
          final flight = Curves.easeInOutSine.transform(
            _phase(completion, .42, .75),
          );
          final arrival = _phase(completion, .75, 1);
          final blessing = Curves.easeOutCubic.transform(
            _phase(completion, .88, 1),
          );
          final score = amount.floor();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.myActions,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    s.offeringCollected(index + (full ? 1 : 0)),
                    style: const TextStyle(color: goldColor, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _OfferingScene(
                asset: asset,
                fraction: amount / _goal,
                gain: _completesOffering
                    ? _phase(motion, .035, .22)
                    : _phase(motion, .16, .55),
                flight: flight,
                arrival: arrival,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '$score / $_goal',
                      style: const TextStyle(
                        color: goldColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: amount / _goal,
                  minHeight: 6,
                  backgroundColor: lineColor,
                  color: goldColor,
                  semanticsLabel: s.offeringEnergy,
                ),
              ),
              const SizedBox(height: 8),
              if (blessing > 0)
                _OfferingBlessing(progress: blessing)
              else
                Text(
                  full
                      ? s.offeringPresenting
                      : s.offeringPerAction(ActionLedger.energyPerAction),
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
            ],
          );
        },
      ),
    );
  }
}

double _phase(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0);

class _OfferingScene extends StatelessWidget {
  const _OfferingScene({
    required this.asset,
    required this.fraction,
    required this.gain,
    required this.flight,
    required this.arrival,
  });

  final String asset;
  final double fraction, gain, flight, arrival;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: AspectRatio(
      aspectRatio: 3 / 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          // The tray and shrine remain aligned while the scene pushes in.
          final tray = Offset(size.width / 2, size.height * .817);
          final shrine = Offset(tray.dx, size.height * .545);
          final standingSize = math.min(114.0, size.height * .30);
          final origin = tray - Offset(0, standingSize * .48);
          final position =
              Offset.lerp(origin, shrine, flight)! -
              Offset(0, math.sin(flight * math.pi) * size.height * .035);
          final diameter = standingSize * lerpDouble(1, .24, flight)!;
          final light = Curves.easeInOutSine.transform(
            _phase(arrival, .08, .72),
          );
          return Transform.scale(
            scale: 1 + flight * .042,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const RepaintBoundary(
                  child: Image(
                    image: AssetImage(
                      'assets/images/action-offering-sanctuary.webp',
                    ),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                ColoredBox(
                  color: const Color(
                    0xFF12091D,
                  ).withValues(alpha: lerpDouble(.27, .06, light)!),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _OfferingAtmosphere(
                      gain: gain,
                      fraction: fraction,
                      flight: flight,
                      arrival: arrival,
                      light: light,
                      tray: tray,
                      shrine: shrine,
                    ),
                  ),
                ),
                if (flight < 1)
                  Positioned(
                    left: position.dx - diameter / 2,
                    top: position.dy - diameter / 2,
                    width: diameter,
                    height: diameter,
                    child: Opacity(
                      opacity: 1 - _phase(flight, .84, 1),
                      child: _OfferingImage(asset: asset, fraction: fraction),
                    ),
                  ),
                if (gain > 0 && gain < 1)
                  Positioned(
                    left: origin.dx + standingSize * .55,
                    top: origin.dy - gain * 22,
                    child: Opacity(
                      opacity: math.sin(gain * math.pi),
                      child: const Text(
                        '+${ActionLedger.energyPerAction}',
                        style: TextStyle(
                          color: goldColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _OfferingBlessing extends StatelessWidget {
  const _OfferingBlessing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), theme = Theme.of(context);
    return ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        heightFactor: progress,
        child: Opacity(
          opacity: progress,
          child: Semantics(
            liveRegion: progress == 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: goldColor.withValues(alpha: .34)),
                color: goldColor.withValues(alpha: .09),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: goldColor),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.offeringComplete,
                            style: const TextStyle(
                              color: goldColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.offeringBlessing,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: inkColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.offeringNext,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferingImage extends StatelessWidget {
  const _OfferingImage({required this.asset, required this.fraction});

  final String asset;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/action-offering-$asset.png',
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: .25,
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0xFFD4BADB),
              BlendMode.srcIn,
            ),
            child: image,
          ),
        ),
        ClipRect(clipper: _OfferingFill(fraction), child: image),
      ],
    );
  }
}

class _OfferingFill extends CustomClipper<Rect> {
  const _OfferingFill(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    size.height * (1 - progress),
    size.width,
    size.height * progress,
  );

  @override
  bool shouldReclip(covariant _OfferingFill oldClipper) =>
      oldClipper.progress != progress;
}

class _OfferingAtmosphere extends CustomPainter {
  const _OfferingAtmosphere({
    required this.gain,
    required this.fraction,
    required this.flight,
    required this.arrival,
    required this.light,
    required this.tray,
    required this.shrine,
  });

  final double gain, fraction, flight, arrival, light;
  final Offset tray, shrine;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final offeringLight =
        (.08 + .13 * fraction + .24 * math.sin(gain * math.pi)) * (1 - flight);
    _glow(canvas, tray, h * .18, goldColor, offeringLight);

    if (arrival <= 0) return;
    final candlelight = Curves.easeOutSine.transform(_phase(arrival, 0, .48));
    for (final x in [.213, .788]) {
      _glow(
        canvas,
        Offset(size.width * x, h * .54),
        h * .16,
        const Color(0xFFFFBA6A),
        .36 * candlelight,
      );
    }
    _glow(
      canvas,
      shrine - Offset(0, h * .06),
      h * .36,
      const Color(0xFFFFD594),
      .66 * light,
    );
    _glow(
      canvas,
      shrine + Offset(0, h * .104),
      h * .25,
      goldColor,
      .25 * light,
    );

    if (arrival >= 1) return;
    final smoke = Offset(size.width * .788, h * (.505 - .09 * arrival));
    canvas.drawPath(
      Path()
        ..moveTo(smoke.dx, smoke.dy)
        ..relativeCubicTo(
          -h * .04,
          -h * .046,
          h * .056,
          -h * .078,
          h * .014,
          -h * .15,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .85)
        ..color = const Color(
          0xFFE8D4CD,
        ).withValues(alpha: .47 * math.sin(arrival * math.pi)),
    );
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color tint,
    double opacity,
  ) {
    if (opacity <= 0) return;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final gradient = RadialGradient(
      colors: [
        tint.withValues(alpha: opacity),
        tint.withValues(alpha: 0),
      ],
      radius: .5,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient.createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _OfferingAtmosphere oldDelegate) =>
      oldDelegate.gain != gain ||
      oldDelegate.fraction != fraction ||
      oldDelegate.flight != flight ||
      oldDelegate.arrival != arrival ||
      oldDelegate.light != light ||
      oldDelegate.tray != tray ||
      oldDelegate.shrine != shrine;
}
