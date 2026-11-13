import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

part 'tarot_deck.dart';
part 'tarot_motion.dart';

// The 1909 Rider–Waite–Smith artwork is numbered in this order.
enum _Arcana implements _TarotCard {
  fool,
  magician,
  highPriestess,
  empress,
  emperor,
  hierophant,
  lovers,
  chariot,
  strength,
  hermit,
  wheelOfFortune,
  justice,
  hangedMan,
  death,
  temperance,
  devil,
  tower,
  star,
  moon,
  sun,
  judgement,
  world;

  @override
  String get artwork =>
      'assets/images/tarot/${index.toString().padLeft(2, '0')}.jpg';

  @override
  ({String name, String meaning}) reading(AppLocalizations s) => switch (this) {
    _Arcana.fool => (name: s.tarotFool, meaning: s.tarotFoolMeaning),
    _Arcana.magician => (
      name: s.tarotMagician,
      meaning: s.tarotMagicianMeaning,
    ),
    _Arcana.highPriestess => (
      name: s.tarotHighPriestess,
      meaning: s.tarotHighPriestessMeaning,
    ),
    _Arcana.empress => (name: s.tarotEmpress, meaning: s.tarotEmpressMeaning),
    _Arcana.emperor => (name: s.tarotEmperor, meaning: s.tarotEmperorMeaning),
    _Arcana.hierophant => (
      name: s.tarotHierophant,
      meaning: s.tarotHierophantMeaning,
    ),
    _Arcana.lovers => (name: s.tarotLovers, meaning: s.tarotLoversMeaning),
    _Arcana.chariot => (name: s.tarotChariot, meaning: s.tarotChariotMeaning),
    _Arcana.strength => (
      name: s.tarotStrength,
      meaning: s.tarotStrengthMeaning,
    ),
    _Arcana.hermit => (name: s.tarotHermit, meaning: s.tarotHermitMeaning),
    _Arcana.wheelOfFortune => (
      name: s.tarotWheelOfFortune,
      meaning: s.tarotWheelOfFortuneMeaning,
    ),
    _Arcana.justice => (name: s.tarotJustice, meaning: s.tarotJusticeMeaning),
    _Arcana.hangedMan => (
      name: s.tarotHangedMan,
      meaning: s.tarotHangedManMeaning,
    ),
    _Arcana.death => (name: s.tarotDeath, meaning: s.tarotDeathMeaning),
    _Arcana.temperance => (
      name: s.tarotTemperance,
      meaning: s.tarotTemperanceMeaning,
    ),
    _Arcana.devil => (name: s.tarotDevil, meaning: s.tarotDevilMeaning),
    _Arcana.tower => (name: s.tarotTower, meaning: s.tarotTowerMeaning),
    _Arcana.star => (name: s.tarotStar, meaning: s.tarotStarMeaning),
    _Arcana.moon => (name: s.tarotMoon, meaning: s.tarotMoonMeaning),
    _Arcana.sun => (name: s.tarotSun, meaning: s.tarotSunMeaning),
    _Arcana.judgement => (
      name: s.tarotJudgement,
      meaning: s.tarotJudgementMeaning,
    ),
    _Arcana.world => (name: s.tarotWorld, meaning: s.tarotWorldMeaning),
  };
}

const _drawCount = 3;
const _readingDuration = Duration(milliseconds: 3500);

enum _TarotPhase { selecting, reading, result }

class TarotPage extends StatefulWidget {
  const TarotPage({super.key});

  @override
  State<TarotPage> createState() => _TarotPageState();
}

class _TarotPageState extends State<TarotPage> with TickerProviderStateMixin {
  final _stageKey = GlobalKey();
  final _slotKeys = List.generate(_drawCount, (_) => GlobalKey());
  final _scroll = ScrollController();
  final _drawn = <_TarotCard>[];
  late final AnimationController _flightMotion;
  late final AnimationController _readingMotion;

  late List<_DeckEntry> _spread = _deal();
  _TarotPhase _phase = _TarotPhase.selecting;
  _CardFlight? _flight;
  VideoPlayerController? _seer;
  bool _seerReady = false;

