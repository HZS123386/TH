import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import '../features/landing_page.dart';
import '../features/report_page.dart';
import '../features/welcome_page.dart';
import '../features/information_page.dart';
import '../ui/theme.dart';
import 'controller.dart';

class H5App extends StatefulWidget {
  const H5App({required this.controller, this.initialLocation, super.key});
  final H5Controller controller;
  final String? initialLocation;
  @override
  State<H5App> createState() => _H5AppState();
}

class _H5AppState extends State<H5App> {
  bool _deferred = true;
  late final _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            _Shell(landing: state.uri.path == '/', child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => LandingPage(
              topic:
                  state.uri.queryParameters['reading'] == 'love' ||
                      state.uri.queryParameters['topic'] == 'love'
                  ? 'love'
                  : state.uri.queryParameters['topic'] == 'career'
                  ? 'career'
                  : 'life',
            ),
          ),
          GoRoute(
            path: '/privacy.html',
            builder: (context, state) => const InformationPage(),
          ),
          GoRoute(
            path: '/support.html',
            builder: (context, state) => const InformationPage(support: true),
          ),
          GoRoute(
            path: '/report.html',
            builder: (context, state) => ReportPage(
              key: ValueKey(state.uri.queryParameters['id']),
              h5: widget.controller,
              id: state.uri.queryParameters['id'] ?? '',
              checkout: state.uri.queryParameters['checkout'] == '1',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const LandingPage(),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.deferFirstFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted &&
            !(widget.initialLocation ?? Uri.base.path).contains('.html')) {
          await Future.wait([
            precacheImage(heroImage, context),
            precacheImage(
              const AssetImage('assets/images/astrologer-900.webp'),
              context,
            ),
          ]);
        }
      } finally {
        _allowFrame();
      }
    });
  }

  void _allowFrame() {
    if (!_deferred) return;
    _deferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _allowFrame();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => H5Scope(
    controller: widget.controller,
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => MaterialApp.router(
        title: 'FATE',
        debugShowCheckedModeBanner: false,
        theme: h5Theme(),
        locale: Locale(widget.controller.language),
        supportedLocales: const [Locale('th'), Locale('zh')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    ),
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.landing = false});
  final Widget child;
  final bool landing;
  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context);
    final showWelcome = landing && h5.welcomeOpen;
    return ColoredBox(
      color: const Color(0xFF0B0715),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.sizeOf(context).width >= 700 ? 28 : 0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  excluding: showWelcome,
                  child: IgnorePointer(
                    ignoring: showWelcome,
                    child: Scaffold(body: child),
                  ),
                ),
                if (showWelcome) Positioned.fill(child: WelcomePage(h5: h5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
