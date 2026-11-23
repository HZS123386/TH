import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

enum Guardian {
  love,
  career,
  wealth,
  wellbeing;

  static Guardian fromId(String? value) =>
      values.where((item) => item.name == value).firstOrNull ?? love;

  String get image => 'assets/images/guardian-$name.png';
  String get portraitTag => 'guardian-portrait-$name';
  Color get color => switch (this) {
    love => const Color(0xFFE4A0BB),
    career => const Color(0xFF9CB8E8),
    wealth => const Color(0xFFF0CB83),
    wellbeing => const Color(0xFFABD2B6),
  };
  IconData get icon => switch (this) {
    love => Icons.favorite_border,
    career => Icons.north_east,
    wealth => Icons.wb_sunny_outlined,
    wellbeing => Icons.spa_outlined,
  };
  String title(AppLocalizations s) => switch (this) {
    love => s.loveGuardian,
    career => s.careerGuardian,
    wealth => s.wealthGuardian,
    wellbeing => s.wellbeingGuardian,
  };
  String note(AppLocalizations s) => switch (this) {
    love => s.loveGuardianNote,
    career => s.careerGuardianNote,
    wealth => s.wealthGuardianNote,
    wellbeing => s.wellbeingGuardianNote,
  };
  String prompt(AppLocalizations s) => switch (this) {
    love => s.lovePrompt,
    career => s.careerPrompt,
    wealth => s.wealthPrompt,
    wellbeing => s.wellbeingPrompt,
  };
}

class ReadingHandoff {
  const ReadingHandoff({
    required this.title,
    required this.text,
    this.question,
    this.period,
    this.owner,
  });
  final String title, text;
  final String? question, period, owner;
}

void openGuardian(
  BuildContext context, {
  Guardian? guardian,
  ReadingHandoff? reading,
}) {
  final model = DependencyScope.of(context).companion;
  final selected = guardian ?? model.selected;
  model.select(selected);
  context.push('/companion/${selected.name}', extra: reading);
}

class GuardianAvatar extends StatelessWidget {
  const GuardianAvatar(
    this.guardian, {
    this.size = 48,
    this.hero = false,
    super.key,
  });
  final Guardian guardian;
  final double size;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final portrait = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: guardian.color.withValues(alpha: .7)),
      ),
      child: ClipOval(
        child: Image.asset(
          guardian.image,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -.65),
          excludeFromSemantics: true,
          cacheWidth: (size * 3).round(),
        ),
      ),
    );
    return hero
        ? HeroMode(
            enabled: !FateMotion.reduced(context),
            child: Hero(
              tag: guardian.portraitTag,
              transitionOnUserGestures: true,
              child: portrait,
            ),
          )
        : portrait;
  }
}
