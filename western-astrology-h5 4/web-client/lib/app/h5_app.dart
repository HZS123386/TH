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
        builder: (context, state, child) => _Shell(
          report: state.uri.path == '/report.html',
          landing: state.uri.path == '/',
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => LandingPage(
              topic:
                  state.uri.queryParameters['reading'] == 'love' ||
                      state.uri.queryParameters['topic'] == 'love'
                  ? 'love'
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
            !(widget.initialLocation ?? Uri.base.path).contains(
              'report.html',
            )) {
          await precacheImage(heroImage, context);
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
  const _Shell({
    required this.child,
    required this.report,
    this.landing = false,
  });
  final Widget child;
  final bool report, landing;
  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context), c = h5.copy;
    final showWelcome = landing && h5.welcomeOpen;
    return ColoredBox(
      color: const Color(0xFF0B0715),
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
                  child: Scaffold(
                    appBar: AppBar(
                      titleSpacing: 20,
                      title: InkWell(
                        onTap: () => context.go('/?lang=${h5.language}'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_outlined, size: 25),
                            SizedBox(width: 12),
                            Text(
                              'FATE',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: report
                          ? [
                              TextButton.icon(
                                onPressed: () =>
                                    context.go('/?lang=${h5.language}'),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: Text(
                                  c.t('generation', 'back'),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ]
                          : [
                              TextButton(
                                onPressed: h5.languageLoading
                                    ? null
                                    : () async {
                                        final switched = await h5
                                            .changeLanguage('th');
                                        if (!context.mounted) return;
                                        if (!switched) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                h5.copy.t('ui', 'network'),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        final current = GoRouterState.of(
                                          context,
                                        ).uri;
                                        if (current.path != '/report.html') {
                                          context.replace(
                                            Uri(
                                              path: current.path,
                                              queryParameters: {
                                                ...current.queryParameters,
                                                'lang': 'th',
                                              },
                                            ).toString(),
                                          );
                                        }
                                      },
                                child: Text(
                                  'TH',
                                  style: TextStyle(
                                    color: h5.language == 'th'
                                        ? gold
                                        : lavender,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: h5.languageLoading
                                    ? null
                                    : () async {
                                        final switched = await h5
                                            .changeLanguage('zh');
                                        if (!context.mounted) return;
                                        if (!switched) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                h5.copy.t('ui', 'network'),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        final current = GoRouterState.of(
                                          context,
                                        ).uri;
                                        if (current.path != '/report.html') {
                                          context.replace(
                                            Uri(
                                              path: current.path,
                                              queryParameters: {
                                                ...current.queryParameters,
                                                'lang': 'zh',
                                              },
                                            ).toString(),
                                          );
                                        }
                                      },
                                child: h5.languageLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        '中文',
                                        style: TextStyle(
                                          color: h5.language == 'zh'
                                              ? gold
                                              : lavender,
                                        ),
                                      ),
                              ),
                            ],
                    ),
                    body: child,
                  ),
                ),
              ),
              if (showWelcome) Positioned.fill(child: WelcomePage(h5: h5)),
            ],
          ),
        ),
      ),
    );
  }
}
