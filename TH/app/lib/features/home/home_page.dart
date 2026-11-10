import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../purchases/purchase_sheet.dart';

const homeHeroImage = AssetImage('assets/images/astrologer.webp');

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final dependencies = DependencyScope.of(context),
        s = AppLocalizations.of(context);
    final cardWidth =
        (MediaQuery.sizeOf(context).width.clamp(0.0, 430.0).toDouble() - 52) /
        2;
    return ListenableBuilder(
      listenable: dependencies.session,
      builder: (context, _) => SingleChildScrollView(
        key: const PageStorageKey('home-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 330),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    right: -20,
                    bottom: 0,
                    width: 290,
                    child: Image(
                      image: homeHeroImage,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            canvasColor,
                            canvasColor.withValues(alpha: .4),
                            Colors.transparent,
                          ],
                          stops: const [0, .55, 1],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [canvasColor, Colors.transparent],
                          stops: [0, .5],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✧  ${s.system}',
                          style: const TextStyle(
                            color: goldColor,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          s.heroTitle,
                          style: const TextStyle(
                            fontSize: 29,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 185,
                          child: Text(
                            s.heroText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: mutedColor,
                              height: 1.9,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: goldColor.withValues(alpha: .4),
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            '•  ${s.heroBadge}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: goldColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => context.go(
                dependencies.session.profile == null ? '/birth' : '/chart',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                backgroundColor: panelColor,
                shape: const StadiumBorder(),
              ),
              child: Row(
                children: [
                  const Icon(Icons.explore_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dependencies.session.profile == null
                          ? s.start
                          : s.continueChart,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              s.journey,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in [
                  (s.chart, s.chartNote, Icons.explore_outlined, '/chart'),
                  (
                    s.reports,
                    s.reportNote,
                    Icons.menu_book_outlined,
                    '/reports',
                  ),
                  (
                    s.fullReport,
                    s.fullNote,
                    Icons.workspace_premium_outlined,
                    'purchase',
                  ),
                  (
                    s.birth,
                    s.birthNote,
                    Icons.calendar_month_outlined,
                    '/birth',
                  ),
                ])
                  SizedBox(
                    width: cardWidth,
                    child: Material(
                      color: panelColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(color: lineColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => card.$4 == 'purchase'
                            ? showPurchaseSheet(context)
                            : context.go(card.$4),
                        child: Padding(
                          padding: const EdgeInsets.all(17),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(card.$3, color: goldColor, size: 25),
                              const SizedBox(height: 20),
                              Text(
                                card.$1,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card.$2,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: mutedColor,
                                  height: 1.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.north_east,
                                  size: 16,
                                  color: goldColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FateCard(
              gold: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✧  FATE',
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.homeReportTitle,
                    style: const TextStyle(fontSize: 21, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.homeReportText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/reports'),
                    child: Text('${s.viewReport}  →'),
                  ),
                ],
              ),
            ),
            if (dependencies.session.offline)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  s.connection,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
