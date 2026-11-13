import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependencies.dart';
import '../../data/daily_horoscope_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import 'daily_horoscope_view_model.dart';

const horoscopeTitleColor = Color(0xFFD8BFF1);
const _surface = Color(0xFF252031);
const _outline = Color(0xFF42394E);
const _bodyColor = Color(0xFFD0C6D8);
const _readingDuration = Duration(milliseconds: 140);

const _zodiacGlyphs = [
  '♈︎',
  '♉︎',
  '♊︎',
  '♋︎',
  '♌︎',
  '♍︎',
  '♎︎',
  '♏︎',
  '♐︎',
  '♑︎',
  '♒︎',
  '♓︎',
];

class DailyHoroscopeCard extends StatelessWidget {
  const DailyHoroscopeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final model = DependencyScope.of(context).dailyHoroscope;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) =>
          _ReadingCard(model: model, home: true, sign: model.homeSign),
    );
  }
}

class DailyHoroscopePage extends StatefulWidget {
  const DailyHoroscopePage({super.key});

  static const path = 'daily-horoscope';
  static const location = '/fortune/$path';

  @override
  State<DailyHoroscopePage> createState() => _DailyHoroscopePageState();
}

class _DailyHoroscopePageState extends State<DailyHoroscopePage> {
  int? _previewSign;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final model = DependencyScope.of(context).dailyHoroscope;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final hasBirthSign = model.birthSign != null;
        final sign = (hasBirthSign ? _previewSign : null) ?? model.homeSign;
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            Text(
              s.dailyHoroscopeChooseSign,
              style: const TextStyle(
                color: goldColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _ZodiacPicker(
              key: ValueKey(model.birthSign),
              selectedSign: sign,
              onSelected: (selected) {
                if (model.birthSign != null) {
                  setState(() => _previewSign = selected);
                } else {
                  model.selectManualSign(selected);
                }
              },
            ),
            if (sign != null) ...[
              const SizedBox(height: 20),
              _ReadingCard(model: model, home: false, sign: sign),
              const SizedBox(height: 12),
              Text(
                s.dailyHoroscopeBasis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ZodiacPicker extends StatefulWidget {
  const _ZodiacPicker({
    required this.selectedSign,
    required this.onSelected,
    super.key,
  });

  final int? selectedSign;
  final ValueChanged<int> onSelected;

  @override
  State<_ZodiacPicker> createState() => _ZodiacPickerState();
}

class _ZodiacPickerState extends State<_ZodiacPicker> {
  static const _spacing = 8.0;
  late final _scroll = ScrollController(
    initialScrollOffset: (widget.selectedSign ?? 0) * (_tileWidth + _spacing),
    keepScrollOffset: false,
  );

  double get _tileWidth => MediaQuery.textScalerOf(context).scale(80);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = AppLocalizations.of(context).zodiacNames;
    final scrollBehavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: scrollBehavior.copyWith(
        scrollbars: false,
        dragDevices: {...scrollBehavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: SizedBox(
        height: MediaQuery.textScalerOf(context).scale(91),
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: names.length,
          separatorBuilder: (_, _) => const SizedBox(width: _spacing),
          itemBuilder: (context, sign) {
            final selected = widget.selectedSign == sign;
            return Semantics(
              selected: selected,
              button: true,
              child: SizedBox(
                width: _tileWidth,
                child: Material(
                  color: selected ? const Color(0xFF382A48) : _surface,
                  animationDuration: Duration.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: selected
                          ? horoscopeTitleColor.withValues(alpha: .62)
                          : _outline,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('daily-zodiac-$sign'),
                    onTap: () => widget.onSelected(sign),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SignGlyph(sign: sign, size: 27),
                        const SizedBox(height: 7),
                        Text(
                          names[sign],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? horoscopeTitleColor : _bodyColor,
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.model,
    required this.home,
    required this.sign,
  });

  final DailyHoroscopeViewModel model;
  final bool home;
  final int? sign;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final sign = this.sign;
    final forecast = sign == null
        ? null
        : FutureBuilder<DailyHoroscopeDay>(
            future: model.today,
            builder: (context, snapshot) {
              final loaded = snapshot.connectionState == ConnectionState.done;
              final day = loaded ? snapshot.data : model.loadedDay;
              if (day == null) return _status(context, s, loaded);
              final duration = MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : _readingDuration;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!home) ...[
                    _ForecastHeading(sign: sign),
                    const SizedBox(height: 16),
                  ],
                  TweenAnimationBuilder<double>(
                    key: ValueKey((day.date, sign)),
                    tween: Tween(begin: 4, end: 0),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, offset, child) => Transform.translate(
                      offset: Offset(0, offset),
                      child: child,
                    ),
                    child: _ReadingBody(
                      reading: day.readings[sign],
                      home: home,
                    ),
                  ),
                ],
              );
            },
          );
    if (!home) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline),
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: forecast),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: _outline),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                sign == null
                    ? s.dailyHoroscopeTitle
                    : s.dailyHoroscopeToday(s.zodiacNames[sign]),
                style: const TextStyle(
                  color: horoscopeTitleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go(DailyHoroscopePage.location),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.only(left: 10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sign == null
                        ? s.dailyHoroscopeChooseSign
                        : s.dailyHoroscopeMore,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ],
        ),
        if (forecast != null) ...[
          const SizedBox(height: 4),
          forecast,
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _status(BuildContext context, AppLocalizations s, bool loaded) => Row(
    children: [
      if (!loaded) ...[
        const SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Text(
          loaded ? s.dailyHoroscopeUnavailable : s.dailyHoroscopeLoading,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (loaded)
        TextButton(onPressed: model.refresh, child: Text(s.thaiCalendarRetry)),
    ],
  );
}

class _ForecastHeading extends StatelessWidget {
  const _ForecastHeading({required this.sign});

  final int sign;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final name = s.zodiacNames[sign];
    final title = Localizations.localeOf(context).languageCode == 'th'
        ? '$name (${lookupAppLocalizations(const Locale('en')).zodiacNames[sign]})'
        : name;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF77618C), Color(0xFF3C2B56)],
            ),
          ),
          child: _SignGlyph(sign: sign, size: 25),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: horoscopeTitleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                s.dailyHoroscopeForecast,
                style: const TextStyle(fontSize: 12, color: _bodyColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignGlyph extends StatelessWidget {
  const _SignGlyph({required this.sign, required this.size});

  final int sign;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(
      _zodiacGlyphs[sign],
      style: TextStyle(color: goldColor, fontSize: size, height: 1.1),
    ),
  );
}

class _ReadingBody extends StatelessWidget {
  const _ReadingBody({required this.reading, required this.home});

  final DailyHoroscopeReading reading;
  final bool home;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tone = reading.tone.name;
    final advice = switch (reading.topic) {
      HoroscopeTopic.love => s.dailyHoroscopeLoveAdvice(tone),
      HoroscopeTopic.work => s.dailyHoroscopeWorkAdvice(tone),
      HoroscopeTopic.money => s.dailyHoroscopeMoneyAdvice(tone),
      HoroscopeTopic.health => s.dailyHoroscopeHealthAdvice(tone),
    };
    final domains = [
      (
        HoroscopeTopic.love,
        s.dailyHoroscopeLove,
        home ? s.dailyHoroscopeLoveShort : s.dailyHoroscopeLove,
        Icons.favorite_rounded,
        const Color(0xFFF0B7BB),
      ),
      (
        HoroscopeTopic.work,
        s.dailyHoroscopeWork,
        home ? s.dailyHoroscopeWorkShort : s.dailyHoroscopeWork,
        Icons.work_outline_rounded,
        const Color(0xFFF0C75B),
      ),
      (
        HoroscopeTopic.money,
        s.dailyHoroscopeMoney,
        home ? s.dailyHoroscopeMoneyShort : s.dailyHoroscopeMoney,
        Icons.attach_money_rounded,
        horoscopeTitleColor,
      ),
      (
        HoroscopeTopic.health,
        s.dailyHoroscopeHealth,
        s.dailyHoroscopeHealth,
        Icons.spa_rounded,
        const Color(0xFF74BF91),
      ),
    ];
    const summaryFontSize = 15.0;
    const summaryLineHeight = 1.65;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: home
                ? 0
                : 2 *
                      summaryLineHeight *
                      MediaQuery.textScalerOf(context).scale(summaryFontSize),
          ),
          child: Text(
            s.dailyHoroscopeReading(
              s.planetName(reading.planet),
              reading.house,
              advice,
            ),
            style: const TextStyle(
              fontSize: summaryFontSize,
              height: summaryLineHeight,
              color: _bodyColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!home) ...[
          const Divider(height: 1, color: _outline),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (topic, label, caption, icon, color) in domains)
              Expanded(
                child: Semantics(
                  label: '$label ${reading.scores[topic]}',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Icon(icon, size: 17, color: color),
                      Text(
                        '${reading.scores[topic]}',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.32,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: _bodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
