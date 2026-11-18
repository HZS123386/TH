import '../core/models/report.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class ReportReference {
  const ReportReference(
    this.id,
    this.resultId,
    this.locale, {
    this.profileRevision,
  });

  final String id, resultId, locale;
  final int? profileRevision;

  factory ReportReference.fromJson(Map<String, dynamic> value) {
    final id = value['report_id'];
    final resultId = value['calculation_result_id'] ?? value['result_id'];
    final locale = value['locale'];
    final revision = value['profile_revision'];
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
    );
  }

  Map<String, dynamic> toJson() => {
    'report_id': id,
    'calculation_result_id': resultId,
    'locale': locale,
    'profile_revision': profileRevision,
  };
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
      drafts.read(owner, 'example-report') != null;

  Future<void> saveExample(String owner) =>
      drafts.write(owner, 'example-report', {'saved': true});

  Future<void> removeExample(String owner) =>
      drafts.remove(owner, 'example-report');

  ReportReference? active(String owner) {
    final value = drafts.read(owner, 'active-report');
    if (value == null) return null;
    try {
      return ReportReference.fromJson(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> remember(String owner, ReportReference ref) =>
      drafts.write(owner, 'active-report', ref.toJson());

  Future<ReportReference> create(
    String owner,
    String resultId,
    int revision,
    String locale,
    String key,
  ) async {
    final value = await api.request(
      'POST',
      '/api/western/reports',
      requestKey: key,
      body: {
        'topic': 'natal',
        'profile_revision': revision,
        'calculation_result_id': resultId,
        'locale': locale,
      },
    );
    final ref = ReportReference.fromJson({
      'calculation_result_id': resultId,
      'locale': locale,
      'profile_revision': revision,
      ...value,
    });
    if (ref.resultId != resultId ||
        ref.locale != locale ||
        ref.profileRevision != revision) {
      throw const FormatException('invalid_report_reference');
    }
    await remember(owner, ref);
    return ref;
  }

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

  Future<List<ReportReference>> list() async {
    final value = await api.get('/api/western/reports');
    final items = value['items'];
    if (items is! List) return const [];
    return [
      for (final item in items.whereType<Map<String, dynamic>>())
        ReportReference.fromJson(item),
    ];
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
