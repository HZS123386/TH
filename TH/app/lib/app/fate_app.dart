import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/account/account_page.dart';
import '../features/account/birth_page.dart';
import '../features/account/login_page.dart';
import '../features/chart/chart_page.dart';
import '../features/home/home_page.dart';
import '../features/reports/reports_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/theme.dart';
import 'dependencies.dart';

class FateApp extends StatefulWidget {
  const FateApp({required this.dependencies, super.key});
  final AppDependencies dependencies;
  @override
  State<FateApp> createState() => _FateAppState();
}

class _FateAppState extends State<FateApp> {
  bool _firstFrameDeferred = true;

  @override
  void initState() {
    super.initState();
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
    initialLocation: '/fortune',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/fortune', builder: (_, _) => const HomePage()),
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
              titleSpacing: 18,
              title: InkWell(
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
                IconButton(
                  tooltip: session.auth.signedIn ? s.account : s.login,
                  onPressed: () =>
                      context.go(session.auth.signedIn ? '/profile' : '/login'),
                  icon: const Icon(Icons.person_outline, size: 22),
                ),
              ],
            ),
            body: child,
            bottomNavigationBar: NavigationBar(
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
