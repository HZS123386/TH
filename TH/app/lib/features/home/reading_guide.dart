import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/asset_tile.dart';
import '../../ui/theme.dart';

const sirinPortrait = AssetImage('assets/images/guide-sirin.png');
const guideDuo = AssetImage('assets/images/guide-duo.png');

enum ReadingGuide {
  sirin('THAI ASTROLOGY', 'FATE-THAI-001', Color(0xFFD2B284)),
  arun('SEVEN CHARACTERS', 'FATE-SEVEN-001', Color(0xFFABBE9D)),
  mira('TAROT READING', 'FATE-TAROT-001', Color(0xFFBEA4D2));

  const ReadingGuide(this.tradition, this.sampleCode, this.color);
  final String tradition, sampleCode;
  final Color color;

  static ReadingGuide fromName(String? name) =>
      values.where((guide) => guide.name == name).firstOrNull ?? sirin;

  String displayName(AppLocalizations s) => switch (this) {
    sirin => s.sirin,
    arun => s.arun,
    mira => s.mira,
  };

  String method(AppLocalizations s) => switch (this) {
    sirin => s.thaiGuide,
    arun => s.sevenGuide,
    mira => s.tarotGuide,
  };

  String focus(AppLocalizations s) => switch (this) {
    sirin => s.sirinFocus,
    arun => s.arunFocus,
    mira => s.miraFocus,
  };

  String hint(AppLocalizations s) => switch (this) {
    sirin => s.sirinHint,
    arun => s.arunHint,
    mira => s.miraHint,
  };

  String sampleQuestion(AppLocalizations s) => switch (this) {
    sirin => s.readingSampleQuestion,
    arun => s.readingSampleLife,
    mira => s.readingSampleLove,
  };

  String startLabel(AppLocalizations s, bool hasBirth) => switch (this) {
    sirin => hasBirth ? s.viewThaiGuide : s.startThaiGuide,
    arun => s.startSevenGuide,
    mira => s.startTarotGuide,
  };

  void openChat(
    BuildContext context, {
    bool voice = false,
    bool sample = false,
  }) {
    final options = [if (voice) 'voice=1', if (sample) 'sample=1'].join('&');
    context.push('/reading/$name${options.isEmpty ? '' : '?$options'}');
  }

  void start(BuildContext context) {
    switch (this) {
      case sirin:
        final hasBirth = DependencyScope.of(context).session.profile != null;
        context.push(hasBirth ? '/chart/thai' : '/birth?reading=thai');
      case arun:
        final s = AppLocalizations.of(context);
        showDialog<void>(
          context: context,
          animationStyle: FateMotion.dialog(context),
          builder: (sheet) => AlertDialog(
            title: Text(s.sevenGuide),
            content: Text(s.sevenPreviewNote),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: Text(s.close),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  openChat(context, sample: true);
                },
                child: Text(s.textChat),
              ),
            ],
          ),
        );
      case mira:
        context.push('/fortune/tarot');
    }
  }
}

class GuidePortrait extends StatelessWidget {
  const GuidePortrait(
    this.guide, {
    this.alignment = Alignment.topCenter,
    super.key,
  });
  final ReadingGuide guide;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => guide == ReadingGuide.sirin
      ? Image(
          image: sirinPortrait,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: alignment,
          excludeFromSemantics: true,
        )
      : AssetTile(
          guideDuo.assetName,
          column: guide == ReadingGuide.arun ? 0 : 1,
          cellRatio: .75,
          alignment: alignment,
        );
}

class GuideCarousel extends StatelessWidget {
  const GuideCarousel({
    required this.selected,
    required this.onSelect,
    this.showDetails = true,
    super.key,
  });
  final ReadingGuide selected;
  final ValueChanged<ReadingGuide> onSelect;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final duration = FateMotion.duration(context, FateMotion.page);
    final guides = ReadingGuide.values;
    final previous = guides[(selected.index - 1) % guides.length];
    final next = guides[(selected.index + 1) % guides.length];
    final height = showDetails ? 252.0 : 270.0;
    return GestureDetector(
      onHorizontalDragEnd: (detail) {
        final velocity = detail.primaryVelocity ?? 0;
        if (velocity.abs() > 40) onSelect(velocity < 0 ? next : previous);
      },
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -.4),
                      radius: .67,
                      colors: [Color(0xFF36254B), Color(0x00170E26)],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Icon(Icons.auto_awesome, size: 12, color: goldColor),
              ),
              for (final guide in [previous, next, selected])
                AnimatedPositioned(
                  key: ValueKey(guide),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  top: guide == selected ? 12 : 30,
                  bottom: guide == selected ? 2 : 10,
                  width: box.maxWidth * (guide == selected ? .55 : .41),
                  left:
                      box.maxWidth *
                      (guide == selected
                          ? .225
                          : guide == previous
                          ? -.015
                          : .605),
                  child: AnimatedRotation(
                    duration: duration,
                    turns: guide == selected
                        ? 0
                        : guide == previous
                        ? -.025
                        : .025,
                    child: _GuideCard(
                      guide: guide,
                      current: guide == selected,
                      showDetails: showDetails,
                      onTap: guide == selected ? null : () => onSelect(guide),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.guide,
    required this.current,
    required this.showDetails,
    this.onTap,
  });
  final ReadingGuide guide;
  final bool current, showDetails;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final radius = const BorderRadius.vertical(
      top: Radius.circular(110),
      bottom: Radius.circular(23),
    );
    return Semantics(
      label: '${guide.displayName(s)} · ${guide.method(s)}',
      selected: current,
      button: onTap != null,
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: panelColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: guide.color.withValues(alpha: current ? .54 : .28),
          ),
          borderRadius: radius,
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GuidePortrait(guide),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .48, 1],
                    colors: [
                      Colors.black.withValues(alpha: current ? .04 : .19),
                      canvasColor.withValues(alpha: current ? .10 : .35),
                      const Color(0xF0130C20),
                    ],
                  ),
                ),
              ),
              if (showDetails && current)
                Align(
                  alignment: const Alignment(0, -.85),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xD02A2134),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x526B5A60)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        '${guide.method(s)} · AI',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: current ? 19 : 14,
                right: current ? 14 : 14,
                bottom: current && showDetails ? 20 : 23,
                child: Column(
                  crossAxisAlignment: current || guide != ReadingGuide.arun
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    if (current && showDetails)
                      Text(
                        guide.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: guide.color,
                          letterSpacing: 2,
                        ),
                      ),
                    Text(
                      guide.displayName(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: current ? 27 : 17,
                        height: 1.34,
                      ),
                    ),
                    if (current && showDetails)
                      Text(
                        guide.focus(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: mutedColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
