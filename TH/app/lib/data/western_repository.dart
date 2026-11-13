import '../core/models/birth_profile.dart';
import '../core/models/calculation.dart';
import '../core/network/api_client.dart';

class WesternRepository {
  WesternRepository(this.api);

  final ApiClient api;

  Future<CalculationSnapshot> calculate(
    BirthProfile profile,
    String key,
  ) async {
    if (!profile.isServerRevision) throw const ApiFailure('profile_required');
    return CalculationSnapshot.fromJson(
      await api.request(
        'POST',
        '/api/calculations',
        requestKey: key,
        body: {
          'system': 'western_natal',
          'profile_id': profile.id,
          'profile_revision': profile.revision,
        },
      ),
    );
  }
}
