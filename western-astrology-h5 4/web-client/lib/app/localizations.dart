import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';
import 'date_data.dart';
import 'languages.dart';

// Instantiate only the supported translations so other languages tree-shake.
const h5Localizations = <LocalizationsDelegate<dynamic>>[
  _MaterialDelegate(),
  GlobalWidgetsLocalizations.delegate,
  _CupertinoDelegate(),
];

final _initializedDates = <String>{};
void _initializeDates(String language) {
  // Custom registration replaces Intl's initial maps, including its US default.
  for (final locale in ['en_US', 'en', language]) {
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
  bool isSupported(Locale locale) =>
      h5Languages.any((item) => item.$1 == locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final language = locale.languageCode;
    final dateLocale = h5DateLocale(language);
    _initializeDates(dateLocale);
    final formats = (
      year: DateFormat.y(dateLocale),
      compact: DateFormat.yMd(dateLocale),
      short: DateFormat.yMMMd(dateLocale),
      medium: DateFormat.MMMEd(dateLocale),
      long: DateFormat.yMMMMEEEEd(dateLocale),
      yearMonth: DateFormat.yMMMM(dateLocale),
      monthDay: DateFormat.MMMd(dateLocale),
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
    if (language == 'en') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationEnSg(
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
    if (language == 'vi') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationVi(
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
    if (language == 'my') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationMy(
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
    if (language == 'km') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationKm(
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
    if (language == 'lo') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationLo(
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
    if (language == 'ms') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationMs(
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
    if (language == 'id') {
      return SynchronousFuture<MaterialLocalizations>(
        MaterialLocalizationId(
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
  bool isSupported(Locale locale) =>
      h5Languages.any((item) => item.$1 == locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final language = locale.languageCode;
    final dateLocale = h5DateLocale(language);
    _initializeDates(dateLocale);
    final formats = (
      year: DateFormat.y(dateLocale),
      day: DateFormat.d(dateLocale),
      weekday: DateFormat.E(dateLocale),
      medium: DateFormat.MMMEd(dateLocale),
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
    if (language == 'en') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationEnSg(
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
    if (language == 'vi') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationVi(
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
    if (language == 'my') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationMy(
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
    if (language == 'km') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationKm(
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
    if (language == 'lo') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationLo(
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
    if (language == 'ms') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationMs(
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
    if (language == 'id') {
      return SynchronousFuture<CupertinoLocalizations>(
        CupertinoLocalizationId(
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
