import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';
import 'date_data.dart';

// Instantiate only our two supported translations so other languages tree-shake.
const h5Localizations = <LocalizationsDelegate<dynamic>>[
  _MaterialDelegate(),
  GlobalWidgetsLocalizations.delegate,
  _CupertinoDelegate(),
];

final _initializedDates = <String>{};
void _initializeDates(String language) {
  // Custom registration replaces Intl's initial maps, including its US default.
  for (final locale in ['en_US', language]) {
    if (_initializedDates.contains(locale)) continue;
    initializeDateFormattingCustom(
      locale: locale,
      symbols: DateSymbols.deserializeFromMap(h5DateSymbols[locale]!),
      patterns: h5DatePatterns[locale]!,
    );
    _initializedDates.add(locale);
  }
}

class _MaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialDelegate();

  @override
  bool isSupported(Locale locale) => ['th', 'zh'].contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final language = locale.languageCode;
    _initializeDates(language);
    final formats = (
      year: DateFormat.y(language),
      compact: DateFormat.yMd(language),
      short: DateFormat.yMMMd(language),
      medium: DateFormat.MMMEd(language),
      long: DateFormat.yMMMMEEEEd(language),
      yearMonth: DateFormat.yMMMM(language),
      monthDay: DateFormat.MMMd(language),
      decimal: NumberFormat.decimalPattern(language),
      twoDigits: NumberFormat('00', language),
    );
    if (language == 'zh') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationZh(
          fullYearFormat: formats.year,
          compactDateFormat: formats.compact,
          shortDateFormat: formats.short,
          mediumDateFormat: formats.medium,
          longDateFormat: formats.long,
          yearMonthFormat: formats.yearMonth,
          shortMonthDayFormat: formats.monthDay,
          decimalFormat: formats.decimal,
          twoDigitZeroPaddedFormat: formats.twoDigits,
        ),
      );
    }
    return SynchronousFuture<MaterialLocalizations>(
      MaterialLocalizationTh(
        fullYearFormat: formats.year,
        compactDateFormat: formats.compact,
        shortDateFormat: formats.short,
        mediumDateFormat: formats.medium,
        longDateFormat: formats.long,
        yearMonthFormat: formats.yearMonth,
        shortMonthDayFormat: formats.monthDay,
        decimalFormat: formats.decimal,
        twoDigitZeroPaddedFormat: formats.twoDigits,
      ),
    );
  }

  @override
  bool shouldReload(_MaterialDelegate old) => false;
}

class _CupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoDelegate();

  @override
  bool isSupported(Locale locale) => ['th', 'zh'].contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final language = locale.languageCode;
    _initializeDates(language);
    final formats = (
      year: DateFormat.y(language),
      day: DateFormat.d(language),
      weekday: DateFormat.E(language),
      medium: DateFormat.MMMEd(language),
      hour: DateFormat('HH', language),
      minute: DateFormat.m(language),
      twoMinutes: DateFormat('mm', language),
      second: DateFormat.s(language),
      decimal: NumberFormat.decimalPattern(language),
    );
    if (language == 'zh') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationZh(
          fullYearFormat: formats.year,
          dayFormat: formats.day,
          weekdayFormat: formats.weekday,
          mediumDateFormat: formats.medium,
          singleDigitHourFormat: formats.hour,
          singleDigitMinuteFormat: formats.minute,
          doubleDigitMinuteFormat: formats.twoMinutes,
          singleDigitSecondFormat: formats.second,
          decimalFormat: formats.decimal,
        ),
      );
    }
    return SynchronousFuture<CupertinoLocalizations>(
      CupertinoLocalizationTh(
        fullYearFormat: formats.year,
        dayFormat: formats.day,
        weekdayFormat: formats.weekday,
        mediumDateFormat: formats.medium,
        singleDigitHourFormat: formats.hour,
        singleDigitMinuteFormat: formats.minute,
        doubleDigitMinuteFormat: formats.twoMinutes,
        singleDigitSecondFormat: formats.second,
        decimalFormat: formats.decimal,
      ),
    );
  }

  @override
  bool shouldReload(_CupertinoDelegate old) => false;
}
