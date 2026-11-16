import '../core/network/api_client.dart';

class AppCapabilities {
  const AppCapabilities({
    this.western = false,
    this.reports = false,
    this.appleLogin = false,
    this.applePurchase = false,
    this.developmentLogin = false,
    this.guestReading = false,
    this.aiNoticeVersion,
  });
  final bool western, reports, appleLogin, applePurchase, developmentLogin;
  final bool guestReading;
  final String? aiNoticeVersion;
  factory AppCapabilities.fromJson(Map<String, dynamic> json) {
    final modules = json['modules'] as List? ?? [];
    bool ready(String id) => modules.any(
      (row) => row is Map && row['id'] == id && row['status'] == 'ready',
    );
    final features = json['app_capabilities'] is Map
        ? json['app_capabilities'] as Map
        : const {};
    return AppCapabilities(
      western: ready('western_astrology'),
      reports: features['western_reports'] == true,
      appleLogin: features['apple_login'] == true,
      applePurchase: features['apple_iap'] == true,
      developmentLogin: json['account_login'] == true,
      guestReading: json['guest_reading'] == true,
      aiNoticeVersion: features['ai_notice_version'] as String?,
    );
  }
}

class ConfigurationRepository {
  ConfigurationRepository(this.api);
  final ApiClient api;
  Future<AppCapabilities> load() async => AppCapabilities.fromJson(
    await api.get('/api/config', authenticated: false),
  );
  Future<void> consent(String noticeVersion) async {
    await api.request(
      'POST',
      '/api/privacy/consents',
      body: {
        'purpose': 'ai_reading',
        'notice_version': noticeVersion,
        'granted': true,
      },
    );
  }
}
