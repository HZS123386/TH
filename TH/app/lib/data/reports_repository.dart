import '../core/models/report.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class ReportReference {
  const ReportReference(
    this.id,
    this.resultId,
    this.locale, {
    this.profileRevision,
    this.number,
    this.createdAt,
    this.state = 'ready',
  });
  final String id, resultId, locale;
  final int? profileRevision;
  final String? number;
  final DateTime? createdAt;
  final String state;
  Map<String, dynamic> toJson() => {
    'report_id': id,
    'result_id': resultId,
    'locale': locale,
    'profile_revision': profileRevision,
    'report_number': number,
    'created_at': createdAt == null
        ? null
        : createdAt!.millisecondsSinceEpoch / 1000,
    'state': state,
  };
  factory ReportReference.fromJson(Map<String, dynamic> json) =>
      ReportReference(
        json['report_id'] as String,
        json['result_id'] as String,
        json['locale'] as String,
        profileRevision: json['profile_revision'] as int?,
        number: json['report_number'] as String?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                ((json['created_at'] as num) * 1000).round(),
                isUtc: true,
              ),
        state: json['state'] as String? ?? 'ready',
      );
}

class ReportsRepository {
  ReportsRepository(this.api, this.drafts);
  final ApiClient api;
  final LocalDraftStore drafts;
  bool exampleSaved(String owner) =>
      drafts.read(owner, 'example-bookmark') != null;
  Future<void> saveExample(String owner) => drafts.write(
    owner,
    'example-bookmark',
    {'saved_at': DateTime.now().toUtc().toIso8601String()},
  );
  Future<void> removeExample(String owner) =>
      drafts.remove(owner, 'example-bookmark');
  Future<ReportReference> create(
    String owner,
    String resultId,
    int revision,
    String locale,
    String requestKey,
  ) async {
    final response = await api.request(
      'POST',
      '/api/western/reports',
      requestKey: requestKey,
      body: {
        'profile_revision': revision,
        'calculation_result_id': resultId,
        'topic': 'natal',
        'locale': locale,
      },
    );
    if (response['report_id'] is! String) {
      throw const ApiFailure('invalid_report_reference');
    }
    final ref = ReportReference(
      response['report_id'] as String,
      resultId,
      locale,
      profileRevision: revision,
      number: response['report_number'] as String?,
    );
    await remember(owner, ref);
    return ref;
  }

  Future<void> remember(String owner, ReportReference ref) =>
      drafts.write(owner, 'active-report', ref.toJson());

  Future<ReportSnapshot> read(ReportReference ref) async =>
      ReportSnapshot.fromJson(
        await api.get('/api/western/reports/${Uri.encodeComponent(ref.id)}'),
        resultId: ref.resultId,
        locale: ref.locale,
      );
  ReportReference? active(String owner) {
    final value = drafts.read(owner, 'active-report');
    try {
      return value == null ? null : ReportReference.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(ReportReference reference) async {
    await api.request(
      'DELETE',
      '/api/western/reports/${Uri.encodeComponent(reference.id)}',
    );
  }

  Future<void> forget(String owner, String id) async {
    if (active(owner)?.id == id) await drafts.remove(owner, 'active-report');
  }

  Future<List<ReportReference>> list({
    String query = '',
    String? locale,
  }) async {
    final uri = Uri(
      path: '/api/western/reports',
      queryParameters: {if (query.isNotEmpty) 'q': query, 'locale': ?locale},
    );
    final response = await api.get(uri.toString());
    final items = response['items'];
    if (items is! List) throw const ApiFailure('invalid_report_list');
    return items
        .map(
          (item) =>
              ReportReference.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }
}
