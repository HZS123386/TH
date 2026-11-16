import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

class LuckyNumbersPage extends StatefulWidget {
  const LuckyNumbersPage({super.key});

  @override
  State<LuckyNumbersPage> createState() => _LuckyNumbersPageState();
}

class _LuckyNumbersPageState extends State<LuckyNumbersPage>
    with WidgetsBindingObserver {
  late DateTime _today;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _refreshDate();
  }

  void _refreshDate() {
    final now = DateTime.now();
    if (!DateUtils.isSameDay(_today, now)) {
      setState(() => _today = now);
    }
    _midnightTimer?.cancel();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextDay.difference(now), _refreshDate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDate();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final formats = MaterialLocalizations.of(context);
    // Reduce the sum of the Gregorian date's digits to a number from 1 to 9.
    final number = (_today.year + _today.month + _today.day - 1) % 9 + 1;
    final meaning = [
      s.luckyNumberOne,
      s.luckyNumberTwo,
      s.luckyNumberThree,
      s.luckyNumberFour,
      s.luckyNumberFive,
      s.luckyNumberSix,
      s.luckyNumberSeven,
      s.luckyNumberEight,
      s.luckyNumberNine,
    ][number - 1];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        PageHeading(s.todayLuckyNumber, formats.formatFullDate(_today)),
        FateCard(
          gold: true,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 276,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  radius: .88,
                  colors: [Color(0xFF552C6B), Color(0xFF251531), panelColor],
                  stops: [0, .67, 1],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox.square(
                      dimension: 228,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final ring in const [
                            (228.0, Color(0x45E4BC78)),
                            (192.0, Color(0x75E4BC78)),
                          ])
                            SizedBox.square(
                              dimension: ring.$1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ring.$2),
                                ),
                              ),
                            ),
                          const Align(
                            alignment: Alignment(.66, -.60),
                            child: Icon(Icons.auto_awesome, color: goldColor),
                          ),
                          const Align(
                            alignment: Alignment(-.68, .48),
                            child: Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: goldColor,
                            ),
                          ),
                          Semantics(
                            liveRegion: true,
                            child: SizedBox.square(
                              dimension: 156,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formats.formatDecimal(number),
                                  style: const TextStyle(
                                    color: Color(0xFFFFDFA4),
                                    fontSize: 126,
                                    height: 1.12,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xA9E8A55E),
                                        blurRadius: 22,
                                      ),
                                    ],
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
          ),
        ),
        const SizedBox(height: 16),
        FateCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.luckyNumberHint,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: goldColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(meaning),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          s.luckyNumberUpdates,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
