part of 'tarot_page.dart';

const _spreadCount = 30;
const _flightDuration = Duration(milliseconds: 2620);
const _cardAspectRatio = .58;
const _night = Color(0xFF120A2A);
const _tarotGold = Color(0xFFF6E2A8);

class _DeckEntry {
  const _DeckEntry(this.card, this.cell, this.jitter, this.angle, this.scale);

  final _TarotCard card;
  final int cell;
  final Offset jitter;
  final double angle, scale;
}

class _TarotSpread extends StatelessWidget {
  const _TarotSpread({
    super.key,
    required this.entries,
    required this.hidden,
    required this.height,
    required this.onDraw,
  });

  final List<_DeckEntry> entries;
  final Set<_TarotCard> hidden;
  final double height;
  final void Function(_DeckEntry, BuildContext) onDraw;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cellWidth = width / 5;
          final cellHeight = height / 6;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 1050),
            builder: (context, deal, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < entries.length; i++)
                  if (!hidden.contains(entries[i].card))
                    _positionCard(
                      entry: entries[i],
                      index: i,
                      s: s,
                      cell: Size(cellWidth, cellHeight),
                      stage: Size(width, height),
                      deal: deal,
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _positionCard({
    required _DeckEntry entry,
    required int index,
    required AppLocalizations s,
    required Size cell,
    required Size stage,
    required double deal,
  }) {
    final width = math.min(48.0, cell.width * .72) * entry.scale;
    final height = width * 1.54;
    final sin = math.sin(entry.angle).abs();
    final cos = math.cos(entry.angle).abs();
    final extentX = (width * cos + height * sin) / 2;
    final extentY = (height * cos + width * sin) / 2;
    final x = ((entry.cell % 5 + .5 + entry.jitter.dx) * cell.width).clamp(
      extentX,
      stage.width - extentX,
    );
    final y = ((entry.cell ~/ 5 + .5 + entry.jitter.dy) * cell.height).clamp(
      extentY,
      stage.height - extentY,
    );
    final bounce = math.sin(math.pi * _unit((deal - index * .018) / .4));

    return Positioned(
      key: ValueKey(entry.card),
      left: x - width / 2,
      top: y - height / 2,
      width: width,
      height: height,
      child: Transform.translate(
        offset: Offset(0, -8 * bounce),
        child: Transform.rotate(
          angle: entry.angle,
          child: _ScatteredCard(
            label: s.tarotChooseCard(index + 1),
            onDraw: (context) => onDraw(entry, context),
          ),
        ),
      ),
    );
  }
}

class _ScatteredCard extends StatefulWidget {
  const _ScatteredCard({required this.label, required this.onDraw});
  final String label;
  final ValueChanged<BuildContext> onDraw;

  @override
  State<_ScatteredCard> createState() => _ScatteredCardState();
}

class _ScatteredCardState extends State<_ScatteredCard> {
  double _drag = 0;
  bool _hover = false;

  void _release() => setState(() => _drag = 0);

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Transform.translate(
      offset: Offset(0, -math.max(_hover ? 6.0 : 0.0, _drag * .45)),
      child: Builder(
        builder: (faceContext) => Semantics(
          container: true,
          button: true,
          label: widget.label,
          child: GestureDetector(
            excludeFromSemantics: true,
            dragStartBehavior: DragStartBehavior.down,
            onVerticalDragStart: (_) => _release(),
            onVerticalDragUpdate: (details) {
              setState(() => _drag = math.max(0, _drag - details.delta.dy));
              if (_drag >= 30) widget.onDraw(faceContext);
            },
            onVerticalDragCancel: _release,
            onVerticalDragEnd: (_) => _release(),
            child: _TarotBack(onTap: () => widget.onDraw(faceContext)),
          ),
        ),
      ),
    ),
  );
}

