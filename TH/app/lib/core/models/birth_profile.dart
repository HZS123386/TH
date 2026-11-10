class BirthProfile {
  const BirthProfile({
    required this.date,
    required this.timezone,
    required this.place,
    this.name = '',
    this.time,
    this.placeId,
    this.id,
    this.revision,
  });
  final String date, timezone, place, name;
  final String? time, placeId, id;
  final int? revision;
  bool get exactTime => time != null;
  bool get isServerRevision => id != null && revision != null;
  Map<String, dynamic> toJson() => {
    'birth_date': date,
    'birth_time': time,
    'tzid': timezone,
    'birthplace': place,
    'display_name': name,
    'place_id': placeId,
    'profile_id': id,
    'revision': revision,
  };
  factory BirthProfile.fromJson(Map<String, dynamic> json) {
    final source = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : json;
    final date = source['birth_date'];
    if (date is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null ||
        DateTime.parse(date).toIso8601String().substring(0, 10) != date) {
      throw const FormatException('invalid_birth_date');
    }
    final time = source['birth_time'];
    if (time != null &&
        (time is! String ||
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time))) {
      throw const FormatException('invalid_birth_time');
    }
    return BirthProfile(
      date: date,
      time: time as String?,
      timezone:
          (source['tzid'] ?? source['timezone'] ?? 'Asia/Bangkok') as String,
      place: (source['birthplace'] ?? '') as String,
      name: (source['display_name'] ?? '') as String,
      placeId: (source['place_id'] ?? source['location_id']) as String?,
      id: json['profile_id'] as String?,
      revision: json['revision'] as int?,
    );
  }
}
