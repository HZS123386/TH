import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/thai_calendar_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

class ThaiCalendarCard extends StatefulWidget {
  const ThaiCalendarCard({required this.repository, super.key});

  final ThaiCalendarRepository repository;

  @override
  State<ThaiCalendarCard> createState() => _ThaiCalendarCardState();
}

class _ThaiCalendarCardState extends State<ThaiCalendarCard>
    with WidgetsBindingObserver {
  late Future<ThaiCalendarDay> _request;
  Timer? _midnight;
  DateTime? _expires;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(ThaiCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _load();
  }

  void _load() {
    _midnight?.cancel();
    _expires = null;
    _request = _loadDay(++_requestId);
  }

  Future<ThaiCalendarDay> _loadDay(int requestId) async {
    final day = await widget.repository.loadToday();
    if (mounted && requestId == _requestId) {
      // Use the server's Bangkok midnight interval even if the device is elsewhere.
      _expires = DateTime.now().toUtc().add(day.refreshAfter);
      _midnight = Timer(day.refreshAfter, _refresh);
    }
    return day;
  }

  void _refresh() => setState(_load);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final expires = _expires;
    if (state == AppLifecycleState.resumed &&
        expires != null &&
        !DateTime.now().toUtc().isBefore(expires)) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FateCard(
      gold: true,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: goldColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.thaiCalendarTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: goldColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                s.thaiCalendarTimezone,
                style: const TextStyle(fontSize: 10, color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<ThaiCalendarDay>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Row(
                  children: [
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.thaiCalendarLoading,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                );
              }
              final day = snapshot.data;
              if (day == null) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.thaiCalendarUnavailable,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: Text(s.thaiCalendarRetry),
                    ),
                  ],
                );
              }
              return _CalendarDetails(day: day);
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDetails extends StatelessWidget {
  const _CalendarDetails({required this.day});

  final ThaiCalendarDay day;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final civilDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(day.date);
    final lunar = day.lunar;
    final (label, color, icon) = switch (day.kind) {
      ThaiDayKind.auspicious => (
        s.thaiCalendarAuspicious,
        const Color(0xFFA5DBB6),
        Icons.auto_awesome_outlined,
      ),
      ThaiDayKind.caution => (
        s.thaiCalendarCaution,
        const Color(0xFFFFB8A9),
        Icons.info_outline,
      ),
      ThaiDayKind.mixed => (
        s.thaiCalendarMixed,
        const Color(0xFFF5C88D),
        Icons.balance_outlined,
      ),
      ThaiDayKind.ordinary => (
        s.thaiCalendarOrdinary,
        mutedColor,
        Icons.circle_outlined,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.thaiCalendarCivilDate(civilDate, day.buddhistYear),
          style: const TextStyle(fontSize: 12, color: mutedColor),
        ),
        const SizedBox(height: 4),
        if (lunar == null)
          Text(
            s.thaiCalendarLunarUnavailable,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 9,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                lunar.waxing
                    ? s.thaiCalendarWaxing(lunar.day)
                    : s.thaiCalendarWaning(lunar.day),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  color: inkColor,
                ),
              ),
              Text(
                lunar.secondEighthMonth
                    ? s.thaiCalendarSecondEighth
                    : s.thaiCalendarLunarMonth(lunar.month),
                style: const TextStyle(fontSize: 13, color: mutedColor),
              ),
            ],
          ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            Tooltip(
              message: s.thaiCalendarDayRule,
              child: _CalendarBadge(text: label, color: color, icon: icon),
            ),
            Tooltip(
              message: s.thaiCalendarHourRule,
              child: _CalendarBadge(
                text: s.thaiCalendarHours(day.hours.join(' / ')),
                color: goldColor,
                icon: Icons.schedule_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CalendarBadge extends StatelessWidget {
  const _CalendarBadge({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      border: Border.all(color: color.withValues(alpha: .30)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    ),
  );
}
