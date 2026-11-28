import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_page.dart';
import '../features/account/birth_page.dart';
import '../features/account/login_page.dart';
import '../features/account/privacy_page.dart';
import '../features/account/support_page.dart';
import '../features/actions/action_page.dart';
import '../features/purchases/purchase_center_page.dart';
import '../features/chart/chart_page.dart';
import '../features/chart/thai_chart_page.dart';
import '../features/home/daily_horoscope.dart';
import '../features/home/home_page.dart';
import '../features/home/divination_page.dart';
import '../features/home/live_page.dart';
import '../features/home/reading_guide.dart';
import '../features/home/thai_calendar_page.dart';
import '../features/home/welcome_page.dart';
import '../features/companion/bond_page.dart';
import '../features/companion/companion_page.dart';
import '../features/companion/guardian.dart';
import '../features/lucky_numbers/lucky_numbers_page.dart';
import '../features/reports/h5_report_page.dart';
import '../features/reports/reports_page.dart';
import '../features/reports/report_progress_page.dart';
import '../features/reports/report_records_page.dart';
import '../features/reports/report_recovery_sheet.dart';
import '../features/shop/shop_page.dart';
import '../features/tarot/tarot_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/theme.dart';
import 'app_opening.dart';
import 'dependencies.dart';

class FateApp extends StatefulWidget {
  const FateApp({
    required this.dependencies,
    this.playOpening = false,
    super.key,
  });
  final AppDependencies dependencies;
  final bool playOpening;
  @override
  State<FateApp> createState() => _FateAppState();
}

