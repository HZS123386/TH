import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/thai_calendar_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

const _lavender = Color(0xFFCCB5F2);

String _civilDate(BuildContext context, DateTime date) {
  final text = MaterialLocalizations.of(context).formatFullDate(date);
  // Keep the real weekday when displaying the Buddhist year in Thai.
  return AppLocalizations.of(context).localeName == 'th'
      ? text.replaceFirst('${date.year}', '${date.year + 543}')
      : text;
}

Color _flagColor(Kalayok flag) => switch (flag) {
  Kalayok.thongchai => const Color(0xFF8FD6A8),
  Kalayok.athibodi => const Color(0xFF74CFC8),
  Kalayok.ubat => const Color(0xFFF0AC76),
  Kalayok.lokawinas => const Color(0xFFF1A5BC),
};

String _lunarLabel(AppLocalizations s, ThaiLunarDay lunar) =>
    '${lunar.waxing ? s.thaiCalendarWaxing(lunar.day) : s.thaiCalendarWaning(lunar.day)} · '
    '${lunar.secondEighthMonth ? s.thaiCalendarSecondEighth : s.thaiCalendarLunarMonth(lunar.month)}';

class ThaiCalendarPage extends StatefulWidget {
  const ThaiCalendarPage({
    required this.repository,
    this.initialDate,
    super.key,
  });
  final ThaiCalendarRepository repository;
  final DateTime? initialDate;

  @override
  State<ThaiCalendarPage> createState() => _ThaiCalendarPageState();
}

