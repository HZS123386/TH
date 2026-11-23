import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

Future<void> openServiceLink(
  BuildContext context,
  Uri uri, {
  bool appInformation = false,
}) async {
  final s = AppLocalizations.of(context);
  final target = appInformation && kIsWeb
      ? uri.replace(queryParameters: {...uri.queryParameters, 'from': 'app'})
      : uri;
  final mode = appInformation && !kIsWeb
      ? LaunchMode.inAppBrowserView
      : LaunchMode.externalApplication;
  try {
    if (await launchUrl(target, mode: mode)) return;
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

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  Future<String?>? _email;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _email ??= DependencyScope.of(context).accountServices.supportEmail();
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    final thaiOnly = d.session.thaiAstrologyOnly;
    final questions = thaiOnly
        ? [
            (s.thaiHelpChartQuestion, s.thaiHelpChartAnswer),
            (s.thaiHelpTimeQuestion, s.unknownTime),
            (s.thaiHelpCityQuestion, s.thaiHelpCityAnswer),
            (s.thaiHelpRetryQuestion, s.thaiHelpRetryAnswer),
            (s.thaiHelpDataQuestion, s.thaiHelpDataAnswer),
          ]
        : [
            (s.faqReportTitle, s.faqReportBody),
            (s.faqChatTitle, s.faqChatBody),
            if (d.purchases.storeEnabled)
              (s.faqPurchaseTitle, s.faqPurchaseBody),
          ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeading(
          s.supportTitle,
          thaiOnly ? s.thaiHelpIntro : s.supportIntro,
          icon: Icons.support_agent_rounded,
        ),
        FateCard(
          gold: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: FateEmblem(Icons.mail_outline, size: 52),
              ),
              const SizedBox(height: 16),
              Text(s.supportContact, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 12),
              FutureBuilder<String?>(
                future: _email,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  final email = snapshot.data;
                  if (email == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.hasError ? s.error : s.supportUnavailable,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () {
                            final email = d.accountServices.supportEmail();
                            setState(() {
                              _email = email;
                            });
                          },
                          child: Text(s.serviceRetry),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        email,
                        style: const TextStyle(color: goldColor),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => openServiceLink(
                          context,
                          Uri(
                            scheme: 'mailto',
                            path: email,
                            query:
                                'subject=${Uri.encodeComponent('FATE support')}',
                          ),
                        ),
                        child: Text(
                          thaiOnly ? s.supportOpenEmail : s.supportContact,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: email));
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(s.copied)));
                          }
                        },
                        child: Text(s.copyAddress),
                      ),
                    ],
                  );
                },
              ),
              if (thaiOnly) ...[
                const SizedBox(height: 8),
                Text(
                  s.thaiHelpContactBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (d.accountServices.supportUrl != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => openServiceLink(
                    context,
                    d.accountServices.supportUrl!,
                    appInformation: thaiOnly,
                  ),
                  child: Text(s.supportWebsite),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (thaiOnly) ...[
          Text(
            s.supportFaqHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
        ],
        for (final entry in questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FateCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                title: Text(entry.$1),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  Text(entry.$2, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        if (thaiOnly)
          TextButton(
            onPressed: () => context.push('/privacy'),
            child: Text(s.privacyCenter),
          )
        else ...[
          const SizedBox(height: 12),
          FateCard(child: ReadingParagraph(s.termsTitle, s.termsBody)),
        ],
        if (d.accountServices.termsUrl != null)
          TextButton(
            onPressed: () =>
                openServiceLink(context, d.accountServices.termsUrl!),
            child: Text(s.termsTitle),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'FATE',
            applicationIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/images/fate-brand-gold.png',
                height: 24,
              ),
            ),
          ),
          icon: const Icon(Icons.code_rounded),
          label: Text(s.licenses),
        ),
      ],
    );
  }
}