class _TarotBack extends StatelessWidget {
  const _TarotBack({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF24164D),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
      side: const BorderSide(color: Color(0xFFB49559), width: 1.2),
    ),
    child: Ink(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.3),
          radius: .86,
          colors: [Color(0xFF544076), Color(0xFF2B1C61), Color(0xFF1A103F)],
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x75E4BC78)),
            ),
            child: const ExcludeSemantics(
              child: FittedBox(
                child: SizedBox(
                  width: 36,
                  height: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BackStars(),
                      Icon(
                        Icons.brightness_3_rounded,
                        size: 15,
                        color: _tarotGold,
                      ),
                      Text(
                        'TAROT',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 6.5,
                          letterSpacing: 1.2,
                          color: _tarotGold,
                        ),
                      ),
                      _BackStars(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BackStars extends StatelessWidget {
  const _BackStars();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      Icon(Icons.star_rounded, size: 5, color: goldColor),
      Icon(Icons.star_rounded, size: 5, color: goldColor),
      Icon(Icons.star_rounded, size: 5, color: goldColor),
    ],
  );
}

class _TarotFace extends StatelessWidget {
  const _TarotFace(this.card);

  final _TarotCard card;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      card.artwork,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

class _CardFlight {
  const _CardFlight(this.entry, this.start, this.slot);
  final _DeckEntry entry;
  final Rect start, slot;
}

class _FlyingCard extends StatelessWidget {
  const _FlyingCard({
    required this.flight,
    required this.motion,
    required this.name,
  });

  final _CardFlight flight;
  final Animation<double> motion;
  final String name;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stage = constraints.biggest;
      final center = stage.center(Offset.zero);
      final largeWidth = math.min(
        148.0,
        math.min(stage.width * .46, stage.height * .35),
      );
      final large = Size(largeWidth, largeWidth / _cardAspectRatio);
      return AnimatedBuilder(
        animation: motion,
        child: _TarotFace(flight.entry.card),
        builder: (context, face) {
          final ms = motion.value * _flightDuration.inMilliseconds;
          final intoCenter = Curves.easeOutCubic.transform(_unit(ms / 950));
          final intoSlot = Curves.easeOutCubic.transform(
            _unit((ms - 2000) / 620),
          );
          final movingToSlot = ms >= 2000;
          final start = flight.start.center;
          final slot = flight.slot.center;
          final position = movingToSlot
              ? _arc(center, slot, intoSlot, height: 56)
              : _arc(
                  start,
                  center,
                  intoCenter,
                  height: 40,
                  drift: start.dx < center.dx ? -65 : 65,
                );
          final size = movingToSlot
              ? Size.lerp(large, flight.slot.size, intoSlot)!
              : Size.lerp(flight.start.size, large, intoCenter)!;
          final turn = const Cubic(
            .3,
            .6,
            .3,
            1,
          ).transform(_unit((ms - 425) / 480));
          final front = turn >= .5;
          final glow = _unit((ms - 320) / 420) * (1 - .8 * intoSlot);
          final wordOpacity =
              _unit((ms - 880) / 220) * (1 - _unit((ms - 1880) / 220));
          return Stack(
            children: [
              if (glow > 0)
                Positioned.fromRect(
                  rect: Rect.fromCircle(center: position, radius: 164),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _tarotGold.withValues(alpha: .32 * glow),
                          const Color(0xFF966EFF).withValues(alpha: .21 * glow),
                          Colors.transparent,
                        ],
                        stops: const [0, .48, 1],
                      ),
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: position,
                  width: size.width,
                  height: size.height,
                ),
                child: Transform.rotate(
                  angle: flight.entry.angle * (1 - intoCenter),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .002)
                      ..rotateY(math.pi * (front ? turn - 1 : turn)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          if (glow > 0)
                            BoxShadow(
                              color: _tarotGold.withValues(alpha: .56 * glow),
                              blurRadius: 28,
                              spreadRadius: 2 * glow,
                            ),
                        ],
                      ),
                      child: IndexedStack(
                        index: front ? 1 : 0,
                        sizing: StackFit.expand,
                        children: [const _TarotBack(), face!],
                      ),
                    ),
                  ),
                ),
              ),
              if (ms >= 910 && ms < 1870)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TarotSparks(center, _unit((ms - 910) / 960), 16),
                  ),
                ),
              if (ms >= 2330)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TarotSparks(slot, _unit((ms - 2330) / 290), 7),
                  ),
                ),
              if (wordOpacity > 0)
                Positioned(
                  left: 18,
                  right: 18,
                  top: center.dy + large.height / 2 + 12,
                  child: Opacity(
                    opacity: wordOpacity,
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _tarotGold,
                        shadows: [Shadow(blurRadius: 12, color: _night)],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

double _unit(double value) => value.clamp(0.0, 1.0);

Offset _arc(
  Offset from,
  Offset to,
  double t, {
  required double height,
  double drift = 0,
}) {
  final guide = Offset(
    (from.dx + to.dx) / 2 + drift,
    math.min(from.dy, to.dy) - height,
  );
  final rest = 1 - t;
  return from * (rest * rest) + guide * (2 * rest * t) + to * (t * t);
}

class _TarotSparks extends CustomPainter {
  const _TarotSparks(this.origin, this.progress, this.count);
  final Offset origin;
  final double progress;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final motion = Curves.easeOutCubic.transform(progress);
    final paint = Paint()
      ..color = _tarotGold.withValues(alpha: (1 - progress) * .95);
    for (var i = 0; i < count; i++) {
      final angle = i * 2.39996;
      final distance = (35 + (i * 17) % 74) * motion;
      final point =
          origin +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance - motion * 18,
          );
      canvas.drawCircle(
        point,
        (1.1 + i % 3 * .55) * (1 - progress * .6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TarotSparks old) =>
      old.origin != origin || old.progress != progress || old.count != count;
}

class _TarotStars extends CustomPainter {
  const _TarotStars();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(613);
    final paint = Paint();
    for (var i = 0; i < 72; i++) {
      paint.color = inkColor.withValues(alpha: .22 + random.nextDouble() * .49);
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, i % 7 == 0 ? 1.05 : .56, paint);
    }
  }

  @override
  bool shouldRepaint(_TarotStars oldDelegate) => false;
}