class _ThaiCalendarPageState extends State<ThaiCalendarPage>
    with WidgetsBindingObserver {
  late DateTime _selected, _month, _today;
  late Future<List<ThaiCalendarDetail>> _request;
  Timer? _midnight;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = ThaiCalendarRepository.bangkokToday();
    final initial = widget.initialDate ?? _today;
    _selected = DateTime.utc(initial.year, initial.month, initial.day);
    if (_selected.isBefore(ThaiCalendarRepository.firstDate)) {
      _selected = ThaiCalendarRepository.firstDate;
    } else if (_selected.isAfter(ThaiCalendarRepository.lastDate)) {
      _selected = ThaiCalendarRepository.lastDate;
    }
    _loadMonth();
    _scheduleMidnight();
  }

  void _loadMonth() {
    _month = DateTime.utc(_selected.year, _selected.month);
    _request = widget.repository.loadMonth(_month);
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now().toUtc();
    final nextMidnight = _today.add(const Duration(days: 1, hours: -7));
    _midnight = Timer(nextMidnight.difference(now), _refreshToday);
  }

  void _refreshToday() {
    final today = ThaiCalendarRepository.bangkokToday();
    if (today != _today) {
      setState(() {
        if (_selected == _today && _inRange(today)) {
          _selected = today;
          _loadMonth();
        }
        _today = today;
      });
    }
    _scheduleMidnight();
  }

  bool _inRange(DateTime date) =>
      !date.isBefore(ThaiCalendarRepository.firstDate) &&
      !date.isAfter(ThaiCalendarRepository.lastDate);

  void _moveMonth(int offset) {
    final target = DateTime.utc(_month.year, _month.month + offset);
    if (!_inRange(target)) return;
    FateMotion.selectionFeedback();
    setState(() {
      _selected = DateTime.utc(
        target.year,
        target.month,
        math.min(
          _selected.day,
          DateTime.utc(target.year, target.month + 1, 0).day,
        ),
      );
      _loadMonth();
    });
  }

  void _goToday() {
    _refreshToday();
    if (!_inRange(_today)) return;
    setState(() {
      _selected = _today;
      _loadMonth();
    });
    if (_scroll.hasClients) {
      if (FateMotion.reduced(context)) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: FateMotion.page,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void didUpdateWidget(ThaiCalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository) _loadMonth();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final formats = MaterialLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: formats.backButtonTooltip,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/fortune'),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: goldColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    s.calendarTitle,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('calendar-today'),
                  onPressed: _inRange(_today) ? _goToday : null,
                  icon: const Icon(Icons.today_outlined, size: 17),
                  label: Text(s.calendarToday),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 18),
                    child: Text(
                      s.calendarSubtitle,
                      style: const TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ),
                  FateCard(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              key: const ValueKey('calendar-previous'),
                              tooltip: formats.previousMonthTooltip,
                              onPressed:
                                  _inRange(
                                    DateTime.utc(_month.year, _month.month - 1),
                                  )
                                  ? () => _moveMonth(-1)
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  AnimatedSwitcher(
                                    duration: FateMotion.duration(
                                      context,
                                      FateMotion.change,
                                    ),
                                    child: Text(
                                      s.calendarMonth('${_month.month}'),
                                      key: ValueKey(_month),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: _lavender,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    s.calendarYears(
                                      _month.year + 543,
                                      _month.year,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('calendar-next'),
                              tooltip: formats.nextMonthTooltip,
                              onPressed:
                                  _inRange(
                                    DateTime.utc(_month.year, _month.month + 1),
                                  )
                                  ? () => _moveMonth(1)
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var weekday = 0; weekday < 7; weekday++)
                              Expanded(
                                child: Text(
                                  formats.narrowWeekdays[weekday],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: weekday == 0
                                        ? const Color(0xFFF1A5BC)
                                        : goldColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<ThaiCalendarDetail>>(
                          future: _request,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return SizedBox(
                                height: 334,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(s.calendarLoading),
                                    ],
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError || snapshot.data == null) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                  horizontal: 12,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      s.calendarUnavailable,
                                      textAlign: TextAlign.center,
                                    ),
                                    TextButton(
                                      onPressed: () => setState(_loadMonth),
                                      child: Text(s.thaiCalendarRetry),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return GestureDetector(
                              onHorizontalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                if (velocity.abs() >= 180) {
                                  _moveMonth(velocity < 0 ? 1 : -1);
                                }
                              },
                              child: FateEntrance(
                                key: ValueKey(_month),
                                child: _MonthGrid(
                                  entries: snapshot.data!,
                                  selected: _selected,
                                  today: _today,
                                  onSelect: (date) {
                                    if (_selected == date) return;
                                    FateMotion.selectionFeedback();
                                    setState(() => _selected = date);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 7,
                          children: [
                            for (final flag in Kalayok.values)
                              _Legend(
                                label: s.calendarFlag(flag.name),
                                color: _flagColor(flag),
                              ),
                            _Legend(
                              label: s.calendarWanPhra,
                              color: goldColor,
                              moon: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 4,
                    ),
                    child: Text(
                      s.calendarSelectHint,
                      style: const TextStyle(fontSize: 11, color: mutedColor),
                    ),
                  ),
                  FutureBuilder<List<ThaiCalendarDetail>>(
                    future: _request,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done ||
                          snapshot.hasError ||
                          snapshot.data == null) {
                        return const SizedBox.shrink();
                      }
                      final entry = snapshot.data![_selected.day - 1];
                      return AnimatedSwitcher(
                        duration: FateMotion.duration(
                          context,
                          FateMotion.change,
                        ),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, .015),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _DayDetails(
                          key: ValueKey(_selected),
                          entry: entry,
                        ),
                      );
                    },
                  ),
                  if (!_inRange(_today))
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(s.calendarOutOfRange),
                    ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      s.calendarRange(
                        ThaiCalendarRepository.firstDate.year,
                        ThaiCalendarRepository.lastDate.year,
                      ),
                      style: const TextStyle(fontSize: 10, color: mutedColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      s.calendarReference,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: mutedColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.entries,
    required this.selected,
    required this.today,
    required this.onSelect,
  });
  final List<ThaiCalendarDetail> entries;
  final DateTime selected, today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final offset = entries.first.day.date.weekday % 7;
    final count = ((entries.length + offset) / 7).ceil() * 7;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 70 + math.max(0, scale - 1) * 45,
        mainAxisSpacing: 5,
        crossAxisSpacing: 4,
      ),
      itemCount: count,
      itemBuilder: (context, cell) {
        final i = cell - offset;
        if (i < 0 || i >= entries.length) return const SizedBox.shrink();
        final entry = entries[i], day = entry.day;
        final lunar = day.lunar!;
        final chosen = day.date == selected, isToday = day.date == today;
        final color = chosen
            ? _lavender
            : entry.kalayok.isNotEmpty
            ? _flagColor(entry.kalayok.first)
            : lineColor;
        final markers = [
          ...entry.kalayok.map((flag) => _flagColor(flag)),
          if (entry.wanPhra) goldColor,
        ];
        return Semantics(
          key: ValueKey(
            'calendar-day-${day.date.toIso8601String().substring(0, 10)}',
          ),
          button: true,
          selected: chosen,
          excludeSemantics: true,
          label: [
            _civilDate(context, day.date),
            _lunarLabel(s, lunar),
            ...entry.kalayok.map((flag) => s.calendarFlag(flag.name)),
            if (entry.wanPhra) s.calendarWanPhra,
            if (isToday) s.calendarToday,
          ].join(', '),
          onTap: () => onSelect(day.date),
          child: AnimatedContainer(
            duration: FateMotion.duration(context, FateMotion.settle),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: chosen ? const Color(0xFF513C6B) : const Color(0xFF271D35),
              border: Border.all(
                color: chosen ? color : color.withValues(alpha: .55),
                width: chosen ? 1.8 : .7,
              ),
              boxShadow: chosen
                  ? [
                      BoxShadow(
                        color: _lavender.withValues(alpha: .13),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => onSelect(day.date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 1,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.date.day}',
                          style: TextStyle(
                            fontSize: 17,
                            color: isToday && !chosen ? goldColor : inkColor,
                            fontWeight: chosen || isToday
                                ? FontWeight.w600
                                : FontWeight.w400,
                            decoration: isToday
                                ? TextDecoration.underline
                                : null,
                            decorationColor: goldColor,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.calendarLunarShort(
                            lunar.waxing ? 'waxing' : 'waning',
                            lunar.day,
                          ),
                          style: const TextStyle(
                            fontSize: 9,
                            color: mutedColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 9,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var j = 0; j < markers.length; j++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: entry.wanPhra && j == markers.length - 1
                                    ? Icon(
                                        Icons.nightlight_round,
                                        size: 8,
                                        color: markers[j],
                                      )
                                    : Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: markers[j],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
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
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color, this.moon = false});
  final String label;
  final Color color;
  final bool moon;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (moon)
        Icon(Icons.nightlight_round, size: 10, color: color)
      else
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(label, style: TextStyle(fontSize: 10, color: color)),
      ),
    ],
  );
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({required this.entry, super.key});
  final ThaiCalendarDetail entry;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final day = entry.day, lunar = entry.day.lunar!;
    final (kindLabel, accent) = switch (day.kind) {
      ThaiDayKind.auspicious => (
        s.thaiCalendarAuspicious,
        const Color(0xFF8FD6A8),
      ),
      ThaiDayKind.caution => (s.thaiCalendarCaution, const Color(0xFFF0AC76)),
      ThaiDayKind.mixed => (s.thaiCalendarMixed, goldColor),
      ThaiDayKind.ordinary => (s.thaiCalendarOrdinary, _lavender),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailCard(
          number: '01',
          title: _civilDate(context, day.date),
          icon: Icons.calendar_today_outlined,
          color: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(label: kindLabel, color: accent),
                  if (entry.wanPhra)
                    _Pill(
                      label: s.calendarWanPhra,
                      color: goldColor,
                      icon: Icons.nightlight_round,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _lunarLabel(s, lunar),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${s.calendarYears(day.buddhistYear, day.date.year)} · ${s.calendarSmallEra(entry.smallEra)}',
                style: const TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailCard(
          number: '02',
          title: s.calendarKalayokTitle,
          icon: Icons.flag_outlined,
          color: const Color(0xFF8FD6A8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.kalayok.isEmpty) Text(s.calendarNoKalayok),
              for (final flag in entry.kalayok)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: _flagColor(flag),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.calendarFlag(flag.name),
                              style: TextStyle(
                                color: _flagColor(flag),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              s.calendarFlagBody(flag.name),
                              style: const TextStyle(
                                fontSize: 12,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (entry.kalayok.length > 1)
                Text(
                  s.calendarMixedNote,
                  style: const TextStyle(fontSize: 11, color: mutedColor),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailCard(
          number: '03',
          title: s.calendarLunarTitle,
          icon: Icons.nightlight_outlined,
          color: _lavender,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: lunar.waxing
                        ? [const Color(0xFF493758), _lavender]
                        : [_lavender, const Color(0xFF493758)],
                  ),
                ),
                child: Icon(
                  lunar.waxing
                      ? Icons.brightness_5_outlined
                      : Icons.nights_stay_outlined,
                  color: inkColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lunar.waxing
                          ? s.thaiCalendarWaxing(lunar.day)
                          : s.thaiCalendarWaning(lunar.day),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (entry.riangMon) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.calendarRiangMon,
                        style: const TextStyle(color: _lavender),
                      ),
                      Text(
                        s.calendarRiangMonBody,
                        style: const TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ] else
                      Text(
                        s.calendarLunarOrdinary,
                        style: const TextStyle(fontSize: 12, color: mutedColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailCard(
          number: '04',
          title: s.calendarUbakong,
          icon: Icons.schedule_rounded,
          color: goldColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.calendarDaylight,
                style: const TextStyle(fontSize: 11, color: mutedColor),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hour in day.hours)
                    _Pill(
                      label: hour,
                      color: goldColor,
                      icon: Icons.access_time_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.thaiCalendarHourRule,
                style: const TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailCard(
          number: '05',
          title: s.calendarMansion,
          icon: Icons.auto_awesome_outlined,
          color: _lavender,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.localeName == 'th'
                    ? entry.mansion.name
                    : s.calendarMansionName('${entry.mansion.index}'),
                style: const TextStyle(
                  fontSize: 18,
                  color: inkColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                s.calendarMansionPosition(
                  entry.mansion.index,
                  entry.mansion.quarter,
                ),
                style: const TextStyle(fontSize: 12, color: _lavender),
              ),
              const SizedBox(height: 10),
              Text(
                s.localeName == 'th' ? entry.mansion.rerk : entry.mansion.name,
                style: const TextStyle(fontSize: 13, color: mutedColor),
              ),
              const SizedBox(height: 6),
              Text(
                s.calendarMansionReference,
                style: const TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });
  final String number, title;
  final IconData icon;
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) => FateCard(
    key: ValueKey('calendar-detail-$number'),
    accent: color,
    padding: const EdgeInsets.all(17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              number,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: .6),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
