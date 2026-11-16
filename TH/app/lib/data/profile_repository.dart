import '../core/models/birth_profile.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class BirthLocationPage {
  const BirthLocationPage(this.items, this.total);
  final List<Map<String, dynamic>> items;
  final int total;
}

class ProfileRepository {
  ProfileRepository(this.api, this.drafts);
  final ApiClient api;
  final LocalDraftStore drafts;
  Future<BirthProfile?> remote() async {
    final json = await api.get('/api/profile', allowEmpty: true);
    return json.isEmpty ? null : BirthProfile.fromJson(json);
  }

  BirthProfile? local(String owner) {
    final json = drafts.read(owner, 'birth');
    if (json == null) return null;
    try {
      return BirthProfile.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<BirthProfile> save(
    String owner,
    BirthProfile profile, {
    required bool serverContractReady,
  }) async {
    var saved = profile;
    if (serverContractReady && owner != 'guest') {
      saved = BirthProfile.fromJson(
        await api.request(
          'PUT',
          '/api/profile',
          body: {
            'system': 'western_natal',
            'birth_date': profile.date,
            'birth_time': profile.time,
            'location_id': profile.placeId,
            'timezone': profile.timezone,
            'birthplace': profile.place,
            'display_name': profile.name,
            'country_code': profile.countryCode,
            'latitude': profile.latitude,
            'longitude': profile.longitude,
            'language': api.locale,
            'expected_revision': profile.revision,
          },
        ),
      );
    }
    await drafts.write(owner, 'birth', saved.toJson());
    return saved;
  }

  Future<BirthLocationPage> locations(
    String query,
    String locale, {
    String country = 'TH',
    String? level,
    String province = '',
    int offset = 0,
  }) async {
    if (!['', 'TH', 'CN', 'VN', 'US'].contains(country)) {
      throw const ApiFailure('unsupported_country');
    }
    final params = Uri(
      queryParameters: {
        'country': country,
        'level': level ?? (['TH', 'CN'].contains(country) ? 'auto' : 'city'),
        'query': query,
        'province': province,
        'offset': '$offset',
      },
    ).query;
    final response = await api.get(
      '/api/thai-locations?$params',
      authenticated: false,
    );
    final rows = response['items'] ?? response['results'] ?? [];
    if (rows is! List) throw const ApiFailure('invalid_locations');
    final items = rows
        .whereType<Map>()
        .map((row) {
          final name = locale == 'th'
              ? row['nameThai']
              : locale == 'zh'
              ? row['nameChinese']
              : row['nameEnglish'];
          return {
            ...Map<String, dynamic>.from(row),
            'label': name ?? row['nameEnglish'] ?? row['name'] ?? '',
            'timezone': row['timeZone'] ?? row['tzid'] ?? row['timezone'],
          };
        })
        .toList(growable: false);
    return BirthLocationPage(
      items,
      (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<void> clearLocal(String owner) => drafts.remove(owner, 'birth');
}
