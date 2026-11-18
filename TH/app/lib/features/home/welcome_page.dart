import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../reports/report_recovery_sheet.dart';
import 'reading_guide.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  static const seenKey = 'fate.app-guide-seen';

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  ReadingGuide _guide = ReadingGuide.sirin;

  Future<void> _start() async {
    final preferences = DependencyScope.of(context).session.drafts.preferences;
    await preferences.setBool(WelcomePage.seenKey, true);
    if (mounted) context.go('/fortune?guide=${_guide.name}');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return ColoredBox(
      color: const Color(0xFF0B0715),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            body: SafeArea(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.38),
                    radius: .85,
                    colors: [Color(0xFF261A34), Color(0xFF130D1F)],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 27, 18, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 47
                            ? constraints.maxHeight - 47
                            : 0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset(
                            'assets/images/fate-brand-gold.png',
                            height: 25,
                            semanticLabel: 'FATE',
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'YOUR DESTINY, YOUR STORY',
                            style: TextStyle(
                              fontSize: 9,
                              color: mutedColor,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FateEntrance(
                            child: GuideCarousel(
                              selected: _guide,
                              showDetails: false,
                              onSelect: (guide) =>
                                  setState(() => _guide = guide),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.guideWelcomeLabel,
                            style: const TextStyle(
                              color: goldColor,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.guideWelcomeTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 34,
                              color: Color(0xFFF5E3BD),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.guideWelcomeNote,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 23, 18, 0),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE3C696),
                                minimumSize: const Size.fromHeight(63),
                              ),
                              onPressed: _start,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _EntryLabel(
                                      s.newVisitor,
                                      s.newVisitorNote,
                                      gold: true,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward, size: 17),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(63),
                              ),
                              onPressed: () => showReportRecovery(context),
                              child: Row(
                                children: [
                                  const Icon(Icons.article_outlined, size: 19),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _EntryLabel(
                                      s.returningVisitor,
                                      s.returningVisitorNote,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward, size: 17),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${s.thaiGuide} · ${s.sevenGuide} · ${s.tarotGuide}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: mutedColor,
                            ),
                          ),
                          Text(
                            s.aiCompanionNotice,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryLabel extends StatelessWidget {
  const _EntryLabel(this.title, this.note, {this.gold = false});
  final String title, note;
  final bool gold;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(
        note,
        style: TextStyle(
          fontSize: 10,
          color: gold ? const Color(0xFF4E3A2D) : mutedColor,
        ),
      ),
    ],
  );
}
