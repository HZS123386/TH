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
  factory ReportReference.fromJson(Map<String, dynamic> json) {
    final id = json['report_id'];
    final resultId = json['calculation_result_id'] ?? json['result_id'];
    final locale = json['locale'];
    final revision = json['profile_revision'];
    if (id is! String ||
        id.isEmpty ||
        resultId is! String ||
        resultId.isEmpty ||
        locale is! String ||
        locale.isEmpty ||
        (revision != null && (revision is! int || revision < 1))) {
      throw const FormatException('invalid_report_reference');
    }
    return ReportReference(
      id,
      resultId,
      locale,
      profileRevision: revision as int?,
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
}

class H5ReportReference {
  const H5ReportReference(
    this.id,
    this.createdAt,
    this.birthDate,
    this.full,
    this.fullState,
  );

  final String id, birthDate;
  final DateTime? createdAt;
  final bool full;
  final String? fullState;

  factory H5ReportReference.fromJson(Map<String, dynamic> value) {
    final id = value['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('invalid_report_reference');
    }
    final input = value['input'];
    final profile = input is Map ? input['profile'] : null;
    final fullState = value['full_state'];
    return H5ReportReference(
      id,
      DateTime.tryParse('${value['created_at']}')?.toLocal(),
      profile is Map ? '${profile['birth_date'] ?? ''}' : '',
      value['access'] == 'full',
      fullState is String ? fullState : null,
    );
  }
}

class H5HistoryPage {
  const H5HistoryPage(this.items, this.nextCursor);

  final List<H5ReportReference> items;
  final Map<String, String>? nextCursor;
}

class ReportsRepository {
  ReportsRepository(this.api, this.drafts);
  final ApiClient api;
  final LocalDraftStore drafts;
  bool exampleSaved(String owner) =>
      drafts.read(owner, LocalDraftStore.exampleBookmark) != null ||
      drafts.read(owner, LocalDraftStore.legacyExampleBookmark) != null;
  Future<void> saveExample(String owner) => drafts.write(
    owner,
    LocalDraftStore.exampleBookmark,
    {'saved_at': DateTime.now().toUtc().toIso8601String()},
  );
  Future<void> removeExample(String owner) async {
    await drafts.remove(owner, LocalDraftStore.exampleBookmark);
    await drafts.remove(owner, LocalDraftStore.legacyExampleBookmark);
  }

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
    final reportId = response['report_id'];
    final returnedResultId =
        response['calculation_result_id'] ?? response['result_id'];
    if (reportId is! String ||
        reportId.isEmpty ||
        (returnedResultId != null && returnedResultId != resultId) ||
        (response['locale'] ?? locale) != locale ||
        (response['profile_revision'] ?? revision) != revision) {
      throw const ApiFailure('invalid_report_reference');
    }
    final ref = ReportReference(
      reportId,
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

  Future<ReportSnapshot> read(ReportReference ref) async {
    final value = await api.get(
      '/api/western/reports/${Uri.encodeComponent(ref.id)}',
    );
    if (value['report_id'] != ref.id) {
      throw const FormatException('invalid_report_reference');
    }
    return ReportSnapshot.fromJson(
      value,
      resultId: ref.resultId,
      locale: ref.locale,
    );
  }

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

  Future<H5HistoryPage> listH5([Map<String, String>? cursor]) async {
    final value = await api.get(
      Uri(path: '/api/app/h5-reports', queryParameters: cursor).toString(),
    );
    final items = value['items'], next = value['next_cursor'];
    if (items is! List) throw const FormatException('invalid_h5_history');
    return H5HistoryPage(
      [
        for (final item in items.whereType<Map<String, dynamic>>())
          H5ReportReference.fromJson(item),
      ],
      next is Map && next['created'] is num && next['id'] is String
          ? {'before_created': '${next['created']}', 'before_id': next['id']}
          : null,
    );
  }

  Future<Map<String, dynamic>> readH5(String id) async {
    final value = await api.get(
      '/api/app/h5-reports/${Uri.encodeComponent(id)}',
    );
    if (value['id'] != id) {
      throw const FormatException('invalid_report_reference');
    }
    return value;
  }
}
