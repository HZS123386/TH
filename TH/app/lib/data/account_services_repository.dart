import '../app/session_view_model.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

/// Service-backed account actions stay closed until the server advertises them.
class AccountServicesRepository {
  const AccountServicesRepository(
    this.api,
    this.session, {
    this.configuredSupportEmail = const String.fromEnvironment(
      'FATE_SUPPORT_EMAIL',
    ),
  });
  final ApiClient api;
  final SessionViewModel session;
  final String configuredSupportEmail;

  static Uri? publicUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  Uri? get privacyUrl =>
      _informationUrl(const String.fromEnvironment('FATE_PRIVACY_URL'));
  Uri? get termsUrl =>
      publicUrl(const String.fromEnvironment('FATE_TERMS_URL'));
  Uri? get supportUrl =>
      _informationUrl(const String.fromEnvironment('FATE_SUPPORT_URL'));

  Uri? _informationUrl(String value) {
    final uri = publicUrl(value);
    final language = session.locale.languageCode;
    if (uri == null ||
        !session.thaiAstrologyOnly ||
        language == 'th' ||
        ![
          '/app-info/privacy.html',
          '/app-info/support.html',
        ].contains(uri.path)) {
      return uri;
    }
    return uri.replace(path: uri.path.replaceFirst('.html', '-$language.html'));
  }

  Future<String?> supportEmail() async {
    final configured = _validEmail(configuredSupportEmail);
    if (configured != null) return configured;
    final result = await api.get('/api/landing/config', authenticated: false);
    return _validEmail(result['support_email']);
  }

  static String? _validEmail(Object? value) {
    final email = value is String ? value.trim() : null;
    return email != null &&
            RegExp(r'^[^\s@?&#]+@[^\s@?&#]+\.[^\s@?&#]+$').hasMatch(email)
        ? email
        : null;
  }

  Future<String> reportContent({
    required String kind,
    required String id,
    required String reason,
    required String detail,
    required String requestKey,
  }) async {
    if (!session.capabilities.contentReporting || !session.auth.hasSession) {
      throw const ApiFailure('service_unavailable');
    }
    if (!['chat', 'western_report'].contains(kind) ||
        id.isEmpty ||
        ![
          'harmful',
          'sexual',
          'hate',
          'privacy',
          'misleading',
          'other',
        ].contains(reason) ||
        detail.length > 1000) {
      throw const ApiFailure('invalid_request');
    }
    final result = await api.request(
      'POST',
      '/api/content-reports',
      requestKey: requestKey,
      body: {
        'content_type': kind,
        'content_id': id,
        'reason': reason,
        'details': detail,
        'locale': session.locale.languageCode,
      },
    );
    final receipt = result['report_id'];
    if (result['status'] != 'received' ||
        receipt is! String ||
        receipt.isEmpty) {
      throw const ApiFailure('invalid_response');
    }
    return receipt;
  }

  Future<bool> deleteAccount({
    required String expectedOwner,
    required String requestKey,
  }) async {
    if (!session.capabilities.accountDeletion ||
        !session.auth.hasSession ||
        expectedOwner != session.owner) {
      throw const ApiFailure('service_unavailable');
    }
    final result = await api.request(
      'DELETE',
      '/api/account',
      requestKey: requestKey,
      body: {'confirmation': 'delete_account'},
    );
    // A queued request or an empty response must never be shown as deletion.
    if (result['status'] != 'deleted' || result['user_id'] != expectedOwner) {
      throw const ApiFailure('invalid_response');
    }
    var cleaned = true;
    for (final kind in [
      'birth',
      'companion',
      'ai-consent',
      'active-report',
      LocalDraftStore.exampleBookmark,
      LocalDraftStore.legacyExampleBookmark,
      'pending-apple-order',
      'pending-google-play-order',
      LocalDraftStore.actionLedger,
      LocalDraftStore.guideConversations,
    ]) {
      try {
        await session.drafts.remove(expectedOwner, kind);
      } catch (_) {
        cleaned = false;
      }
    }
    if (session.owner == expectedOwner) {
      try {
        await session.auth.clear();
      } catch (_) {
        cleaned = false;
      }
    }
    return cleaned;
  }
}