  @override
  void initState() {
    super.initState();
    _flightMotion = AnimationController(vsync: this, duration: _flightDuration)
      ..addStatusListener(_finishFlight);
    _readingMotion = AnimationController(
      vsync: this,
      duration: _readingDuration,
    )..addStatusListener(_finishReading);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seer == null && !MediaQuery.disableAnimationsOf(context)) {
      final player = VideoPlayerController.asset('assets/tarot/seer.mp4');
      _seer = player;
      unawaited(_prepareSeer(player));
    }
  }

  Future<void> _prepareSeer(VideoPlayerController player) async {
    try {
      await player.initialize();
      if (!mounted) return;
      await player.setVolume(0);
      if (!mounted) return;
      _seerReady = true;
      if (_phase == _TarotPhase.reading) await _playSeer();
    } catch (_) {
      // The portrait stays visible when video playback is unavailable.
    }
  }

  Future<void> _playSeer() async {
    final player = _seer;
    if (player == null || !_seerReady) return;
    try {
      await player.seekTo(Duration.zero);
      if (mounted && _phase == _TarotPhase.reading) await player.play();
    } catch (_) {
      // The reading animation can finish with the static portrait.
    }
  }

  Future<void> _pauseSeer() async {
    final player = _seer;
    if (player == null || !_seerReady) return;
    try {
      await player.pause();
    } catch (_) {
      // The player is removed from the scene when the reading ends.
    }
  }

  List<_DeckEntry> _deal() {
    final random = math.Random();
    final cards = _tarotDeck.toList()..shuffle(random);
    final cells = List.generate(_spreadCount, (index) => index)
      ..shuffle(random);
    return [
      for (var i = 0; i < _spreadCount; i++)
        _DeckEntry(
          cards[i],
          cells[i],
          Offset(
            (random.nextDouble() - .5) * .52,
            (random.nextDouble() - .5) * .48,
          ),
          (random.nextDouble() - .5) * math.pi * .34,
          .9 + random.nextDouble() * .19,
        ),
    ];
  }

  Rect? _rectInStage(BuildContext? child) {
    final stage = _stageKey.currentContext?.findRenderObject();
    final box = child?.findRenderObject();
    if (stage is! RenderBox || box is! RenderBox || !box.hasSize) return null;
    return Rect.fromCenter(
      center: box.localToGlobal(box.size.center(Offset.zero), ancestor: stage),
      width: box.size.width,
      height: box.size.height,
    );
  }

  void _draw(_DeckEntry entry, BuildContext face) {
    if (_phase != _TarotPhase.selecting ||
        _flight != null ||
        _drawn.contains(entry.card)) {
      return;
    }
    final start = _rectInStage(face);
    final slot = _rectInStage(_slotKeys[_drawn.length].currentContext);
    if (MediaQuery.disableAnimationsOf(context) ||
        start == null ||
        slot == null) {
      _collect(entry.card);
      return;
    }
    setState(() => _flight = _CardFlight(entry, start, slot));
    _flightMotion.forward(from: 0);
  }

  void _finishFlight(AnimationStatus status) {
    final flight = _flight;
    if (status == AnimationStatus.completed && flight != null) {
      _collect(flight.entry.card);
    }
  }

  void _collect(_TarotCard card) {
    final motionAllowed = !MediaQuery.disableAnimationsOf(context);
    setState(() {
      _flight = null;
      _drawn.add(card);
      if (_drawn.length == _drawCount) {
        _phase = motionAllowed ? _TarotPhase.reading : _TarotPhase.result;
      }
    });
    if (_drawn.length < _drawCount) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_phase == _TarotPhase.reading) {
      _readingMotion.forward(from: 0);
      unawaited(_playSeer());
    }
  }

  void _finishReading(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() => _phase = _TarotPhase.result);
    unawaited(_pauseSeer());
  }

  void _shuffle() {
    if (_flight != null || _phase == _TarotPhase.reading) return;
    setState(() {
      _drawn.clear();
      _spread = _deal();
      _phase = _TarotPhase.selecting;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _flightMotion.dispose();
    _readingMotion.dispose();
    final player = _seer;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final selecting = _phase == _TarotPhase.selecting;
    final reading = _phase == _TarotPhase.reading;
    final flight = _flight;
    final caption = switch (_phase) {
      _TarotPhase.reading => s.tarotSeerReading,
      _TarotPhase.result => s.tarotReadingComplete,
      _TarotPhase.selecting when flight != null => s.tarotRevealing,
      _TarotPhase.selecting when _drawn.isNotEmpty => s.tarotCardsRemaining(
        _drawCount - _drawn.length,
      ),
      _TarotPhase.selecting => s.tarotSeerWaiting,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final portraitHeight = math.min(
          constraints.maxWidth * .47,
          constraints.maxHeight * .27,
        );
        final spreadHeight = math.max(
          255.0,
          constraints.maxHeight - portraitHeight - 257,
        );
        return Stack(
          key: _stageKey,
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.9),
                  radius: 1.27,
                  colors: [Color(0xFF2E1C63), Color(0xFF1D1142), _night],
                  stops: [0, .48, 1],
                ),
              ),
              child: CustomPaint(painter: _TarotStars()),
            ),
            IgnorePointer(
              ignoring: flight != null,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                      children: [
                        _heading(s),
                        const SizedBox(height: 4),
                        _SeerStage(
                          height: portraitHeight,
                          motion: reading ? _readingMotion : null,
                          player: reading ? _seer : null,
                        ),
                        Text(
                          caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _tarotGold,
                          ),
                        ),
                        if (selecting)
                          _TarotSpread(
                            key: ObjectKey(_spread),
                            entries: _spread,
                            hidden: {
                              ..._drawn,
                              if (flight != null) flight.entry.card,
                            },
                            height: spreadHeight,
                            onDraw: _draw,
                          ),
                        if (reading) _readingProgress(s),
                        if (_phase == _TarotPhase.result) _result(s),
                      ],
                    ),
                  ),
                  if (selecting) _tray(s),
                ],
              ),
            ),
            if (flight != null)
              IgnorePointer(
                child: _FlyingCard(
                  flight: flight,
                  motion: _flightMotion,
                  name: flight.entry.card.reading(s).name,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _heading(AppLocalizations s) => Column(
    children: [
      Text(
        s.tarotDrawTitle,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: _tarotGold,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        s.tarotDrawHint,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.4, color: mutedColor),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _drawCount; i++)
            Container(
              width: 23,
              height: 4,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: i < _drawn.length ? goldColor : const Color(0xFF4B3A7A),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          const SizedBox(width: 5),
          Semantics(
            liveRegion: true,
            child: Text(
              s.tarotProgress(_drawn.length, _drawCount),
              style: const TextStyle(fontSize: 11, color: mutedColor),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _tray(AppLocalizations s) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFF1D1238),
      border: Border(top: BorderSide(color: Color(0x35E4BC78))),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(13, 2, 13, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.north_rounded, size: 15, color: goldColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  s.tarotGestureHint,
                  style: const TextStyle(fontSize: 11, color: mutedColor),
                ),
              ),
              TextButton.icon(
                onPressed: _flight == null ? _shuffle : null,
                icon: const Icon(Icons.shuffle_rounded, size: 15),
                label: Text(s.tarotShuffle),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 11),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _drawCount; i++)
                SizedBox(
                  width: 73,
                  child: Column(
                    children: [
                      SizedBox(
                        key: _slotKeys[i],
                        width: 36,
                        height: 36 / _cardAspectRatio,
                        child: i < _drawn.length
                            ? _TarotFace(_drawn[i])
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: const Color(0x55E4BC78),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 14,
                                  color: Color(0x69E4BC78),
                                ),
                              ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        i < _drawn.length
                            ? _drawn[i].reading(s).name
                            : s.tarotCardPosition(i + 1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: _tarotGold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _readingProgress(AppLocalizations s) {
    final words = [
      s.tarotReadingStepOne,
      s.tarotReadingStepTwo,
      s.tarotReadingStepThree,
      s.tarotReadingStepFour,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AnimatedBuilder(
        animation: _readingMotion,
        builder: (context, _) {
          final progress = _readingMotion.value;
          final word =
              words[math.min(
                (progress * words.length).floor(),
                words.length - 1,
              )];
          return Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 230),
                child: Text(
                  word,
                  key: ValueKey(word),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: _tarotGold),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  value: Curves.easeInOut.transform(progress),
                  color: goldColor,
                  backgroundColor: const Color(0xFF4B3A7A),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _result(AppLocalizations s) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - value)),
        child: child,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FateCard(
            gold: true,
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.tarotResult,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _shuffle,
                      icon: const Icon(Icons.shuffle_rounded, size: 16),
                      label: Text(s.tarotDrawAgain),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _drawn.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  _readingRow(s, i),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _readingRow(AppLocalizations s, int index) {
    final card = _drawn[index];
    final reading = card.reading(s);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 47,
          height: 47 / _cardAspectRatio,
          child: _TarotFace(card),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.tarotCardPosition(index + 1),
                style: const TextStyle(color: goldColor, fontSize: 10),
              ),
              Text(
                reading.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reading.meaning,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: mutedColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeerStage extends StatelessWidget {
  const _SeerStage({required this.height, this.motion, this.player});
  final double height;
  final Animation<double>? motion;
  final VideoPlayerController? player;

  @override
  Widget build(BuildContext context) {
    final video = player;
    final animation = motion;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: .66,
                colors: [Color(0x558B53D8), Color(0x008B53D8)],
              ),
            ),
          ),
          Center(
            child: AspectRatio(
              aspectRatio: .92,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => const RadialGradient(
                      radius: .82,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, .57, 1],
                    ).createShader(bounds),
                    child: Image.asset(
                      'assets/tarot/seer.webp',
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  if (video != null)
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: video,
                      child: VideoPlayer(video),
                      builder: (context, value, child) {
                        if (!value.isInitialized ||
                            !value.isPlaying ||
                            value.position == Duration.zero) {
                          return const SizedBox.shrink();
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: value.size.width,
                                height: value.size.height,
                                child: child,
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF221746),
                                    Color(0x00221746),
                                    Color(0x00221746),
                                    Color(0xFF221746),
                                  ],
                                  stops: [0, .13, .87, 1],
                                ),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF241949),
                                      Color(0x00241949),
                                      Color(0x00241949),
                                      Color(0xFF211542),
                                    ],
                                    stops: [0, .09, .84, 1],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (animation != null)
            LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: animation,
                builder: (context, _) => CustomPaint(
                  painter: _TarotSparks(
                    Offset(constraints.maxWidth * .48, height * .69),
                    (animation.value * 3) % 1,
                    12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
