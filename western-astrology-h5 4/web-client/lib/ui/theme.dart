import 'package:flutter/material.dart';

const h5FontFamily = 'NotoSansThai';
const h5FontFallback = [
  'FateLanguageLabel',
  'NotoSansSC',
  'NotoSansSCCommon',
  'NotoSansSCFull',
  'NotoSansSymbols',
  'NotoSansSymbols2',
];

const night = Color(0xFF130C24),
    panel = Color(0xFF211733),
    gold = Color(0xFFE4BC78),
    cream = Color(0xFFFFF5DF),
    lavender = Color(0xFFB4A8C6),
    line = Color(0xFF463655);
ThemeData h5Theme() => ThemeData(
  useMaterial3: true,
  visualDensity: VisualDensity.standard,
  brightness: Brightness.dark,
  fontFamily: h5FontFamily,
  fontFamilyFallback: h5FontFallback,
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
        fontFamily: h5FontFamily,
        fontFamilyFallback: h5FontFallback,
        bodyColor: cream,
        displayColor: cream,
      )
      .copyWith(
        bodyMedium: const TextStyle(
          fontFamily: h5FontFamily,
          fontFamilyFallback: h5FontFallback,
          fontSize: 14,
          height: 1.55,
          color: cream,
        ),
        bodySmall: const TextStyle(
          fontFamily: h5FontFamily,
          fontFamilyFallback: h5FontFallback,
          fontSize: 12,
          height: 1.55,
          color: lavender,
        ),
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF110B1F),
    foregroundColor: gold,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: night,
    isDense: true,
    hintStyle: const TextStyle(
      fontSize: 11,
      color: lavender,
      fontWeight: FontWeight.w400,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0x40E4BC78)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0x40E4BC78)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(51),
      backgroundColor: gold,
      foregroundColor: night,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      foregroundColor: gold,
      side: const BorderSide(color: Color(0x4DE4BC78)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      textStyle: const TextStyle(
        fontFamily: h5FontFamily,
        fontFamilyFallback: h5FontFallback,
        fontSize: 10,
        height: 1.55,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
