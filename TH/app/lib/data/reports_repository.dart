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
}
