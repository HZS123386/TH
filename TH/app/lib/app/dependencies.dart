import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';
import '../data/auth_repository.dart';
import '../data/configuration_repository.dart';
import '../data/daily_horoscope_repository.dart';
import '../data/thai_calendar_repository.dart';
import '../data/profile_repository.dart';
import '../data/western_repository.dart';
import '../data/reports_repository.dart';
import '../data/purchase_repository.dart';
import '../features/chart/chart_view_model.dart';
import '../features/home/daily_horoscope_view_model.dart';
import '../features/reports/reports_view_model.dart';
import '../features/purchases/purchase_view_model.dart';
import 'session_view_model.dart';

class AppDependencies {
  AppDependencies(
    SharedPreferences preferences, {
    ApiClient? client,
    SessionStore? secureStore,
  }) {
    api =
        client ??
        ApiClient(
          const String.fromEnvironment(
            'FATE_API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          ),
        );
    final drafts = LocalDraftStore(preferences);
    auth = AuthRepository(api, secureStore ?? const SecureSessionStore());
    thaiCalendar = ThaiCalendarRepository(api);
    session = SessionViewModel(
      auth,
      ProfileRepository(api, drafts),
      ConfigurationRepository(api),
      drafts,
    );
    dailyHoroscope = DailyHoroscopeViewModel(
      DailyHoroscopeRepository(api),
      preferences,
      session,
    );
    chart = ChartViewModel(WesternRepository(api), session);
    reports = ReportsViewModel(ReportsRepository(api, drafts), session);
    purchaseRepository = PurchaseRepository(api, drafts)
      ..onVerified = reports.refresh;
    purchases = PurchaseViewModel(purchaseRepository, session);
  }
  late final ApiClient api;
  late final AuthRepository auth;
  late final ThaiCalendarRepository thaiCalendar;
  late final DailyHoroscopeViewModel dailyHoroscope;
  late final SessionViewModel session;
  late final ChartViewModel chart;
  late final ReportsViewModel reports;
  late final PurchaseRepository purchaseRepository;
  late final PurchaseViewModel purchases;
  void dispose() {
    dailyHoroscope.dispose();
    purchases.dispose();
    purchaseRepository.dispose();
    reports.dispose();
    chart.dispose();
    session.dispose();
    auth.dispose();
    api.close();
  }
}

class DependencyScope extends InheritedWidget {
  const DependencyScope({
    required this.dependencies,
    required super.child,
    super.key,
  });
  final AppDependencies dependencies;
  static AppDependencies of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DependencyScope>()!
      .dependencies;
  @override
  bool updateShouldNotify(DependencyScope oldWidget) =>
      oldWidget.dependencies != dependencies;
}
