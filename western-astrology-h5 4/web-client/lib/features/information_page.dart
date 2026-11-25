import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';
import '../ui/site_header.dart';
import 'privacy_policy.dart';
import 'support_content.dart';

class InformationPage extends StatefulWidget {
  const InformationPage({this.support = false, this.purchasePolicy, super.key});
  final bool support;
  final PurchasePolicy? purchasePolicy;
  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  Json? _content;
  String? _language;
  Object? _error;
  int _revision = 0;
  bool _recordedPage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recordedPage) {
      _recordedPage = true;
      H5Scope.of(context).trackActivity(widget.support ? 'support' : 'privacy');
    }
    final language = H5Scope.of(context).language;
    if (_language != language) {
      _language = language;
      unawaited(_load(language));
    }
  }

  @override
  void didUpdateWidget(InformationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.support != widget.support) {
      unawaited(_load(H5Scope.of(context).language));
    }
  }

  Future<void> _load(String language) async {
    final h5 = H5Scope.of(context), bundle = DefaultAssetBundle.of(context);
    final revision = ++_revision,
        directory = widget.support ? 'support' : 'privacy';
    setState(() {
      _content = null;
      _error = null;
    });
    try {
      final index = object(
        jsonDecode(
          await bundle.loadString('assets/$directory/index.json', cache: false),
        ),
      );
      final source = text(object(index['languages'])[language]);
      if (!RegExp(r'^[a-z]{2}$').hasMatch(source)) {
        throw const FormatException('Unknown information language');
      }
      final data = object(
        jsonDecode(
          await bundle.loadString(
            'assets/$directory/$source.json',
            cache: false,
          ),
        ),
      );
      final controller = object(
        jsonDecode(
          await bundle.loadString(
            'assets/privacy/controller.json',
            cache: false,
          ),
        ),
      );
      final localized = object(object(controller['localizations'])[language]);
      if (text(localized['controller_name']).isEmpty ||
          text(localized['controller_address']).isEmpty) {
        throw const FormatException('Missing operator translation');
      }
      data['controller'] = {
        'contact_email': controller['contact_email'],
        'effective_date': controller['effective_date'],
        ...localized,
      };
      if (objects(data['sections']).isEmpty) {
        throw const FormatException('Incomplete information page');
      }
      // Legal/help content remains readable without a working report API or account.
      await h5.prepareText(jsonEncode(data), language: language);
      if (mounted && revision == _revision) setState(() => _content = data);
    } catch (error) {
      if (mounted && revision == _revision) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context), c = h5.copy;
    final policy = widget.purchasePolicy;
    return SingleChildScrollView(
      key: ValueKey((widget.support, policy)),
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
                    policy == null
                        ? c.t('jy', widget.support ? 'supportTitle' : 'privacy')
                        : c.t('purchasePolicies', policy.name),
                    style: const TextStyle(
                      fontSize: 27,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_content == null)
                    if (_error == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      Text(c.t('ui', 'network')),
                      TextButton.icon(
                        onPressed: () => unawaited(_load(h5.language)),
                        icon: const Icon(Icons.refresh),
                        label: Text(c.t('jy', 'regionRetry')),
                      ),
                    ]
                  else if (widget.support)
                    SupportContent(content: _content!, purchasePolicy: policy)
                  else
                    PrivacyPolicy(policy: _content!),
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
  h5.trackActivity('consent');
  final accepted =
      await showDialog<bool>(
        context: context,
        builder: (_) => _DataUseDialog(h5: h5),
      ) ??
      false;
  if (context.mounted) {
    h5.trackActivity(
      'birth_form',
      accepted ? 'consent_accept' : 'consent_cancel',
    );
  }
  return accepted;
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
