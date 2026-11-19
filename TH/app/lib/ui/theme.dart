import 'package:flutter/material.dart';

// Share the established H5 palette across every native surface.
const canvasColor = Color(0xFF130C24),
    panelColor = Color(0xFF211733),
    goldColor = Color(0xFFE4BC78),
    inkColor = Color(0xFFFFF5DF),
    mutedColor = Color(0xFFB4A8C6),
    lineColor = Color(0xFF463655);

abstract final class FateMotion {
  static const feedback = Duration(milliseconds: 120);
  static const settle = Duration(milliseconds: 180);
  static const change = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 300);
  static const entrance = Duration(milliseconds: 380);

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;

  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;

  static AnimationStyle dialog(BuildContext context) => reduced(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: change,
          reverseDuration: settle,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
}

// Entrance runs once per mounted item; rebuilding data never restarts it.
class FateEntrance extends StatelessWidget {
  const FateEntrance({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (FateMotion.reduced(context)) return child;
    final duration = FateMotion.entrance + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(
        delay.inMilliseconds / duration.inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

ThemeData fateTheme() {
  const scheme = ColorScheme.dark(
    primary: goldColor,
    primaryContainer: Color(0xFF382346),
    onPrimaryContainer: inkColor,
    secondary: goldColor,
    secondaryContainer: Color(0xFF382346),
    onSecondaryContainer: inkColor,
    onPrimary: Color(0xFF1C102A),
    surface: panelColor,
    surfaceContainerHighest: Color(0xFF352543),
    surfaceContainerLow: Color(0xFF1C122C),
    onSurface: inkColor,
    onSurfaceVariant: mutedColor,
    outline: lineColor,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansThai',
    fontFamilyFallback: const ['NotoSansSC', 'NotoSansSymbols'],
    colorScheme: scheme,
    scaffoldBackgroundColor: canvasColor,
    textTheme: ThemeData.dark().textTheme
        .apply(
          fontFamily: 'NotoSansThai',
          fontFamilyFallback: const ['NotoSansSC', 'NotoSansSymbols'],
          bodyColor: inkColor,
          displayColor: inkColor,
        )
        .copyWith(
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.65,
            color: inkColor,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            height: 1.65,
            color: mutedColor,
          ),
          titleLarge: const TextStyle(
            fontSize: 24,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: inkColor,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvasColor,
      foregroundColor: goldColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panelColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: lineColor),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: panelColor,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: mutedColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3A294A),
      contentTextStyle: const TextStyle(color: inkColor, height: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panelColor,
      hintStyle: const TextStyle(color: mutedColor, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: goldColor, width: 1.3),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        animationDuration: FateMotion.feedback,
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        animationDuration: FateMotion.feedback,
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: Color(0x887A664B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: canvasColor,
      indicatorColor: goldColor.withValues(alpha: .16),
      height: 72,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? goldColor : mutedColor,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? goldColor : mutedColor,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lineColor,
      space: 36,
      thickness: 1,
    ),
  );
}

class FateCard extends StatefulWidget {
  const FateCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gold = false,
    this.onTap,
    this.accent,
    this.radius = 20,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool gold;
  final VoidCallback? onTap;
  final Color? accent;
  final double radius;

  @override
  State<FateCard> createState() => _FateCardState();
}

class _FateCardState extends State<FateCard> {
  bool _pressed = false, _hovered = false, _focused = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed && !FateMotion.reduced(context) ? .985 : 1,
    duration: FateMotion.duration(
      context,
      _pressed ? FateMotion.feedback : FateMotion.settle,
    ),
    curve: Curves.easeOutCubic,
    child: SizedBox(
      width: double.infinity,
      child: Material(
        color: panelColor,
        clipBehavior: Clip.antiAlias,
        animationDuration: FateMotion.duration(context, FateMotion.settle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.radius),
          side: BorderSide(
            color: (_pressed || _hovered || _focused) && widget.onTap != null
                ? (widget.accent ?? goldColor).withValues(alpha: .65)
                : widget.accent?.withValues(alpha: .22) ??
                      (widget.gold
                          ? goldColor.withValues(alpha: .35)
                          : lineColor.withValues(alpha: .55)),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  (widget.accent ??
                          (widget.gold ? goldColor : const Color(0xFF9672B2)))
                      .withValues(alpha: widget.gold ? .10 : .07),
                  panelColor,
                ),
                const Color(0xFF1E142E),
              ],
            ),
          ),
          child: widget.onTap == null
              ? Padding(padding: widget.padding, child: widget.child)
              : InkWell(
                  onTap: widget.onTap,
                  onHighlightChanged: (value) =>
                      setState(() => _pressed = value),
                  onHover: (value) => setState(() => _hovered = value),
                  onFocusChange: (value) => setState(() => _focused = value),
                  splashColor: (widget.accent ?? goldColor).withValues(
                    alpha: .08,
                  ),
                  child: Padding(padding: widget.padding, child: widget.child),
                ),
        ),
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {this.icon, super.key});
  final String title, subtitle;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (icon != null) ...[
            FateEmblem(icon!, size: 48),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 24),
    ],
  );
}

class FateEmblem extends StatelessWidget {
  const FateEmblem(
    this.icon, {
    this.size = 48,
    this.color = goldColor,
    super.key,
  });
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: .28)),
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .16), color.withValues(alpha: .03)],
      ),
    ),
    child: Icon(icon, color: color, size: size * .44),
  );
}

class FateSectionTitle extends StatelessWidget {
  const FateSectionTitle(this.title, {this.subtitle, this.trailing, super.key});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class ReadingParagraph extends StatelessWidget {
  const ReadingParagraph(this.title, this.body, {super.key});
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            height: 1.65,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(body),
      ],
    ),
  );
}
