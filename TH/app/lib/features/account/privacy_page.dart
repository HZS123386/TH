import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/storage/session_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../chart/chart_view_model.dart';
import 'support_page.dart';

Future<bool> requestCompanionConsent(BuildContext context) async {
  final d = DependencyScope.of(context), s = AppLocalizations.of(context);
  if (d.session.companionConsent) return true;
  final owner = d.session.owner;
  final provider = d.session.capabilities.companionProvider;
  final recipients = d.session.capabilities.companionRecipientLabel;
  if (provider == null || !d.auth.hasSession) return false;
  final accepted = await showDialog<bool>(
    context: context,
    animationStyle: FateMotion.dialog(context),
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.auto_awesome_outlined, color: goldColor),
      title: Text(s.aiPermission),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.aiPermissionBody(recipients)),
          TextButton(
            onPressed: () => context.push('/privacy'),
            child: Text(s.privacyCenter),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.decline),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.aiAllow),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return false;
  try {
    await d.session.allowCompanion(owner, provider, recipients: recipients);
    return d.session.owner == owner && d.session.companionConsent;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.error)));
    }
    return false;
  }
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _busy = false;

  Future<void> _action(
    String title,
    String body,
    Future<void> Function() run, {
    String? success,
  }) async {
    final s = AppLocalizations.of(context);
    final session = DependencyScope.of(context).session;
    final owner = session.owner;
    final accepted = await showDialog<bool>(
      context: context,
      animationStyle: FateMotion.dialog(context),
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(title),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || owner != session.owner) return;
    setState(() => _busy = true);
    try {
      await run();
      if (mounted && success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.error)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.session, d.companion]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageHeading(
            s.privacyCenter,
            s.privacyIntro,
            icon: Icons.shield_outlined,
          ),
          FateCard(
            gold: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FateEmblem(Icons.verified_user_outlined, size: 52),
                const SizedBox(height: 16),
                Text(
                  d.session.companionConsent ? s.aiEnabled : s.aiPaused,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  s.dataChatBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (d.session.companionConsent) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _action(
                            s.aiRevoke,
                            s.dataControlBody,
                            d.session.revokeCompanion,
                            success: s.aiRevoked,
                          ),
                    child: Text(s.aiRevoke),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final entry in [
            (s.dataProfileTitle, s.dataProfileBody),
            (s.dataPurchaseTitle, s.dataPurchaseBody),
            (s.dataControlTitle, s.dataControlBody),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FateCard(child: ReadingParagraph(entry.$1, entry.$2)),
            ),
          FateCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.session.profile != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _action(
                            s.clearBirth,
                            s.clearConfirm,
                            d.session.clearBirth,
                          ),
                    child: Text(s.clearBirth),
                  ),
                if (d.auth.hasSession)
                  TextButton(
                    onPressed:
                        _busy || d.companion.sending || d.companion.loading
                        ? null
                        : () => _action(
                            s.clearHistory,
                            s.clearHistoryBody,
                            d.companion.clearHistory,
                            success: s.clearHistoryDone,
                          ),
                    child: Text(s.clearHistory),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _action(
                          s.clearPrototypeRecords,
                          s.recordOnDevice,
                          () async {
                            final owner = d.session.owner;
                            await d.actions.clear(owner);
                            await d.session.drafts.remove(
                              owner,
                              LocalDraftStore.guideConversations,
                            );
                          },
                        ),
                  child: Text(s.clearPrototypeRecords),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_remove_outlined),
                  title: Text(s.deleteAccount),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => context.push('/delete-account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (d.accountServices.privacyUrl != null)
            OutlinedButton(
              onPressed: () =>
                  openServiceLink(context, d.accountServices.privacyUrl!),
              child: Text(s.privacyPolicy),
            )
          else
            Text(
              s.policyUnavailable,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          TextButton(
            onPressed: () => context.push('/support'),
            child: Text(s.supportTitle),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _acknowledged = false, _busy = false;
  String? _error;
  final _requestKey = newRequestKey();

  Future<void> _delete() async {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    final owner = d.session.owner;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: FateMotion.dialog(context),
      builder: (context) => AlertDialog(
        title: Text(s.deleteNow),
        content: Text(s.deleteAccountBody),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.deleteNow),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cleaned = await d.accountServices.deleteAccount(
        expectedOwner: owner,
        requestKey: _requestKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleaned ? s.deleteSuccess : s.deleteCleanup)),
        );
        context.go('/fortune');
      }
    } catch (_) {
      if (mounted) setState(() => _error = s.deleteFailure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: d.session,
      builder: (context, _) {
        final available =
            d.session.capabilities.accountDeletion && d.auth.hasSession;
        return PopScope(
          canPop: !_busy,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PageHeading(
                s.deleteAccount,
                s.privacyIntro,
                icon: Icons.person_remove_outlined,
              ),
              FateCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.session.displayName ?? s.guest,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    Text(s.deleteAccountBody),
                    const SizedBox(height: 16),
                    if (!available)
                      Text(
                        s.deleteUnavailable,
                        style: const TextStyle(color: goldColor),
                      ),
                    if (available)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(s.deleteAcknowledge),
                        value: _acknowledged,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _acknowledged = value == true),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: available && _acknowledged && !_busy
                          ? _delete
                          : null,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(s.deleteNow),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFFACB4)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _busy ? null : () => context.push('/support'),
                child: Text(s.supportTitle),
              ),
            ],
          ),
        );
      },
    );
  }
}
