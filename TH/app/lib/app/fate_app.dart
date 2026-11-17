import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_page.dart';
import '../features/account/birth_page.dart';
import '../features/account/login_page.dart';
import '../features/chart/chart_page.dart';
import '../features/home/daily_horoscope.dart';
import '../features/home/home_page.dart';
import '../features/lucky_numbers/lucky_numbers_page.dart';
import '../features/reports/reports_page.dart';
import '../features/reports/report_records_page.dart';
import '../features/reports/report_progress_page.dart';
import '../features/tarot/tarot_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/theme.dart';
import 'app_opening.dart';
import 'dependencies.dart';

String _reportRecordsLocation(Map<String, String> parameters) =>
    switch (parameters['origin']) {
      'reports' => '/reports',
      'profile' => '/chart/readings?from=profile',
      _ => '/chart/readings',
    };

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

class _FateAppState extends State<FateApp> {
  bool _firstFrameDeferred = false;
  final _rootNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (_showOpening) return;
    _firstFrameDeferred = true;
    final binding = WidgetsBinding.instance;
    binding.deferFirstFrame();
    // Build normally, but present the first frame only after the hero is decoded.
    binding.addPostFrameCallback((_) async {
      try {
        if (mounted) await precacheImage(homeHeroImage, context);
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

  late final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/fortune',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _AppShell(
          path: state.uri.path == DailyHoroscopePage.location
              ? '/fortune'
              : state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/fortune',
            builder: (_, _) => const HomePage(),
            routes: [
              GoRoute(path: 'tarot', builder: (_, _) => const TarotPage()),
              GoRoute(
                path: DailyHoroscopePage.path,
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) {
                  final reduceMotion = MediaQuery.disableAnimationsOf(context);
                  return CustomTransitionPage<void>(
                    key: state.pageKey,
                    transitionDuration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 230),
                    reverseTransitionDuration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 190),
                    transitionsBuilder: (context, animation, _, child) {
                      // Slide the opaque page in one pass without blending two full screens.
                      return SlideTransition(
                        position: animation
                            .drive(CurveTween(curve: Curves.easeInOutCubic))
                            .drive(
                              Tween(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ),
                            ),
                        child: child,
                      );
                    },
                    child: const _AppShell(
                      path: DailyHoroscopePage.location,
                      child: DailyHoroscopePage(),
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'lucky-numbers',
                builder: (_, _) => const LuckyNumbersPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/chart',
            builder: (_, state) =>
                ChartPage(example: state.uri.queryParameters['example'] == '1'),
            routes: [
              GoRoute(
                path: 'reading',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, state) => _AppShell(
                  path: state.uri.path,
                  backLocation: state.uri.queryParameters['from'] == 'history'
                      ? _reportRecordsLocation(state.uri.queryParameters)
                      : state.uri.queryParameters['example'] == '1'
                      ? '/chart?example=1'
                      : '/chart',
                  child: ReportsPage(
                    example: state.uri.queryParameters['example'] == '1',
                    fromChart: ![
                      'history',
                      'generation',
                    ].contains(state.uri.queryParameters['from']),
                  ),
                ),
              ),
              GoRoute(
                path: 'generating',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, state) {
                  final parameters = Map<String, String>.from(
                    state.uri.queryParameters,
                  )..remove('report');
                  final history = parameters['from'] == 'history';
                  final back = history
                      ? _reportRecordsLocation(parameters)
                      : '/chart';
                  if (!history) parameters['from'] = 'generation';
                  final destination = Uri(
                    path: '/chart/reading',
                    queryParameters: parameters,
                  ).toString();
                  return _AppShell(
                    path: state.uri.path,
                    backLocation: back,
                    child: ReportProgressPage(
                      reportId: state.uri.queryParameters['report'],
                      destination: destination,
                      backLocation: back,
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'readings',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, state) => _AppShell(
                  path: state.uri.path,
                  backLocation: state.uri.queryParameters['from'] == 'profile'
                      ? '/profile'
                      : '/chart',
                  child: ReportRecordsPage(
                    origin: state.uri.queryParameters['from'] == 'profile'
                        ? ReportRecordsOrigin.profile
                        : ReportRecordsOrigin.chart,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (_, _) =>
                const ReportRecordsPage(origin: ReportRecordsOrigin.reports),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const AccountPage()),
          GoRoute(path: '/birth', builder: (_, _) => const BirthPage()),
          GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        ],
      ),
      GoRoute(path: '/', redirect: (_, _) => '/fortune'),
    ],
    errorBuilder: (_, _) => const HomePage(),
  );

  late final bool _showOpening =
      widget.playOpening &&
      const {
        '/',
        '/fortune',
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
      builder: (context, child) =>
          _showOpening ? AppOpening(child: child!) : child!,
    ),
  );
  @override
  void dispose() {
    _allowFirstFrame();
    _router.dispose();
    super.dispose();
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.path, required this.child, this.backLocation});
  final String path;
  final Widget child;
  final String? backLocation;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        session = DependencyScope.of(context).session;
    final daily = path == DailyHoroscopePage.location;
    final selected = path.startsWith('/chart') || path == '/birth'
        ? 1
        : path.startsWith('/reports')
        ? 2
        : ['/profile', '/login'].contains(path)
        ? 3
        : 0;
    return ColoredBox(
      color: const Color(0xFF0B0715),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            key: backLocation == null
                ? null
                : const ValueKey('standalone-chart-reading'),
            appBar: AppBar(
              leading: backLocation == null
                  ? (path.startsWith('/fortune/')
                        ? BackButton(onPressed: () => context.pop())
                        : null)
                  : IconButton(
                      key: const ValueKey('reading-back'),
                      tooltip:
                          backLocation == '/reports' ||
                              backLocation!.startsWith('/chart/readings')
                          ? s.savedReadings
                          : backLocation == '/profile'
                          ? s.mine
                          : s.backToChart,
                      onPressed: () => context.go(backLocation!),
                      icon: const Icon(Icons.arrow_back),
                    ),
              titleSpacing: 18,
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_outlined, size: 25),
                          SizedBox(width: 12),
                          Text(
                            'FATE',
                            style: TextStyle(
                              fontFamily: 'serif',
                              letterSpacing: 3,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
              actions: [
                if (backLocation != null && path == '/chart/reading')
                  IconButton(
                    key: const ValueKey('chart-reading-history'),
                    tooltip: s.savedReadings,
                    onPressed: () => context.go(
                      backLocation == '/reports' ||
                              backLocation!.startsWith('/chart/readings')
                          ? backLocation!
                          : '/chart/readings',
                    ),
                    icon: const Icon(Icons.history, size: 21),
                  ),
                PopupMenuButton<String>(
                  tooltip: s.language,
                  icon: const Icon(Icons.language_outlined, size: 21),
                  onSelected: session.changeLocale,
                  itemBuilder: (_) => [
                    for (final row in const [
                      ('th', 'ภาษาไทย'),
                      ('en', 'English'),
                      ('zh', '简体中文'),
                      ('vi', 'Tiếng Việt'),
                    ])
                      PopupMenuItem(value: row.$1, child: Text(row.$2)),
                  ],
                ),
                if (!daily)
                  IconButton(
                    tooltip: session.auth.signedIn ? s.account : s.login,
                    onPressed: () => context.go(
                      session.auth.signedIn ? '/profile' : '/login',
                    ),
                    icon: const Icon(Icons.person_outline, size: 22),
                  ),
              ],
            ),
            body: backLocation == null
                ? child
                : SafeArea(top: false, child: child),
            bottomNavigationBar: backLocation == null && !daily
                ? _AppNavigationBar(selectedIndex: selected)
                : null,
          ),
        ),
      ),
    );
  }
}

