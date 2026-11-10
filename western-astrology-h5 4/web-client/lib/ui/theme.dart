import 'package:flutter/material.dart';

const night = Color(0xFF130C24),
    panel = Color(0xFF20152F),
    gold = Color(0xFFE4BC78),
    cream = Color(0xFFFFF5DF),
    lavender = Color(0xFFB4A8C6),
    line = Color(0xFF483357);
ThemeData h5Theme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'NotoSansThai',
  fontFamilyFallback: const ['FateLanguageLabel', 'NotoSansSC'],
  scaffoldBackgroundColor: night,
  colorScheme: const ColorScheme.dark(
    primary: gold,
    onPrimary: night,
    surface: panel,
    onSurface: cream,
    outline: line,
  ),
  textTheme: ThemeData.dark().textTheme
      .apply(
        fontFamily: 'NotoSansThai',
        fontFamilyFallback: const ['FateLanguageLabel', 'NotoSansSC'],
        bodyColor: cream,
        displayColor: cream,
      )
      .copyWith(
        bodyMedium: const TextStyle(fontSize: 14, height: 1.85, color: cream),
        bodySmall: const TextStyle(fontSize: 12, height: 1.8, color: lavender),
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: night,
    foregroundColor: gold,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: gold,
      foregroundColor: night,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: gold,
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: line, space: 42),
);

class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlight = false,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool highlight;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: highlight ? gold.withValues(alpha: .4) : line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.subtitle = '', super.key});
  final String text, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.6,
          ),
        ),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    ),
  );
}

Widget errorMessage(String value) => value.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFFF2A6AF), height: 1.7),
          ),
        ),
      );
