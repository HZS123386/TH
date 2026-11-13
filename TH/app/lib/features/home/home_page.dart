import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../purchases/purchase_sheet.dart';
import 'daily_horoscope.dart';
import 'thai_calendar_card.dart';

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
            const _HomeHero(),
            const SizedBox(height: 14),
            ThaiCalendarCard(repository: dependencies.thaiCalendar),
            const SizedBox(height: 14),
            const DailyHoroscopeCard(),
            const SizedBox(height: 14),
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
                _IllustratedFeatureCard(
                  width: cardWidth,
                  image: 'assets/images/theme-tarot.jpg',
                  title: s.tarot,
                  subtitle: s.tarotDraw,
                  onTap: () => context.go('/fortune/tarot'),
                ),
                _IllustratedFeatureCard(
                  width: cardWidth,
                  image: 'assets/images/theme-lucky-numbers.jpg',
                  title: s.luckyNumbers,
                  subtitle: s.todayLuckyNumber,
                  onTap: () => context.go('/fortune/lucky-numbers'),
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

class _IllustratedFeatureCard extends StatelessWidget {
  const _IllustratedFeatureCard({
    required this.width,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double width;
  final String image, title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: FateCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    image,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [panelColor, Color(0x0020152F)],
                        stops: [0, .32],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.north_east, size: 16, color: goldColor),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final shape = BorderRadius.circular(22);

    return ClipRRect(
      borderRadius: shape,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: goldColor.withValues(alpha: .22)),
          borderRadius: shape,
        ),
        child: ColoredBox(
          color: const Color(0xFF1B112C),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              child: Stack(
                children: [
                  Positioned.fill(
                    left: constraints.maxWidth * .33,
                    child: const Image(
                      image: homeHeroImage,
                      fit: BoxFit.cover,
                      alignment: Alignment(.18, -.82),
                      excludeFromSemantics: true,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1B112C),
                            Color(0xF21B112C),
                            Color(0xA01B112C),
                            Color(0x001B112C),
                          ],
                          stops: [0, .32, .48, .74],
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
                          colors: [Color(0xA61B112C), Color(0x001B112C)],
                          stops: [0, .36],
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 232),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 19, 0, 17),
                      child: SizedBox(
                        width: constraints.maxWidth * .49,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.heroTitle,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.28,
                                fontWeight: FontWeight.w700,
                                color: inkColor,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              s.heroText,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.65,
                                color: mutedColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0x403C2A46),
                                border: Border.all(
                                  color: goldColor.withValues(alpha: .35),
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '✧  ${s.system}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: goldColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
