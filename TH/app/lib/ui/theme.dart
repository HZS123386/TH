import 'package:flutter/material.dart';

const canvasColor = Color(0xFF130C24),
    panelColor = Color(0xFF20152F),
    goldColor = Color(0xFFE4BC78),
    inkColor = Color(0xFFFFF5DF),
    mutedColor = Color(0xFFB4A8C6),
    lineColor = Color(0xFF483357);

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
    onSurface: inkColor,
    outline: lineColor,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansThai',
    fontFamilyFallback: const ['NotoSansSC'],
    colorScheme: scheme,
    scaffoldBackgroundColor: canvasColor,
    textTheme: ThemeData.dark().textTheme
        .apply(
          fontFamily: 'NotoSansThai',
          fontFamilyFallback: const ['NotoSansSC'],
          bodyColor: inkColor,
          displayColor: inkColor,
        )
        .copyWith(
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.85,
            color: inkColor,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            height: 1.85,
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
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panelColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lineColor),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: Color(0x887A664B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: panelColor,
      indicatorColor: Color(0xFF382346),
      height: 76,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, color: inkColor),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: goldColor)),
    ),
    dividerTheme: const DividerThemeData(
      color: lineColor,
      space: 36,
      thickness: 1,
    ),
  );
}

class FateCard extends StatelessWidget {
  const FateCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gold = false,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool gold;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: panelColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: gold ? goldColor.withValues(alpha: .35) : lineColor,
        ),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 24),
    ],
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
