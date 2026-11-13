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
}

class ConfigurationRepository {
  ConfigurationRepository(this.api);

  final ApiClient api;

  Future<AppCapabilities> load() async {
    final json = await api.get('/api/config', authenticated: false);
    final modules = json['modules'];
    final app = json['app_capabilities'];
    final western =
        modules is List &&
        modules.any(
          (item) =>
              item is Map &&
              item['id'] == 'western_astrology' &&
              item['status'] == 'ready',
        );
    final reports = western && app is Map && app['western_reports'] == true;
    final notice = app is Map ? app['ai_notice_version'] : null;
    return AppCapabilities(
      western: western,
      reports: reports,
      appleLogin: app is Map && app['apple_login'] == true,
      applePurchase: reports && app['apple_iap'] == true,
      developmentLogin: json['account_login'] == true,
      guestReading: json['guest_reading'] == true,
      aiNoticeVersion: notice is String && notice.isNotEmpty ? notice : null,
    );
  }

  Future<void> consent(String version) async {
    await api.request(
      'POST',
      '/api/privacy/consents',
      body: {
        'purpose': 'ai_reading',
        'notice_version': version,
        'granted': true,
      },
    );
  }
}
