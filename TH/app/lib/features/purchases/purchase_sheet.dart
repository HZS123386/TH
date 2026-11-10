import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

Future<void> showPurchaseSheet(
  BuildContext context, {
  String? reportId,
  VoidCallback? previewExample,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  backgroundColor: panelColor,
  constraints: const BoxConstraints(maxWidth: 430),
  builder: (_) =>
      _PurchaseSheet(reportId: reportId, previewExample: previewExample),
);

class _PurchaseSheet extends StatefulWidget {
  const _PurchaseSheet({this.reportId, this.previewExample});
  final String? reportId;
  final VoidCallback? previewExample;
  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  bool restored = false, initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final d = DependencyScope.of(context);
    if (widget.reportId != null &&
        widget.previewExample == null &&
        d.session.capabilities.applePurchase &&
        d.auth.signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) d.purchases.prepare(widget.reportId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: d.purchases,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.offerTitle,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: s.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FateCard(
              gold: true,
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    size: 35,
                    color: goldColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FATE · ${s.fullReport}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.offerText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (final feature in [
              s.offerFeature1,
              s.offerFeature2,
              s.offerFeature3,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 19, color: goldColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                d.purchases.price ?? s.pricePending,
                style: const TextStyle(color: goldColor, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  widget.previewExample == null &&
                      widget.reportId != null &&
                      d.purchases.canPurchase
                  ? d.purchases.buy
                  : null,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(d.purchases.busy ? s.purchaseVerifying : s.appleBuy),
            ),
            const SizedBox(height: 12),
            Text(
              kIsWeb ? s.purchasePreview : s.nativeSetup,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!d.auth.signedIn)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  s.loginRequired,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Center(
              child: TextButton(
                onPressed: () async {
                  setState(() => restored = true);
                  await d.purchases.restore();
                },
                child: Text(s.restore),
              ),
            ),
            if (restored)
              Text(
                kIsWeb
                    ? s.restoreNote
                    : d.purchases.status == null
                    ? s.purchaseVerifying
                    : s.serviceSetup,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (d.purchases.status != null && !restored)
              Text(
                s.serviceSetup,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (d.purchases.needsVerification)
              OutlinedButton(
                onPressed: d.purchases.busy
                    ? null
                    : d.purchases.retryVerification,
                child: Text(s.retryPurchase),
              ),
            if (widget.previewExample != null) ...[
              const Divider(),
              OutlinedButton(
                onPressed: () {
                  widget.previewExample!();
                  Navigator.pop(context);
                },
                child: Text('${s.previewFull}  →'),
              ),
              const SizedBox(height: 10),
              Text(
                s.previewFullNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