class _FateAppState extends State<FateApp> with WidgetsBindingObserver {
  bool _firstFrameDeferred = false;
  final _rootNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_showOpening) return;
    _firstFrameDeferred = true;
    final binding = WidgetsBinding.instance;
    binding.deferFirstFrame();
    // Build normally, but present the first frame only after the hero is decoded.
    binding.addPostFrameCallback((_) async {
      try {
        if (mounted) {
          await Future.wait([
            precacheImage(homeHeroImage, context),
            precacheImage(sirinPortrait, context),
            precacheImage(guideDuo, context),
            precacheImage(const AssetImage(objectsArtwork), context),
            precacheImage(
              const AssetImage('assets/images/fate-brand-gold.png'),
              context,
            ),
          ]);
        }
      } finally {
        _allowFirstFrame();
      }
    });
  }

  void _allowFirstFrame() {
    if (!_firstFrameDeferred) return;
    _firstFrameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  String get _startPath =>
      widget.playOpening &&
          widget.dependencies.session.drafts.preferences.getBool(
                WelcomePage.seenKey,
              ) !=
              true
      ? '/welcome'
      : '/fortune';

  late final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _startPath,
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) =>
            _motionPage(context, state, const WelcomePage()),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final path = state.uri.path;
          final parameters = state.uri.queryParameters;
          final history = parameters['from'] == 'history';
          final back = switch (path) {
            '/chart/reading' || '/chart/generating' =>
              history
                  ? _recordsLocation(parameters['origin'])
                  : parameters['example'] == '1'
                  ? '/chart?example=1'
                  : '/chart',
            '/chart/readings' => switch (parameters['from']) {
              'profile' => '/more',
              'reports' => '/reports',
              _ => '/chart',
            },
            _ => null,
          };
          return _AppShell(
            path: path == DailyHoroscopePage.location ? '/fortune' : path,
            readingBack: back,
            hideNavigation:
                back != null &&
                !(path == '/chart/readings' && parameters['from'] == 'reports'),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/fortune',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              HomePage(
                initialGuide: ReadingGuide.fromName(
                  state.uri.queryParameters['guide'],
                ),
              ),
              tab: true,
            ),
            routes: [
              GoRoute(
                path: 'calendar',
                pageBuilder: (context, state) => _motionPage(
                  context,
                  state,
                  ThaiCalendarPage(
                    repository: widget.dependencies.thaiCalendar,
                  ),
                ),
              ),
              GoRoute(
                path: 'tarot',
                pageBuilder: (context, state) =>
                    _motionPage(context, state, const TarotPage()),
              ),
              GoRoute(
                path: DailyHoroscopePage.path,
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  return _motionPage(
                    context,
                    state,
                    const _AppShell(
                      path: DailyHoroscopePage.location,
                      child: DailyHoroscopePage(),
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'lucky-numbers',
                pageBuilder: (context, state) =>
                    _motionPage(context, state, const LuckyNumbersPage()),
              ),
            ],
          ),
          GoRoute(
            path: '/chart',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              ChartPage(example: state.uri.queryParameters['example'] == '1'),
            ),
          ),
          GoRoute(
            path: '/chart/reading',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              ReportsPage(
                detail: true,
                example: state.uri.queryParameters['example'] == '1',
                fromChart: ![
                  'history',
                  'generation',
                ].contains(state.uri.queryParameters['from']),
                backLocation: state.uri.queryParameters['from'] == 'history'
                    ? _recordsLocation(state.uri.queryParameters['origin'])
                    : '/chart',
              ),
            ),
          ),
          GoRoute(
            path: '/chart/generating',
            pageBuilder: (context, state) {
              final query = Map<String, String>.of(state.uri.queryParameters);
              final id = query.remove('report');
              final history = query['from'] == 'history';
              if (!history) query['from'] = 'generation';
              final back = history
                  ? _recordsLocation(query['origin'])
                  : '/chart';
              if (!history) query['from'] = 'generation';
              return _motionPage(
                context,
                state,
                ReportProgressPage(
                  reportId: id,
                  destination: Uri(
                    path: '/chart/reading',
                    queryParameters: query,
                  ).toString(),
                  backLocation: back,
                ),
              );
            },
          ),
          GoRoute(
            path: '/chart/readings',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              ReportRecordsPage(
                origin: switch (state.uri.queryParameters['from']) {
                  'profile' => ReportRecordsOrigin.profile,
                  'reports' => ReportRecordsOrigin.reports,
                  _ => ReportRecordsOrigin.chart,
                },
              ),
            ),
          ),
          GoRoute(
            path: '/chart/thai',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const ThaiChartPage()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const ReportsPage()),
          ),
          GoRoute(
            path: '/reports/reading',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              ReportsPage(
                detail: true,
                example: state.uri.queryParameters['example'] == '1',
              ),
            ),
          ),
          GoRoute(
            path: '/reports/h5/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return _motionPage(
                context,
                state,
                H5ReportPage(id: id, key: ValueKey(id)),
              );
            },
          ),
          GoRoute(
            path: '/divination',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const DivinationPage(), tab: true),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const BondPage(), tab: true),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const AccountPage(), tab: true),
          ),
          GoRoute(
            path: '/action',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const ActionPage(), tab: true),
          ),
          GoRoute(
            path: '/live',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              LivePage(
                room: switch (state.uri.queryParameters['room']) {
                  'temple' => LiveRoom.temple,
                  'objects' => LiveRoom.objects,
                  _ => null,
                },
              ),
              tab: true,
            ),
          ),
          GoRoute(
            path: '/shop',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const ShopPage(), tab: true),
          ),
          GoRoute(
            path: '/reading/:guide',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              CompanionPage.guide(
                key: state.pageKey,
                guide: ReadingGuide.fromName(state.pathParameters['guide']),
                voice: state.uri.queryParameters['voice'] == '1',
                sample: state.uri.queryParameters['sample'] == '1',
              ),
            ),
          ),
          GoRoute(
            path: '/companion/:guardian',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              CompanionPage(
                key: state.pageKey,
                guardian: Guardian.fromId(state.pathParameters['guardian']),
                reading: state.extra is ReadingHandoff
                    ? state.extra as ReadingHandoff
                    : null,
              ),
            ),
          ),
          GoRoute(
            path: '/birth',
            pageBuilder: (context, state) => _motionPage(
              context,
              state,
              BirthPage(
                returnToPrevious: true,
                openThaiChart: state.uri.queryParameters['reading'] == 'thai',
              ),
            ),
          ),
          GoRoute(
            path: '/login',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const LoginPage()),
          ),
          GoRoute(
            path: '/privacy',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const PrivacyPage()),
          ),
          GoRoute(
            path: '/support',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const SupportPage()),
          ),
          GoRoute(
            path: '/delete-account',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const DeleteAccountPage()),
          ),
          GoRoute(
            path: '/purchases',
            pageBuilder: (context, state) =>
                _motionPage(context, state, const PurchaseCenterPage()),
          ),
        ],
      ),
      GoRoute(path: '/', redirect: (_, _) => _startPath),
    ],
    errorBuilder: (_, _) => const HomePage(),
  );

  late final bool _showOpening =
      widget.playOpening &&
      const {
        '/',
        '/fortune',
        '/welcome',
      }.contains(_router.routeInformationProvider.value.uri.path);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.dependencies.session,
    builder: (context, _) => MaterialApp.router(
      title: 'FATE',
      debugShowCheckedModeBanner: false,
      theme: fateTheme(),
      routerConfig: _router,
      locale: widget.dependencies.session.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: FateMotion.reduced(context)),
        child: _showOpening ? AppOpening(child: child!) : child!,
      ),
    ),
  );
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _allowFirstFrame();
    _router.dispose();
    super.dispose();
  }
}

