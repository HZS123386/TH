import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/information_page.dart' deferred as information;
import '../features/landing_page.dart';
import '../features/report_page.dart' deferred as reports;
import '../features/support_content.dart';
import '../ui/site_header.dart';
import '../ui/theme.dart';
import 'controller.dart';
import 'localizations.dart';
import 'languages.dart';

class H5App extends StatefulWidget {
  const H5App({
    required this.controller,
    this.initialLocation,
    this.openingReportId,
    super.key,
  });
  final H5Controller controller;
  final String? initialLocation, openingReportId;

  @visibleForTesting
  static Future<void> loadRoutesForWidgetTests() async {
    await reports.loadLibrary();
    await information.loadLibrary();
  }

  @override
  State<H5App> createState() => _H5AppState();
}

class _H5AppState extends State<H5App> {
  Timer? _timingFrame;
  late final _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => state.uri.path == '/'
            // The outgoing report still needs a Material ancestor while the HTML form takes over.
            ? Material(type: MaterialType.transparency, child: child)
            : _Shell(
                isReport: state.uri.path == '/report.html',
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
                  : state.uri.queryParameters['topic'] == 'career'
                  ? 'career'
                  : 'life',
            ),
          ),
          GoRoute(
            path: '/privacy.html',
            builder: (context, state) => _DeferredPage(
              load: information.loadLibrary,
              page: () => information.InformationPage(),
            ),
          ),
          GoRoute(
            path: '/support.html',
            builder: (context, state) => _DeferredPage(
              load: information.loadLibrary,
              page: () => information.InformationPage(
                support: true,
                purchasePolicy: PurchasePolicy.values
                    .asNameMap()[state.uri.queryParameters['policy']],
              ),
            ),
          ),
          GoRoute(
            path: '/report.html',
            builder: (context, state) {
              final id = state.uri.queryParameters['id'] ?? '';
              final openedFromForm = id == widget.openingReportId;
              return _DeferredPage(
                load: reports.loadLibrary,
                page: () => reports.ReportPage(
                  key: ValueKey(state.uri.queryParameters['id']),
                  h5: widget.controller,
                  id: id,
                  openedFromForm: openedFromForm,
                  paymentReturn:
                      state.uri.queryParameters['payment_return'] == '1',
                ),
              );
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const LandingPage(),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _observeFirstFrame());
  }

  void _observeFirstFrame() {
    if (!mounted) return;
    // Web batches raster timings for 100ms; an idle page needs a later frame.
    _timingFrame = Timer.periodic(const Duration(milliseconds: 160), (timer) {
      if (!mounted || WidgetsBinding.instance.firstFrameRasterized) {
        timer.cancel();
        return;
      }
      WidgetsBinding.instance.scheduleFrame();
    });
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
        _timingFrame?.cancel();
        if (!mounted) return;
        widget.controller.browser.pageReady('app-ready');
      }),
    );
  }

  @override
  void dispose() {
    _timingFrame?.cancel();
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
        locale: h5Locale(widget.controller.language),
        supportedLocales: h5Locales,
        localizationsDelegates: h5Localizations,
        routerConfig: _router,
      ),
    ),
  );
}

class _DeferredPage extends StatefulWidget {
  const _DeferredPage({
    required this.load,
    required this.page,
    this.showLoading = true,
  });

  final Future<void> Function() load;
  final Widget Function() page;
  final bool showLoading;

  @override
  State<_DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<_DeferredPage> {
  late Future<void> _library = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _library,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return widget.showLoading
            ? const Center(child: CircularProgressIndicator())
            : const SizedBox.shrink();
      }
      if (!snapshot.hasError) return widget.page();
      final copy = H5Scope.of(context).copy;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(copy.t('ui', 'network'), textAlign: TextAlign.center),
            TextButton(
              onPressed: () => setState(() => _library = widget.load()),
              child: Text(copy.t('generation', 'retry')),
            ),
          ],
        ),
      );
    },
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.isReport});
  final Widget child;
  final bool isReport;
  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= 700;
    return ColoredBox(
      color: const Color(0xFF0B0715),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 24 : 0,
            vertical: wide && screen.height >= 600 ? 24 : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: h5PageMaxWidth),
              child: Scaffold(
                body: Column(
                  children: [
                    SiteHeader(
                      showLanguages: !isReport,
                      homeArrowLeading: isReport,
                    ),
                    Expanded(child: child),
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
