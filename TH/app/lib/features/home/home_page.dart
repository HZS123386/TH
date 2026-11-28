import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../companion/guardian.dart';
import '../purchases/purchase_sheet.dart';
import 'daily_horoscope.dart';
import 'live_page.dart';
import 'reading_guide.dart';
import 'thai_calendar_card.dart';

export 'live_page.dart' show homeHeroImage;

class HomePage extends StatelessWidget {
  const HomePage({this.initialGuide = ReadingGuide.sirin, super.key});

  final ReadingGuide initialGuide;
  @override
  Widget build(BuildContext context) {
    final dependencies = DependencyScope.of(context),
        s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        dependencies.session,
        dependencies.companion,
      ]),
      builder: (context, _) => SingleChildScrollView(
        key: const PageStorageKey('home-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TodayReading(
              initialGuide: initialGuide,
              key: ValueKey(initialGuide),
            ),
            const SizedBox(height: 20),
            const DailyHoroscopeCard(),
            const SizedBox(height: 12),
            _ShortcutCard(
              icon: Icons.auto_awesome_outlined,
              label: s.luckyNumbers,
              subtitle: s.luckyNumberHint,
              onTap: () => context.push('/fortune/lucky-numbers'),
            ),
            const SizedBox(height: 16),
            FateCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              onTap: () => context.go('/action'),
              accent: const Color(0xFFA8BE96),
              child: Row(
                children: [
                  const Icon(Icons.eco_outlined, color: Color(0xFFA8BE96)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.myActions)),
                  const Icon(Icons.chevron_right, size: 18, color: mutedColor),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ThaiCalendarCard(
              repository: dependencies.thaiCalendar,
              footer: TextButton.icon(
                onPressed: () => context.push(
                  dependencies.session.profile == null ? '/birth' : '/chart',
                ),
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: Text(
                  dependencies.session.profile == null
                      ? s.start
                      : s.continueChart,
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const LiveTeasers(),
            const SizedBox(height: 18),
            if (dependencies.companion
                .conversation(dependencies.companion.selected)
                .isNotEmpty) ...[
              FateCard(
                padding: const EdgeInsets.all(16),
                onTap: () => openGuardian(context),
                child: Row(
                  children: [
                    GuardianAvatar(dependencies.companion.selected),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.continueConversation,
                            style: const TextStyle(
                              color: goldColor,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            dependencies.companion
                                    .conversation(
                                      dependencies.companion.selected,
                                    )
                                    .last['content']
                                as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            FateSectionTitle(s.chooseGuardian, subtitle: s.guardianSectionNote),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final guardian in Guardian.values)
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: FateEntrance(
                        delay: Duration(milliseconds: guardian.index * 40),
                        child: _GuardianCard(guardian),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FateSectionTitle(s.journey),
            FateCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  for (final entry in [
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
                    ListTile(
                      key: ValueKey('home-entry-${entry.$4}'),
                      leading: Icon(entry.$3, color: goldColor, size: 22),
                      title: Text(
                        entry.$1,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        entry.$2,
                        style: const TextStyle(fontSize: 11, color: mutedColor),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: mutedColor,
                      ),
                      onTap: () => entry.$4 == 'purchase'
                          ? showPurchaseSheet(context)
                          : context.push(entry.$4),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                s.aiCompanionNotice,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: mutedColor),
              ),
            ),
            if (dependencies.session.offline)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    Text(
                      s.connection,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: dependencies.session.loading
                          ? null
                          : dependencies.session.initialize,
                      child: Text(s.serviceRetry),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayReading extends StatefulWidget {
  const _TodayReading({required this.initialGuide, super.key});
  final ReadingGuide initialGuide;

  @override
  State<_TodayReading> createState() => _TodayReadingState();
}

class _TodayReadingState extends State<_TodayReading> {
  late ReadingGuide _selected = widget.initialGuide;

  void _select(ReadingGuide guide) {
    if (guide == _selected) return;
    FateMotion.selectionFeedback();
    setState(() => _selected = guide);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final hasBirth = DependencyScope.of(context).session.profile != null;
    final duration = FateMotion.duration(context, FateMotion.change);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: goldColor),
              ),
              const SizedBox(height: 5),
              Text(
                s.todayQuestion,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final guide in ReadingGuide.values)
              Expanded(
                child: Semantics(
                  selected: guide == _selected,
                  child: InkWell(
                    onTap: () => _select(guide),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Column(
                        children: [
                          Text(
                            guide.method(s),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: guide == _selected ? inkColor : mutedColor,
                              fontSize: 12,
                              fontWeight: guide == _selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            guide.tradition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 7,
                              color: mutedColor,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 7),
                          AnimatedContainer(
                            duration: duration,
                            width: guide == _selected ? 33 : 0,
                            height: 2,
                            decoration: BoxDecoration(
                              color: goldColor,
                              borderRadius: BorderRadius.circular(2),
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
        const Divider(height: 1, color: lineColor),
        const SizedBox(height: 5),
        SizedBox(
          height: 252,
          child: LayoutBuilder(
            builder: (context, constraints) => OverflowBox(
              minWidth: constraints.maxWidth + 40,
              maxWidth: constraints.maxWidth + 40,
              child: GuideCarousel(selected: _selected, onSelect: _select),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final guide in ReadingGuide.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: AnimatedContainer(
                  duration: duration,
                  width: guide == _selected ? 22 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: guide == _selected
                        ? goldColor
                        : mutedColor.withValues(alpha: .48),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 26,
          child: FateEntrance(
            key: ValueKey(_selected),
            child: Text(
              _selected.hint(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: mutedColor,
                height: 2,
              ),
            ),
          ),
        ),
        FilledButton(
          key: const ValueKey('start-selected-reading'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE3C696),
            minimumSize: const Size.fromHeight(45),
          ),
          onPressed: () => _selected.start(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _selected.startLabel(s, hasBirth),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 17),
            ],
          ),
        ),
        if (_selected == ReadingGuide.sirin)
          Center(
            child: TextButton(
              onPressed: () => context.push('/chart?example=1'),
              child: Text(s.homeChartExample),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ShortcutCard(
                icon: Icons.chat_outlined,
                label: s.textReading,
                subtitle: s.textReadingNote,
                onTap: () => _selected.openChat(context),
              ),
            ),
            if (_selected != ReadingGuide.mira) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _ShortcutCard(
                  icon: Icons.style_outlined,
                  label: s.tarotDraw,
                  subtitle: s.tarot,
                  onTap: () => ReadingGuide.mira.start(context),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FateCard(
    onTap: onTap,
    radius: 12,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
    child: Row(
      children: [
        Icon(icon, color: goldColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: mutedColor, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuardianCard extends StatelessWidget {
  const _GuardianCard(this.guardian);
  final Guardian guardian;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${guardian.title(s)} · ${s.startConversation}',
      excludeSemantics: true,
      onTap: () => openGuardian(context, guardian: guardian),
      child: FateCard(
        key: ValueKey('guardian-talk-${guardian.name}'),
        padding: EdgeInsets.zero,
        accent: guardian.color,
        onTap: () => openGuardian(context, guardian: guardian),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(100),
                  bottom: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 1.08,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      HeroMode(
                        enabled: !FateMotion.reduced(context),
                        child: Hero(
                          tag: guardian.portraitTag,
                          transitionOnUserGestures: true,
                          child: GuardianPortrait(
                            guardian,
                            alignment: const Alignment(0, -.7),
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, panelColor],
                            stops: [.72, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: canvasColor.withValues(alpha: .55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            guardian.icon,
                            color: guardian.color,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guardian.title(s),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guardian.note(s),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: guardian.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.startConversation,
                          style: const TextStyle(
                            fontSize: 11,
                            color: mutedColor,
                          ),
                        ),
                      ),
                      Icon(Icons.north_east, size: 14, color: guardian.color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
