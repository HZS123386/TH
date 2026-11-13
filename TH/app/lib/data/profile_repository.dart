import '../core/models/birth_profile.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class ProfileRepository {
  ProfileRepository(this.api, this.drafts);

  final ApiClient api;
  final LocalDraftStore drafts;

  BirthProfile? local(String owner) {
    final value = drafts.read(owner, 'birth');
    if (value == null) return null;
    try {
      return BirthProfile.fromJson(value);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<BirthProfile?> remote() async {
    final value = await api.get('/api/profile', allowEmpty: true);
    return value.isEmpty ? null : BirthProfile.fromJson(value);
  }

  Future<BirthProfile> save(
    String owner,
    BirthProfile profile, {
    required bool serverContractReady,
  }) async {
    final saved = serverContractReady && owner != 'guest'
        ? BirthProfile.fromJson(
            await api.request(
              'PUT',
              '/api/profile',
              body: {
                'birth_date': profile.date,
                'birth_time': profile.time,
                'place_id': profile.placeId,
                'birthplace': profile.place,
                'tzid': profile.timezone,
                'display_name': profile.name,
                'expected_revision': profile.revision,
              },
            ),
          )
        : profile;
    await drafts.write(owner, 'birth', saved.toJson());
    return saved;
  }

  Future<void> clearLocal(String owner) => drafts.remove(owner, 'birth');

  Future<List<Map<String, dynamic>>> locations(
    String query,
    String language, {
    String country = 'TH',
  }) async {
    final path = Uri(
      path: '/api/thai-locations',
      queryParameters: {
        'query': query,
        'country': country,
        'level': const ['TH', 'CN'].contains(country) ? 'auto' : 'city',
      },
    );
    final response = await api.get(path.toString(), authenticated: false);
    final items = response['items'];
    if (items is! List) return const [];
    final localizedField = switch (language) {
      'zh' => 'nameChinese',
      'th' => 'nameThai',
      'vi' => 'nameVietnamese',
      _ => 'nameEnglish',
    };
    return [
      for (final item in items.whereType<Map>())
        if (item['id'] is String && item['timeZone'] is String)
          {
            'id': item['id'],
            'label':
                item[localizedField] ?? item['nameEnglish'] ?? item['nameThai'],
            'timezone': item['timeZone'],
          },
    ];
  }
}
