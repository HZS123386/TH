import '../core/network/api_client.dart';

enum ThaiDayKind { auspicious, caution, mixed, ordinary }

typedef ThaiLunarDay = ({
  bool waxing,
  int day,
  int month,
  bool secondEighthMonth,
});

class ThaiCalendarDay {
  const ThaiCalendarDay._({
    required this.date,
    required this.buddhistYear,
    required this.lunar,
    required this.kind,
    required this.hours,
    required this.refreshAfter,
  });

  final DateTime date;
  final int buddhistYear;
  final ThaiLunarDay? lunar;
  final ThaiDayKind kind;
  final List<String> hours;
  final Duration refreshAfter;

  static final _dateFormat = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _clockFormat = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  factory ThaiCalendarDay.fromJson(Map<String, dynamic> json) {
    if (json case {
      'date': final String day,
      'buddhist_year': final int year,
      'lunar': final Object? lunar,
      'day_kind': final String kind,
      'auspicious_hours': final List<Object?> hours,
      'refresh_after_seconds': final int seconds,
    }) {
      final date = _dateFormat.hasMatch(day)
          ? DateTime.tryParse('${day}T00:00:00Z')
          : null;
      if (date == null ||
          date.toIso8601String().substring(0, 10) != day ||
          year != date.year + 543 ||
          hours.isEmpty ||
          seconds < 1 ||
          seconds > 86400) {
        throw const ApiFailure('invalid_response');
      }
      final lunarDay = switch (lunar) {
        null => null,
        {
          'phase': final String phase,
          'day': final int day,
          'month': final int month,
          'second_eighth_month': final bool secondEighthMonth,
        }
            when (phase == 'waxing' || phase == 'waning') &&
                day >= 1 &&
                day <= 15 &&
                month >= 1 &&
                month <= 12 &&
                (!secondEighthMonth || month == 8) =>
          (
            waxing: phase == 'waxing',
            day: day,
            month: month,
            secondEighthMonth: secondEighthMonth,
          ),
        _ => throw const ApiFailure('invalid_response'),
      };
      return ThaiCalendarDay._(
        date: date,
        buddhistYear: year,
        lunar: lunarDay,
        kind: switch (kind) {
          'auspicious' => ThaiDayKind.auspicious,
          'caution' => ThaiDayKind.caution,
          'mixed' => ThaiDayKind.mixed,
          'ordinary' => ThaiDayKind.ordinary,
          _ => throw const ApiFailure('invalid_response'),
        },
        hours: List.unmodifiable(hours.map(_hourRange)),
        refreshAfter: Duration(seconds: seconds),
      );
    }
    throw const ApiFailure('invalid_response');
  }

  static String _hourRange(Object? value) {
    if (value case {'start': final String start, 'end': final String end}
        when _clockFormat.hasMatch(start) &&
            _clockFormat.hasMatch(end) &&
            start.compareTo(end) < 0) {
      return '$start–$end';
    }
    throw const ApiFailure('invalid_response');
  }
}

class ThaiCalendarRepository {
  const ThaiCalendarRepository(this.api);

  final ApiClient api;

  Future<ThaiCalendarDay> loadToday() async => ThaiCalendarDay.fromJson(
    await api.get('/api/thai-calendar/today', authenticated: false),
  );
}
