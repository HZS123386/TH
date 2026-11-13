import '../core/network/api_client.dart';

enum HoroscopeTopic { love, work, money, health }

enum HoroscopeTone { supportive, steady, reflective }

class DailyHoroscopeReading {
  const DailyHoroscopeReading._({
    required this.scores,
    required this.topic,
    required this.tone,
    required this.planet,
    required this.house,
  });

  final Map<HoroscopeTopic, int> scores;
  final HoroscopeTopic topic;
  final HoroscopeTone tone;
  final String planet;
  final int house;

  factory DailyHoroscopeReading.fromJson(Object? json, int expectedSign) {
    if (json
        case {
          'sign': final int sign,
          'scores': final Map<String, dynamic> scores,
          'highlight': {
            'topic': final String topic,
            'tone': final String tone,
            'planet': final String planet,
            'house': final int house,
          },
        }
        when sign == expectedSign &&
            house >= 1 &&
            house <= 12 &&
            const {'venus', 'mercury', 'jupiter', 'moon'}.contains(planet)) {
      final values = <HoroscopeTopic, int>{};
      for (final topic in HoroscopeTopic.values) {
        final score = scores[topic.name];
        if (score is! int || score < 0 || score > 100) {
          throw const ApiFailure('invalid_response');
        }
        values[topic] = score;
      }
      try {
        return DailyHoroscopeReading._(
          scores: Map.unmodifiable(values),
          topic: HoroscopeTopic.values.byName(topic),
          tone: HoroscopeTone.values.byName(tone),
          planet: planet,
          house: house,
        );
      } on ArgumentError {
        throw const ApiFailure('invalid_response');
      }
    }
    throw const ApiFailure('invalid_response');
  }
}

class DailyHoroscopeDay {
  const DailyHoroscopeDay._(this.date, this.readings, this.refreshAfter);

  final DateTime date;
  final List<DailyHoroscopeReading> readings;
  final Duration refreshAfter;

  factory DailyHoroscopeDay.fromJson(Map<String, dynamic> json) {
    if (json case {
      'date': final String date,
      'signs': final List<Object?> signs,
      'refresh_after_seconds': final int seconds,
    } when signs.length == 12 && seconds >= 1 && seconds <= 86400) {
      final parsed = DateTime.tryParse('${date}T00:00:00Z');
      if (parsed != null && parsed.toIso8601String().substring(0, 10) == date) {
        return DailyHoroscopeDay._(
          parsed,
          List.unmodifiable([
            for (var sign = 0; sign < signs.length; sign++)
              DailyHoroscopeReading.fromJson(signs[sign], sign),
          ]),
          Duration(seconds: seconds),
        );
      }
    }
    throw const ApiFailure('invalid_response');
  }
}

class DailyHoroscopeRepository {
  const DailyHoroscopeRepository(this.api);

  final ApiClient api;

  Future<DailyHoroscopeDay> loadToday() async => DailyHoroscopeDay.fromJson(
    await api.get('/api/daily-horoscope/today', authenticated: false),
  );
}
