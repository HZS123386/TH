import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../account/birth_page.dart';
import '../chart/thai_rasi_wheel.dart';

class ThaiHomePage extends StatelessWidget {
  const ThaiHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return BirthPage(
      header: FateCard(
        gold: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.thaiSampleChart,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Align(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 262),
                child: ThaiRasiWheel(
                  data: ThaiRasiData.example,
                  label: s.thaiSampleChart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
