import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';
import 'privacy_policy.dart';
import 'support_content.dart';

class InformationPage extends StatefulWidget {
  const InformationPage({this.support = false, super.key});
  final bool support;
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
                    SupportContent(content: _content!)
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
