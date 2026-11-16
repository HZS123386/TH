import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../companion/guardian.dart';
import 'daily_horoscope.dart';
import 'thai_calendar_card.dart';

class DivinationPage extends StatelessWidget {
  const DivinationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const PageStorageKey('divination-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            s.divinationTitle,
            s.divinationIntro,
            icon: Icons.auto_awesome_outlined,
          ),
          _ToolCard(
            image: 'assets/images/theme-tarot.jpg',
            title: s.dailyDraw,
            subtitle: s.dailyDrawNote,
            featured: true,
            onTap: () => context.push('/fortune/tarot'),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ToolCard(
                    image: 'assets/images/theme-lucky-numbers.jpg',
                    title: s.luckyNumbers,
                    subtitle: s.todayLuckyNumber,
                    onTap: () => context.push('/fortune/lucky-numbers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ToolCard(
                    title: s.weeklyEvents,
                    subtitle: s.weeklyNote,
                    onTap: () => openGuardian(
                      context,
                      reading: ReadingHandoff(
                        title: s.weeklyEvents,
                        text: '',
                        question: s.weeklyPrompt,
                        period: 'week',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const DailyHoroscopeCard(),
          const SizedBox(height: 24),
          FateCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.explore_outlined, color: goldColor),
                  title: Text(s.chart),
                  subtitle: Text(s.chartNote),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/chart'),
                ),
                const Divider(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.menu_book_outlined,
                    color: goldColor,
                  ),
                  title: Text(s.reports),
                  subtitle: Text(s.reportNote),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/reports'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ThaiCalendarCard(repository: d.thaiCalendar),
          const SizedBox(height: 18),
          Text(
            s.aiCompanionNotice,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
  });
  final String? image;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) => FateEntrance(
    child: FateCard(
      radius: featured ? 24 : 18,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: image == null
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3D2A54), panelColor],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.calendar_month_outlined,
                          size: 64,
                          color: Color(0x509C82C2),
                        ),
                      ),
                    ),
                  )
                : Image.asset(
                    image!,
                    fit: BoxFit.cover,
                    alignment: featured
                        ? const Alignment(0, -.3)
                        : const Alignment(0, -.7),
                    excludeFromSemantics: true,
                    cacheWidth: featured ? 800 : 400,
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: featured ? Alignment.centerLeft : Alignment.topCenter,
                  end: featured
                      ? Alignment.centerRight
                      : Alignment.bottomCenter,
                  colors: featured
                      ? const [
                          Color(0xF2130C24),
                          Color(0xA6130C24),
                          Color(0x10130C24),
                        ]
                      : const [
                          Color(0x50130C24),
                          Color(0xE6130C24),
                          Color(0xFF130C24),
                        ],
                  stops: featured ? const [0, .5, 1] : const [0, .65, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(featured ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FateEmblem(
                  featured ? Icons.auto_awesome_outlined : Icons.north_east,
                  size: featured ? 42 : 32,
                  color: goldColor,
                ),
                SizedBox(height: featured ? 24 : 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: featured ? 26 : 17,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: featured ? 155 : double.infinity,
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: Color(0xFFE0DAE3),
                    ),
                  ),
                ),
                if (featured) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context).tarot,
                          style: const TextStyle(
                            color: canvasColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Icon(
                          Icons.arrow_forward,
                          color: canvasColor,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
