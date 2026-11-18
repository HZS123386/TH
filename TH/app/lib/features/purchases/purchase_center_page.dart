import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

class PurchaseCenterPage extends StatelessWidget {
  const PurchaseCenterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.purchases, d.session]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageHeading(
            s.purchaseCenter,
            s.purchaseCenterIntro,
            icon: Icons.receipt_long_outlined,
          ),
          FateCard(
            gold: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FateEmblem(Icons.verified_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  d.session.displayName ?? s.guest,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  s.dataPurchaseBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!d.auth.signedIn)
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: Text(s.optionalLogin),
                  ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: d.purchases.canRestore
                      ? d.purchases.restore
                      : null,
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(
                    d.purchases.restoring ? s.restoreCheck : s.restore,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    d.purchases.restoring
                        ? s.restoreCheck
                        : d.purchases.restoreChecked
                        ? s.restoreChecked
                        : d.purchases.status != null
                        ? s.error
                        : !d.purchases.canRestore
                      ? s.restoreUnavailable
                        : s.faqPurchaseBody,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (d.purchases.needsVerification) ...[
                  const SizedBox(height: 16),
                  Text(s.purchaseVerifying),
                  FilledButton(
                    onPressed: d.purchases.busy
                        ? null
                        : d.purchases.retryVerification,
                    child: Text(s.retryPurchase),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          FateCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReadingParagraph(s.verifiedContent, s.verifiedContentIntro),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/reports'),
                  child: Text(s.reports),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.push('/support'),
            child: Text(s.supportTitle),
          ),
        ],
      ),
    );
  }
}
