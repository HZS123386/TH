import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../purchases/purchase_sheet.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: d.session,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(s.mine, s.accountText),
            FateCard(
              gold: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_outline, size: 36, color: goldColor),
                  const SizedBox(height: 16),
                  Text(
                    d.session.displayName ?? s.guest,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.auth.signedIn ? s.signedIn : s.guestReading,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => context.go('/birth'),
                    child: Text(
                      d.session.profile != null ? s.editBirth : s.start,
                    ),
                  ),
                  if (!d.auth.signedIn)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(s.optionalLogin),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FateCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_month_outlined,
                      color: goldColor,
                    ),
                    title: Text(s.birth),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/birth'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.menu_book_outlined,
                      color: goldColor,
                    ),
                    title: Text(s.reports),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/reports'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.workspace_premium_outlined,
                      color: goldColor,
                    ),
                    title: Text(s.purchaseHistory),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showPurchaseSheet(context),
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
                      for (final row in const [
                        ('th', 'ภาษาไทย'),
                        ('en', 'English'),
                        ('zh', '中文'),
                        ('vi', 'Tiếng Việt'),
                      ])
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
                    s.privacyText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (d.session.profile != null)
                    TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Text(s.clearConfirm),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(s.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(s.clearBirth),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) await d.session.clearBirth();
                      },
                      child: Text(s.clearBirth),
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
