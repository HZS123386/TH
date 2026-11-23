import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/storage/session_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../actions/action_page.dart' show actionColor;
import '../companion/guardian.dart';
import '../home/reading_guide.dart';
import '../reports/report_recovery_sheet.dart';
import '../shop/shop_page.dart';

const _languages = [
  ('th', 'ภาษาไทย'),
  ('en', 'English'),
  ('zh', '中文'),
  ('vi', 'Tiếng Việt'),
];

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    if (d.session.thaiAstrologyOnly) {
      return ListenableBuilder(
        listenable: d.session,
        builder: (context, _) => const _ThaiSettings(),
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([d.session, d.companion]),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR SPACE',
              style: TextStyle(
                color: goldColor,
                letterSpacing: 1.8,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 7),
            PageHeading(s.mySpace, s.mySpaceIntro),
            FateCard(
              gold: true,
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0x2DE4BC78),
                    foregroundColor: goldColor,
                    child: d.session.displayName == null
                        ? const Icon(Icons.person_outline)
                        : Text(
                            d.session.displayName!.characters.first
                                .toUpperCase(),
                            style: const TextStyle(fontSize: 20),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.session.displayName ??
                              (d.auth.hasH5Reports ? s.h5Account : s.guest),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 19),
                        ),
                        Text(
                          d.auth.signedIn ? s.signedIn : s.guestReading,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/birth'),
                    child: Text(
                      d.session.profile != null ? s.editBirth : s.birth,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _AccountShortcut(
                      Icons.article_outlined,
                      s.recoverReports,
                      () => showReportRecovery(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AccountShortcut(
                      Icons.eco_outlined,
                      s.actionsAndReviews,
                      () => context.go('/action'),
                      color: actionColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AccountShortcut(
                      Icons.receipt_long_outlined,
                      s.shopOrders,
                      () => showShopOrders(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            const _ReadingLinks(),
            TextButton.icon(
              key: const ValueKey('profile-reading-history'),
              onPressed: () => context.push('/chart/readings?from=profile'),
              icon: const Icon(Icons.history),
              label: Text(s.savedReadings),
            ),
            const SizedBox(height: 17),
            FateCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Column(
                children: [
                  if (!d.auth.signedIn)
                    ListTile(
                      leading: const Icon(Icons.login, color: goldColor),
                      title: Text(s.optionalLogin),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/login'),
                    ),
                  ListTile(
                    leading: const Icon(
                      Icons.favorite_border,
                      color: goldColor,
                    ),
                    title: Text(s.bondNav),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile'),
                  ),
                  if (d.purchases.storeEnabled)
                    ListTile(
                      leading: const Icon(
                        Icons.workspace_premium_outlined,
                        color: goldColor,
                      ),
                      title: Text(s.purchaseCenter),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/purchases'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FateCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.language, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(
                    s.languageHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final row in _languages)
                        ChoiceChip(
                          label: Text(row.$2),
                          selected: d.session.locale.languageCode == row.$1,
                          onSelected: (_) => d.session.changeLocale(row.$1),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FateCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.privacy, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(
                    s.privacyIntro,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/privacy'),
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(s.privacyCenter),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/support'),
                    icon: const Icon(Icons.help_outline),
                    label: Text(s.supportTitle),
                  ),
                ],
              ),
            ),
            if (d.auth.signedIn) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await d.auth.logout();
                    if (context.mounted) context.go('/fortune');
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(s.error)));
                    }
                  }
                },
                child: Text(s.logout),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThaiSettings extends StatelessWidget {
  const _ThaiSettings();

  Future<void> _chooseLanguage(BuildContext context) async {
    final s = AppLocalizations.of(context);
    final session = DependencyScope.of(context).session;
    final language = await showDialog<String>(
      context: context,
      animationStyle: FateMotion.dialog(context),
      builder: (dialogContext) => SimpleDialog(
        title: Text(s.language),
        children: [
          for (final (code, name) in _languages)
            ListTile(
              title: Text(name),
              selected: session.locale.languageCode == code,
              selectedColor: goldColor,
              trailing: session.locale.languageCode == code
                  ? const Icon(Icons.check, color: goldColor)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(code),
            ),
        ],
      ),
    );
    if (language != null && context.mounted) {
      await session.changeLocale(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final session = DependencyScope.of(context).session;
    final theme = Theme.of(context);
    final language = _languages
        .firstWhere((item) => item.$1 == session.locale.languageCode)
        .$2;
    return ListTileTheme(
      iconColor: goldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.mine, style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            _SettingsGroup(
              title: s.settingsBirthChart,
              children: [
                _link(
                  icon: Icons.event_outlined,
                  title: s.birth,
                  detail: session.profile == null
                      ? s.settingsBirthEmpty
                      : s.settingsBirthSaved,
                  onTap: () => context.push('/birth'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsGroup(
              title: s.settingsPreferences,
              children: [
                _link(
                  icon: Icons.language_outlined,
                  title: s.language,
                  detail: language,
                  onTap: () => _chooseLanguage(context),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.motion_photos_off_outlined),
                  title: Text(s.settingsReduceMotion),
                  subtitle: Text(s.settingsReduceMotionHint),
                  value: session.reduceMotion,
                  onChanged: (value) async {
                    try {
                      await session.changeReduceMotion(value);
                    } on Exception {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(s.error)));
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsGroup(
              title: s.settingsPrivacySupport,
              children: [
                _link(
                  icon: Icons.shield_outlined,
                  title: s.privacyCenter,
                  onTap: () => context.push('/privacy'),
                ),
                _link(
                  icon: Icons.help_outline,
                  title: s.supportTitle,
                  onTap: () => context.push('/support'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ListTile _link({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? detail,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: detail == null ? null : Text(detail),
    trailing: const Icon(Icons.chevron_right, color: mutedColor),
    onTap: onTap,
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: goldColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      FateCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, indent: 52, endIndent: 16),
              children[index],
            ],
          ],
        ),
      ),
    ],
  );
}

class _AccountShortcut extends StatelessWidget {
  const _AccountShortcut(
    this.icon,
    this.label,
    this.open, {
    this.color = goldColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback open;
  final Color color;

  @override
  Widget build(BuildContext context) => FateCard(
    radius: 15,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 15),
    onTap: open,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}

class _ReadingLinks extends StatelessWidget {
  const _ReadingLinks();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), d = DependencyScope.of(context);
    final last = d.session.drafts.read(
      d.session.owner,
      LocalDraftStore.guideConversations,
    )?['last'];
    final recentGuide = last is String ? ReadingGuide.fromName(last) : null;
    final guardian = d.companion.selected;
    final hasGuardianChat = d.companion.conversation(guardian).isNotEmpty;
    return FateCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recentGuide != null || hasGuardianChat)
            ListTile(
              title: Text(s.resumeCompanion),
              subtitle: Text(recentGuide?.displayName(s) ?? guardian.title(s)),
              trailing: const Icon(
                Icons.chevron_right,
                color: goldColor,
                size: 19,
              ),
              onTap: () => recentGuide != null
                  ? recentGuide.openChat(context)
                  : openGuardian(context),
            ),
          for (final guide in ReadingGuide.values) ...[
            if (guide.index > 0 || recentGuide != null || hasGuardianChat)
              const Divider(height: 1, indent: 12, endIndent: 12),
            ListTile(
              dense: true,
              title: Text(
                '${guide.displayName(s)} · ${guide.method(s)}',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.textReading,
                    style: const TextStyle(fontSize: 10, color: mutedColor),
                  ),
                  const Icon(Icons.chevron_right, color: goldColor, size: 18),
                ],
              ),
              onTap: () => guide.openChat(context),
            ),
          ],
          const Divider(height: 1, indent: 12, endIndent: 12),
          ListTile(
            title: Text(s.fortunePeriods, style: const TextStyle(fontSize: 13)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/divination'),
          ),
        ],
      ),
    );
  }
}
