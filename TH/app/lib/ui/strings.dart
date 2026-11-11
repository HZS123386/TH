import '../l10n/generated/app_localizations.dart';

extension ChartStrings on AppLocalizations {
  String aspectName(double angle) => switch (angle) {
    0 => aspectConjunction,
    60 => aspectSextile,
    90 => aspectSquare,
    120 => aspectTrine,
    180 => aspectOpposition,
    _ => '${angle.toInt()}°',
  };
  String chartError(String? code) => switch (code) {
    'roxy_local_limit' || 'roxy_quota' => roxyQuota,
    'profile_changed' => profileChanged,
    'roxy_input_rejected' => saveForChart,
    _ => roxyUnavailable,
  };
  List<String> get zodiacNames => [
    zAries,
    zTaurus,
    zGemini,
    zCancer,
    zLeo,
    zVirgo,
    zLibra,
    zScorpio,
    zSagittarius,
    zCapricorn,
    zAquarius,
    zPisces,
  ];
  String planetName(String key) => switch (key) {
    'sun' => pSun,
    'moon' => pMoon,
    'mercury' => pMercury,
    'venus' => pVenus,
    'mars' => pMars,
    'jupiter' => pJupiter,
    'saturn' => pSaturn,
    'uranus' => pUranus,
    'neptune' => pNeptune,
    'pluto' => pPluto,
    _ => '',
  };
  String planetMeaning(String key) => switch (key) {
    'sun' => sunMeaning,
    'moon' => moonMeaning,
    'mercury' => mercuryMeaning,
    'venus' => venusMeaning,
    'mars' => marsMeaning,
    'jupiter' => jupiterMeaning,
    'saturn' => saturnMeaning,
    'uranus' => uranusMeaning,
    'neptune' => neptuneMeaning,
    'pluto' => plutoMeaning,
    _ => '',
  };
  String position(double longitude) =>
      '${zodiacNames[(longitude / 30).floor()]} ${(longitude % 30).floor()}°${((longitude % 1) * 60).floor().toString().padLeft(2, '0')}′';
}