const _shellBackdrop = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, -.48),
    radius: .94,
    colors: [Color(0xFF20172E), Color(0xFF13101F)],
  ),
);

Page<void> _motionPage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool tab = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: FateMotion.duration(
      context,
      tab ? FateMotion.settle : FateMotion.page,
    ),
    reverseTransitionDuration: FateMotion.duration(context, FateMotion.settle),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (FateMotion.reduced(context)) return child;
      // Keep the route and draft alive when reduced motion changes, including on iOS.
      if (!tab && Theme.of(context).platform == TargetPlatform.iOS) {
        return CupertinoRouteTransitionMixin.buildPageTransitions<void>(
          ModalRoute.of(context)! as PageRoute<void>,
          context,
          animation,
          secondaryAnimation,
          child,
        );
      }
      final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      if (tab) {
        // Fade the incoming content over the background so outgoing text cannot show through.
        return DecoratedBox(
          decoration: _shellBackdrop,
          child: FadeTransition(opacity: eased, child: child),
        );
      }
      return FadeTransition(
        opacity: eased,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(.045, 0),
            end: Offset.zero,
          ).animate(eased),
          child: child,
        ),
      );
    },
  );
}

String _recordsLocation(String? origin) => switch (origin) {
  'profile' => '/chart/readings?from=profile',
  'reports' => '/chart/readings?from=reports',
  _ => '/chart/readings',
};

class _AppShell extends StatelessWidget {
  const _AppShell({
    required this.path,
    required this.child,
    this.readingBack,
    this.hideNavigation = false,
  });
  final String path;
  final Widget child;
  final String? readingBack;
  final bool hideNavigation;
  static const _tabs = ['/fortune', '/action', '/live', '/shop', '/more'];

