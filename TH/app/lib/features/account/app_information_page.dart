import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/generated/app_localizations.dart';

final _informationDocument = RegExp(
  r'^/app-info/(privacy|support)(-(en|zh|vi))?\.html$',
);
final _informationIndex = RegExp(r'^/app-info/index(-(en|zh|vi))?\.html$');

Future<void> openServiceLink(
  BuildContext context,
  Uri uri, {
  bool appInformation = false,
}) async {
  final isDocument =
      appInformation &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      _informationDocument.hasMatch(uri.path);
  if (isDocument && !kIsWeb && WebViewPlatform.instance != null) {
    final router = GoRouter.of(context);
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => _AppInformationPage(url: uri)),
    );
    if (context.mounted) router.go('/more');
    return;
  }

  final s = AppLocalizations.of(context);
  final webPreview =
      isDocument &&
      kIsWeb &&
      const {'localhost', '127.0.0.1', '::1'}.contains(Uri.base.host);
  final target = appInformation && kIsWeb
      ? uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'from': 'app',
            if (webPreview) 'app_origin': Uri.base.origin,
          },
        )
      : uri;
  final mode = appInformation && !kIsWeb
      ? LaunchMode.inAppBrowserView
      : LaunchMode.externalApplication;
  try {
    if (await launchUrl(
      target,
      mode: mode,
      webOnlyWindowName: webPreview ? '_self' : null,
    )) {
      return;
    }
  } catch (_) {
    /* Leave a readable copy option if no external handler exists. */
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(s.openFailed),
      action: SnackBarAction(
        label: uri.scheme == 'mailto' ? s.copyAddress : s.copyLink,
        onPressed: () => Clipboard.setData(
          ClipboardData(
            text: uri.scheme == 'mailto' ? uri.path : uri.toString(),
          ),
        ),
      ),
    ),
  );
}

class _AppInformationPage extends StatefulWidget {
  const _AppInformationPage({required this.url});

  final Uri url;

  @override
  State<_AppInformationPage> createState() => _AppInformationPageState();
}

class _AppInformationPageState extends State<_AppInformationPage> {
  late final WebViewController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _controller.setBackgroundColor(const Color(0xFF151022));
      await _controller.setJavaScriptMode(JavaScriptMode.disabled);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _navigate,
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _showError();
          },
          onHttpError: (error) {
            final url = error.request?.uri;
            if (url == null || _informationDocument.hasMatch(url.path)) {
              _showError();
            }
          },
        ),
      );
      await _controller.loadRequest(widget.url);
    } on PlatformException {
      _showError();
    }
  }

  NavigationDecision _navigate(NavigationRequest request) {
    final url = Uri.tryParse(request.url);
    if (!mounted || !request.isMainFrame || url == null) {
      return NavigationDecision.prevent;
    }
    if (url.scheme == 'mailto') {
      unawaited(openServiceLink(context, url));
      return NavigationDecision.prevent;
    }
    if (url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.origin != widget.url.origin) {
      return NavigationDecision.prevent;
    }
    // Public pages link to their index when opened outside FATE.
    if (_informationIndex.hasMatch(url.path)) {
      if (ModalRoute.isCurrentOf(context) == true) Navigator.of(context).pop();
      return NavigationDecision.prevent;
    }
    return _informationDocument.hasMatch(url.path)
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
  }

  void _showError() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF151022),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.openFailed),
                    TextButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        unawaited(_load());
                      },
                      child: Text(s.serviceRetry),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.back),
                    ),
                  ],
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
