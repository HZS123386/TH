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
          ),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
          GoRoute(
            path: '/reports/reading',
            builder: (_, state) => ReportsPage(
              detail: true,
              example: state.uri.queryParameters['example'] == '1',
            ),
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
  const _AppShell({required this.path, required this.child});
  final String path;
  final Widget child;
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
            appBar: AppBar(
              leading: path.startsWith('/fortune/')
                  ? BackButton(onPressed: () => context.pop())
                  : null,
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
            body: child,
            bottomNavigationBar: daily
                ? null
                : NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: (index) => context.go(
                      ['/fortune', '/chart', '/reports', '/profile'][index],
                    ),
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home_rounded),
                        label: s.home,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.public_outlined),
                        label: s.chart,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.menu_book_outlined),
                        label: s.reports,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.person_outline),
                        label: s.mine,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