  Future<void> _showQuickAccess(BuildContext context) async {
    final s = AppLocalizations.of(context);
    final entries = [
      (
        s.dailyHoroscopeTitle,
        Icons.wb_twilight_outlined,
        DailyHoroscopePage.location,
      ),
      (s.tarot, Icons.style_outlined, '/fortune/tarot'),
      (s.calendarTitle, Icons.calendar_month_outlined, '/fortune/calendar'),
      (s.luckyNumbers, Icons.auto_awesome_outlined, '/fortune/lucky-numbers'),
      (s.chart, Icons.explore_outlined, '/chart'),
      (s.reports, Icons.menu_book_outlined, '/reports'),
    ];
    final destination = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 430),
      sheetAnimationStyle: FateMotion.dialog(context),
      builder: (sheet) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  s.quickAccess,
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
              ),
              for (final (title, icon, location) in entries)
                ListTile(
                  leading: Icon(icon, color: goldColor),
                  title: Text(title),
                  trailing: Icon(
                    path == location ? Icons.check : Icons.chevron_right,
                    color: path == location ? goldColor : mutedColor,
                  ),
                  onTap: () => Navigator.pop(sheet, location),
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || destination == null || destination == path) return;
    FateMotion.selectionFeedback();
    context.push(destination);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), d = DependencyScope.of(context);
    final daily = path == DailyHoroscopePage.location;
    final chatting = path.startsWith('/companion/');
    final calendar = path == '/fortune/calendar';
    final selected = _tabs.contains(path)
        ? _tabs.indexOf(path)
        : const [
            '/profile',
            '/login',
            '/privacy',
            '/support',
            '/delete-account',
            '/purchases',
          ].contains(path)
        ? 4
        : 0;
    final showBack = !_tabs.contains(path);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return ColoredBox(
      color: const Color(0xFF0B0715),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: DecoratedBox(
            decoration: _shellBackdrop,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: chatting || calendar
                  ? null
                  : AppBar(
                      backgroundColor: Colors.transparent,
                      automaticallyImplyLeading: false,
                      leading: readingBack != null
                          ? BackButton(
                              key: const ValueKey('reading-back'),
                              onPressed: () => context.go(readingBack!),
                            )
                          : showBack
                          ? BackButton(
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go(
                                      path.startsWith('/reports/h5/')
                                          ? '/reports'
                                          : _tabs[selected],
                                    ),
                            )
                          : null,
                      toolbarHeight: 56,
                      titleSpacing: showBack ? 0 : 20,
                      centerTitle: daily ? true : null,
                      title: daily
                          ? Text(
                              s.dailyHoroscopeTitle,
                              style: const TextStyle(
                                color: horoscopeTitleColor,
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : InkWell(
                              onTap: () => context.go('/fortune'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Image.asset(
                                  'assets/images/fate-brand-gold.png',
                                  height: 22,
                                  semanticLabel: 'FATE',
                                ),
                              ),
                            ),
                      actions: [
                        if (!daily)
                          IconButton(
                            tooltip: s.quickAccess,
                            onPressed: () => _showQuickAccess(context),
                            icon: const Icon(Icons.grid_view_rounded, size: 20),
                          ),
                        if (daily)
                          PopupMenuButton<String>(
                            tooltip: s.language,
                            icon: const Icon(Icons.language_outlined, size: 21),
                            onSelected: d.session.changeLocale,
                            itemBuilder: (_) => [
                              for (final row in const [
                                ('th', 'ภาษาไทย'),
                                ('en', 'English'),
                                ('zh', '简体中文'),
                                ('vi', 'Tiếng Việt'),
                              ])
                                PopupMenuItem(
                                  value: row.$1,
                                  child: Text(row.$2),
                                ),
                            ],
                          ),
                        if (!daily)
                          TextButton.icon(
                            onPressed: () => showReportRecovery(context),
                            icon: const Icon(Icons.article_outlined, size: 17),
                            label: Text(
                              s.recoverReportAction,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: mutedColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        if (path == '/shop' || path == '/live')
                          ValueListenableBuilder(
                            valueListenable: d.demoCart,
                            builder: (context, items, _) {
                              final count = items.values.fold<int>(
                                0,
                                (total, value) => total + value,
                              );
                              return IconButton(
                                tooltip: s.shopCart,
                                onPressed: () => showShopCart(context),
                                icon: Badge(
                                  isLabelVisible: count > 0,
                                  label: Text('$count'),
                                  backgroundColor: goldColor,
                                  textColor: canvasColor,
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 21,
                                  ),
                                ),
                              );
                            },
                          )
                        else if (!daily)
                          IconButton(
                            tooltip: s.mine,
                            onPressed: () => context.go('/more'),
                            icon: const Icon(
                              Icons.person_outline,
                              color: mutedColor,
                              size: 22,
                            ),
                          ),
                        const SizedBox(width: 9),
                      ],
                    ),
              body: child,
              bottomNavigationBar:
                  hideNavigation || daily || chatting || keyboard
                  ? null
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x55463655)),
                        ),
                      ),
                      child: NavigationBar(
                        key: const ValueKey('app-bottom-navigation'),
                        height: 64,
                        backgroundColor: const Color(0xFF171222),
                        animationDuration: FateMotion.duration(
                          context,
                          FateMotion.change,
                        ),
                        selectedIndex: selected,
                        onDestinationSelected: (index) {
                          if (index != selected) FateMotion.selectionFeedback();
                          context.go(_tabs[index]);
                        },
                        destinations: [
                          NavigationDestination(
                            icon: const Icon(Icons.wb_sunny_outlined),
                            selectedIcon: const Icon(Icons.wb_sunny_rounded),
                            label: s.todayTab,
                          ),
                          NavigationDestination(
                            icon: const Icon(
                              Icons.eco_outlined,
                              color: actionColor,
                            ),
                            selectedIcon: const Icon(
                              Icons.eco_rounded,
                              color: actionColor,
                            ),
                            label: s.actionTab,
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.ondemand_video_outlined),
                            selectedIcon: const Icon(
                              Icons.ondemand_video_rounded,
                            ),
                            label: s.liveTab,
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.shopping_bag_outlined),
                            selectedIcon: const Icon(
                              Icons.shopping_bag_rounded,
                            ),
                            label: s.objectsTab,
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.person_outline),
                            selectedIcon: const Icon(Icons.person_rounded),
                            label: s.mine,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
