import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';

class InformationPage extends StatefulWidget {
  const InformationPage({this.support = false, super.key});
  final bool support;
  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  final _request = CancelToken();
  bool _loaded = false;
  bool _recordedPage = false;
  String _email = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recordedPage) {
      _recordedPage = true;
      H5Scope.of(context).trackActivity(widget.support ? 'support' : 'privacy');
    }
    if (widget.support && !_loaded) {
      _loaded = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final h5 = H5Scope.of(context);
      final data = object(
        await h5.repository.request(
          '/api/landing/config',
          _request,
          owned: false,
        ),
      );
      if (mounted) setState(() => _email = text(data['support_email']));
    } catch (_) {
      // The data-use explanation is readable even when support is unavailable.
    }
  }

  @override
  void dispose() {
    _request.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context), c = h5.copy;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
            child: JYCard(
              padding: const EdgeInsets.all(24),
              radius: 20,
              borderColor: line,
              colors: const [panel, panel],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    c.t('jy', widget.support ? 'supportTitle' : 'privacy'),
                    style: const TextStyle(
                      fontSize: 27,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.support)
                    SelectableText(
                      _email.isEmpty ? c.t('jy', 'noSupport') : _email,
                      style: TextStyle(
                        color: _email.isEmpty ? cream : gold,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    )
                  else ...[
                    for (final paragraph in c.list('jy', 'privacyDetails'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          paragraph,
                          style: const TextStyle(fontSize: 14, height: 1.55),
                        ),
                      ),
                    Text(c.t('jy', 'privacyContact')),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            context.go('/support.html?lang=${h5.language}'),
                        child: Text(c.t('jy', 'support')),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${c.t('jy', 'geoNames')} ',
                        style: const TextStyle(color: lavender, fontSize: 12),
                      ),
                      InkWell(
                        onTap: () =>
                            h5.browser.openPage('https://www.geonames.org/'),
                        child: const Text(
                          'GeoNames',
                          style: TextStyle(
                            color: gold,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(
                        ' (CC BY 4.0)',
                        style: TextStyle(color: lavender, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
