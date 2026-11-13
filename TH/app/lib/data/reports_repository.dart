import '../core/models/report.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class ReportReference {
  const ReportReference(this.id, this.resultId, this.locale);

  final String id, resultId, locale;

  factory ReportReference.fromJson(Map<String, dynamic> value) {
    final id = value['report_id'];
    final resultId = value['calculation_result_id'];
    final locale = value['locale'];
    if (id is! String ||
        id.isEmpty ||
        resultId is! String ||
        resultId.isEmpty ||
        locale is! String ||
        locale.isEmpty) {
      throw const FormatException('invalid_report_reference');
    }
    return ReportReference(id, resultId, locale);
  }

  Map<String, dynamic> toJson() => {
    'report_id': id,
    'calculation_result_id': resultId,
    'locale': locale,
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

  Future<ReportReference> create(
    String owner,
    String resultId,
    int revision,
    String locale,
    String key,
  ) async {
    final value = await api.request(
      'POST',
      '/api/life-reports',
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
      ...value,
    });
    if (ref.resultId != resultId || ref.locale != locale) {
      throw const FormatException('invalid_report_reference');
    }
    await drafts.write(owner, 'active-report', ref.toJson());
    return ref;
  }

  Future<ReportSnapshot> read(ReportReference ref) async {
    final value = await api.get(
      '/api/life-reports/${Uri.encodeComponent(ref.id)}',
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
    final value = await api.get('/api/life-reports');
    final items = value['items'];
    if (items is! List) return const [];
    return [
      for (final item in items.whereType<Map<String, dynamic>>())
        if (item['system'] == 'western_natal') ReportReference.fromJson(item),
    ];
  }
}
