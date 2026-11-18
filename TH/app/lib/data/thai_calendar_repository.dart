import 'dart:convert';

import 'package:flutter/services.dart';

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
    final seconds = json['refresh_after_seconds'];
    if (seconds is! int || seconds < 1 || seconds > 86400) {
      throw const ApiFailure('invalid_response');
    }
    return ThaiCalendarDay._parse(json, Duration(seconds: seconds));
  }

  static ThaiCalendarDay _parse(
    Map<String, dynamic> json,
    Duration refreshAfter,
  ) {
    if (json case {
      'date': final String day,
      'buddhist_year': final int year,
      'lunar': final Object? lunar,
      'day_kind': final String kind,
      'auspicious_hours': final List<Object?> hours,
    }) {
      final date = _dateFormat.hasMatch(day)
          ? DateTime.tryParse('${day}T00:00:00Z')
          : null;
      if (date == null ||
          date.toIso8601String().substring(0, 10) != day ||
          year != date.year + 543 ||
          hours.isEmpty) {
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
        refreshAfter: refreshAfter,
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

enum Kalayok { thongchai, athibodi, ubat, lokawinas }

class ThaiCalendarDetail {
  const ThaiCalendarDetail({
    required this.day,
    required this.smallEra,
    required this.kalayok,
    required this.wanPhra,
    required this.riangMon,
    required this.mansion,
  });

  final ThaiCalendarDay day;
  final int smallEra;
  final List<Kalayok> kalayok;
  final bool wanPhra, riangMon;
  final ({int index, int quarter, String name, String rerk}) mansion;

  factory ThaiCalendarDetail.fromJson(Map<String, dynamic> json) {
    if (json
        case {
          'small_era': final int era,
          'kalayok': final List<dynamic> flags,
          'wan_phra': final bool wanPhra,
          'riang_mon': final bool riangMon,
          'mansion': {
            'index': final int index,
            'quarter': final int quarter,
            'name': final String name,
            'rerk': final String rerk,
          },
        }
        when index >= 1 &&
            index <= 27 &&
            quarter >= 1 &&
            quarter <= 4 &&
            name.isNotEmpty &&
            rerk.isNotEmpty) {
      final day = ThaiCalendarDay._parse(json, Duration.zero);
      if (day.lunar == null ||
          era < day.date.year - 639 ||
          era > day.date.year - 638) {
        throw const ApiFailure('invalid_response');
      }
      return ThaiCalendarDetail(
        day: day,
        smallEra: era,
        kalayok: List.unmodifiable(
          flags.map(
            (flag) => switch (flag) {
              'thongchai' => Kalayok.thongchai,
              'athibodi' => Kalayok.athibodi,
              'ubat' => Kalayok.ubat,
              'lokawinas' => Kalayok.lokawinas,
              _ => throw const ApiFailure('invalid_response'),
            },
          ),
        ),
        wanPhra: wanPhra,
        riangMon: riangMon,
        mansion: (index: index, quarter: quarter, name: name, rerk: rerk),
      );
    }
    throw const ApiFailure('invalid_response');
  }
}

class ThaiCalendarRepository {
  ThaiCalendarRepository(this.api, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final ApiClient api;
  final AssetBundle _bundle;
  final _years = <int, Future<List<ThaiCalendarDetail>>>{};
  static final firstDate = DateTime.utc(2025);
  static final lastDate = DateTime.utc(2030, 12, 31);

  static DateTime bangkokToday([DateTime? now]) {
    final bangkok = (now ?? DateTime.now()).toUtc().add(
      const Duration(hours: 7),
    );
    return DateTime.utc(bangkok.year, bangkok.month, bangkok.day);
  }

  Future<List<ThaiCalendarDetail>> loadMonth(DateTime month) async {
    if (month.year < firstDate.year || month.year > lastDate.year) {
      throw const ApiFailure('calendar_out_of_range');
    }
    final year = _years.putIfAbsent(month.year, () => _loadYear(month.year));
    try {
      return (await year)
          .where((entry) => entry.day.date.month == month.month)
          .toList(growable: false);
    } catch (_) {
      if (identical(_years[month.year], year)) _years.remove(month.year);
      rethrow;
    }
  }

  Future<List<ThaiCalendarDetail>> _loadYear(int year) async {
    final json = jsonDecode(
      await _bundle.loadString('assets/calendar/$year.json'),
    );
    if (json case {
      'schema': 1,
      'year': final int assetYear,
      'days': final List<dynamic> days,
    } when assetYear == year) {
      final entries = days
          .map(
            (day) => ThaiCalendarDetail.fromJson(day as Map<String, dynamic>),
          )
          .toList(growable: false);
      if (entries.length !=
          DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays) {
        throw const ApiFailure('invalid_response');
      }
      for (var i = 0; i < entries.length; i++) {
        if (entries[i].day.date != DateTime.utc(year, 1, i + 1)) {
          throw const ApiFailure('invalid_response');
        }
      }
      return entries;
    }
    throw const ApiFailure('invalid_response');
  }

  Future<ThaiCalendarDay> loadToday() async => ThaiCalendarDay.fromJson(
    await api.get('/api/thai-calendar/today', authenticated: false),
  );
}
