class ChartPlanet {
  const ChartPlanet(
    this.key,
    this.longitude, {
    this.house,
    this.retrograde = false,
  });
  final String key;
  final double longitude;
  final int? house;
  final bool retrograde;
  static const keys = [
    'sun',
    'moon',
    'mercury',
    'venus',
    'mars',
    'jupiter',
    'saturn',
    'uranus',
    'neptune',
    'pluto',
  ];
  static const symbols = ['☉', '☽', '☿', '♀', '♂', '♃', '♄', '♅', '♆', '♇'];
  String get symbol => symbols[keys.indexOf(key)];
}

class ChartAspect {
  const ChartAspect(this.from, this.to, this.angle, {this.orb, this.type});
  final String from, to;
  final double angle;
  final double? orb;
  final String? type;
}

class CalculationSnapshot {
  const CalculationSnapshot({
    required this.id,
    required this.engineVersion,
    required this.rulesetVersion,
    required this.exactTime,
    required this.planets,
    this.ascendant,
    this.midheaven,
    this.houses = const {},
    this.aspects = const [],
    this.missingFields = const [],
    this.example = false,
  });
  final String id, engineVersion, rulesetVersion;
  final bool exactTime, example;
  final List<ChartPlanet> planets;
  final double? ascendant, midheaven;
  final Map<int, double> houses;
  final List<ChartAspect> aspects;
  final List<String> missingFields;
  factory CalculationSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['system'] != 'western_natal' ||
        json['result_id'] is! String ||
        !['complete', 'partial'].contains(json['status']) ||
        !['exact_time', 'date_only'].contains(json['input_precision']) ||
        json['engine_version'] is! String ||
        json['ruleset_version'] is! String ||
        json['facts'] is! List) {
      throw const FormatException('invalid_calculation');
    }
    final exact = json['input_precision'] == 'exact_time';
    final planets = <ChartPlanet>[], aspects = <ChartAspect>[];
    final houses = <int, double>{}, ids = <String>{};
    double? ascendant, midheaven;
    double longitude(dynamic value) {
      if (value is! num || !value.isFinite || value < 0 || value >= 360) {
        throw const FormatException('invalid_longitude');
      }
      return value.toDouble();
    }

    if ((json['facts'] as List).length > 200) {
      throw const FormatException('too_many_facts');
    }
    for (final raw in json['facts'] as List) {
      if (raw is! Map ||
          raw['fact_id'] is! String ||
          !ids.add(raw['fact_id'] as String) ||
          raw['value'] is! Map) {
        throw const FormatException('invalid_fact');
      }
      final value = raw['value'] as Map;
      if (!exact &&
          ([
                'ascendant',
                'midheaven',
                'house',
                'aspect',
              ].contains(raw['kind']) ||
              value['house'] != null)) {
        throw const FormatException('time_required');
      }
      switch (raw['kind']) {
        case 'planet':
          final key = value['key'];
          final house = value['house'];
          if (!ChartPlanet.keys.contains(key) ||
              planets.any((p) => p.key == key) ||
              (house != null && (house is! int || house < 1 || house > 12))) {
            throw const FormatException('invalid_planet');
          }
          planets.add(
            ChartPlanet(
              key as String,
              longitude(value['longitude']),
              house: house as int?,
              retrograde: value['retrograde'] == true,
            ),
          );
        case 'ascendant':
          if (ascendant != null) {
            throw const FormatException('duplicate_ascendant');
          }
          ascendant = longitude(value['longitude']);
        case 'midheaven':
          if (midheaven != null) {
            throw const FormatException('duplicate_midheaven');
          }
          midheaven = longitude(value['longitude']);
        case 'house':
          final number = value['number'];
          if (number is! int ||
              number < 1 ||
              number > 12 ||
              houses.containsKey(number)) {
            throw const FormatException('invalid_house');
          }
          houses[number] = longitude(value['longitude']);
        case 'aspect':
          final angle = value['angle'];
          final orb = value['orb'];
          if (!ChartPlanet.keys.contains(value['from']) ||
              !ChartPlanet.keys.contains(value['to']) ||
              value['from'] == value['to'] ||
              angle is! num ||
              !angle.isFinite ||
              ![0, 60, 90, 120, 180].contains(angle) ||
              (orb != null &&
                  (orb is! num || !orb.isFinite || orb < 0 || orb > 6))) {
            throw const FormatException('invalid_aspect');
          }
          aspects.add(
            ChartAspect(
              value['from'] as String,
              value['to'] as String,
              angle.toDouble(),
              orb: value['orb'] is num
                  ? (value['orb'] as num).toDouble()
                  : null,
              type: value['type'] as String?,
            ),
          );
        default:
          throw const FormatException('invalid_fact_kind');
      }
    }
    if (aspects.any(
      (a) =>
          !planets.any((p) => p.key == a.from) ||
          !planets.any((p) => p.key == a.to),
    )) {
      throw const FormatException('missing_aspect_planet');
    }
    return CalculationSnapshot(
      id: json['result_id'] as String,
      engineVersion: json['engine_version'] as String,
      rulesetVersion: json['ruleset_version'] as String,
      exactTime: exact,
      planets: List.unmodifiable(planets),
      ascendant: ascendant,
      midheaven: midheaven,
      houses: Map.unmodifiable(houses),
      aspects: List.unmodifiable(aspects),
      missingFields: List<String>.from(json['missing_fields'] as List? ?? []),
    );
  }
}

/// A labelled illustration, never a fallback for a failed personal calculation.
const teachingChart = CalculationSnapshot(
  id: 'teaching-example',
  engineVersion: 'illustration',
  rulesetVersion: 'illustration',
  exactTime: true,
  example: true,
  missingFields: ['ascendant', 'houses'],
  planets: [
    ChartPlanet('sun', 142),
    ChartPlanet('moon', 254),
    ChartPlanet('mercury', 158),
    ChartPlanet('venus', 116),
    ChartPlanet('mars', 71),
    ChartPlanet('jupiter', 8),
    ChartPlanet('saturn', 322),
    ChartPlanet('uranus', 48),
    ChartPlanet('neptune', 355),
    ChartPlanet('pluto', 297),
  ],
  aspects: [
    ChartAspect('sun', 'saturn', 180),
    ChartAspect('mercury', 'mars', 90),
    ChartAspect('venus', 'neptune', 120),
  ],
);
