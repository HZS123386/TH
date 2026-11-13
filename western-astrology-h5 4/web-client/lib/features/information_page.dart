import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';
import '../ui/site_header.dart';

class InformationPage extends StatefulWidget {
  const InformationPage({this.support = false, super.key});
  final bool support;
  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  final _request = CancelToken();
  bool _loaded = false;
  String _email = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
          const SiteHeader(),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.go('/?lang=${h5.language}'),
                      child: Text(c.t('jy', 'back')),
                    ),
                  ),
                  const SizedBox(height: 17),
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

Future<bool> confirmDataUse(BuildContext context, H5Controller h5) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _DataUseDialog(h5: h5),
      ) ??
      false;
}

class _DataUseDialog extends StatefulWidget {
  const _DataUseDialog({required this.h5});
  final H5Controller h5;
  @override
  State<_DataUseDialog> createState() => _DataUseDialogState();
}

class _DataUseDialogState extends State<_DataUseDialog> {
  bool _saving = false;
  bool _outdated = false;
  String _error = '';

  Future<void> _accept() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.h5.acceptDataUse();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _outdated =
              error is ApiFailure && error.code == 'landing_notice_outdated';
          _error = widget.h5.copy.t(
            'jy',
            _outdated ? 'noticeOutdated' : 'consentError',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    return AlertDialog(
      title: Text(
        c.t('jy', 'consentTitle'),
        style: const TextStyle(fontSize: 19),
      ),
      backgroundColor: const Color(0xFF1C122D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x55E4BC78)),
      ),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.t('jy', 'consent'),
            style: const TextStyle(fontSize: 12, color: lavender),
          ),
          TextButton(
            onPressed: () => widget.h5.browser.openPage(
              'privacy.html?lang=${widget.h5.language}',
            ),
            child: Text(
              c.t('jy', 'privacy'),
              style: const TextStyle(
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          errorMessage(_error),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(c.t('jy', 'cancel')),
        ),
        if (_outdated)
          FilledButton(
            key: const ValueKey('data-use-reload'),
            onPressed: () => widget.h5.browser.openPage(
              './?lang=${widget.h5.language}&preview=notice-${DateTime.now().millisecondsSinceEpoch}',
            ),
            child: Text(c.t('jy', 'openLatest')),
          )
        else
          FilledButton(
            key: const ValueKey('data-use-agree'),
            onPressed: _saving ? null : () => unawaited(_accept()),
            child: Text(c.t('jy', 'consentAction')),
          ),
      ],
    );
  }
}