class _AppNavigationBar extends StatelessWidget {
  const _AppNavigationBar({required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final destinations = [
      (path: '/fortune', label: s.home, icon: Icons.home_outlined),
      (path: '/chart', label: s.chart, icon: Icons.public_outlined),
      (path: '/reports', label: s.reports, icon: Icons.menu_book_outlined),
      (path: '/profile', label: s.mine, icon: Icons.person_outline),
    ];
    final scaledLabel = MediaQuery.textScalerOf(context).scale(10.5);
    final itemHeight = scaledLabel > 10.5
        ? 60 + (scaledLabel - 10.5) * 3
        : 60.0;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        key: const ValueKey('app-bottom-navigation'),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0C2C),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF513568), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3305000C),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          height: itemHeight,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _NavigationItem(
                    key: ValueKey('app-nav${destinations[index].path}'),
                    label: destinations[index].label,
                    icon: destinations[index].icon,
                    selected: selectedIndex == index,
                    onTap: () => context.go(destinations[index].path),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFCF4FF) : const Color(0xFFB3A0C9);
    return Semantics(
      button: true,
      selected: selected,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: AnimatedContainer(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8537C4),
                      Color(0xFFAE28D4),
                      Color(0xFFD21ACB),
                    ],
                  )
                : null,
            border: Border.all(
              color: selected ? const Color(0x66D88AF5) : Colors.transparent,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x50911CC7),
                      blurRadius: 17,
                      offset: Offset(0, 5),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
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
