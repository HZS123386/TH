import '../core/network/api_client.dart';

class AppCapabilities {
  const AppCapabilities({
    this.western = false,
    this.reports = false,
    this.appleLogin = false,
    this.applePurchase = false,
    this.googlePurchase = false,
    this.developmentLogin = false,
    this.guestReading = false,
    this.aiNoticeVersion,
    this.companionProvider,
    this.accountDeletion = false,
    this.contentReporting = false,
    this.companionRecipients = const [],
  });

  final bool western, reports, appleLogin, applePurchase, developmentLogin;
  final bool googlePurchase;
  final bool guestReading;
  final String? aiNoticeVersion;
  final String? companionProvider;
  final bool accountDeletion, contentReporting;
  final List<String> companionRecipients;
  String get companionRecipientLabel =>
      (companionRecipients.isEmpty
              ? [companionProvider ?? 'AI']
              : companionRecipients)
          .map(
            (id) => switch (id) {
              'qwen' => 'Qwen (Alibaba)',
              'kimi' => 'Kimi (Moonshot AI)',
              'openai' => 'OpenAI',
              'deepseek' => 'DeepSeek',
              _ => id,
            },
          )
          .join(' / ');

  factory AppCapabilities.fromJson(Map<String, dynamic> json) {
    const enableAppleLogin = bool.fromEnvironment('FATE_ENABLE_APPLE_LOGIN');
    const enableInAppPurchases = bool.fromEnvironment(
      'FATE_ENABLE_IN_APP_PURCHASES',
    );
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
    final providers = json['providers'];
    final enabled = providers is List
        ? providers
              .whereType<Map>()
              .where((item) => item['enabled'] == true && item['id'] != 'mock')
              .map((item) => item['id'])
              .toSet()
        : <Object?>{};
    final provider = [
      'companion',
      json['default_provider'],
      'qwen',
      'kimi',
      'openai',
      'deepseek',
    ].whereType<String>().where(enabled.contains).firstOrNull;
    return AppCapabilities(
      western: western,
      reports: reports,
      appleLogin: enableAppleLogin && app is Map && app['apple_login'] == true,
      applePurchase:
          enableInAppPurchases && reports && app['apple_iap'] == true,
      googlePurchase:
          enableInAppPurchases && reports && app['google_play_billing'] == true,
      developmentLogin: json['account_login'] == true,
      guestReading: json['guest_reading'] == true,
      aiNoticeVersion: notice is String && notice.isNotEmpty ? notice : null,
      companionProvider: provider,
      accountDeletion: app is Map && app['account_deletion'] == true,
      contentReporting: app is Map && app['content_reporting'] == true,
      companionRecipients: provider == 'companion'
          ? ['qwen', 'kimi'].where(enabled.contains).toList()
          : [?provider],
    );
  }
}

class ConfigurationRepository {
  ConfigurationRepository(this.api);

  final ApiClient api;

  Future<AppCapabilities> load() async => AppCapabilities.fromJson(
    await api.get('/api/config', authenticated: false),
  );

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
