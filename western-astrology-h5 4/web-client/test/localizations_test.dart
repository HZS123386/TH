import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fate_h5/app/localizations.dart';
import 'package:intl/intl.dart';

void main() {
  test('cold startup retains the default birth-date serialization', () async {
    final material = h5Localizations
        .whereType<LocalizationsDelegate<MaterialLocalizations>>()
        .single;
    await material.load(const Locale('zh'));
    expect(
      DateFormat('yyyy-MM-dd').format(DateTime(1999, 11, 23)),
      '1999-11-23',
    );
  });
  for (final language in ['zh', 'th']) {
    test(
      '$language retains Flutter date, time and component translations',
      () async {
        final locale = Locale(language);
        final date = DateTime(1999, 11, 23);
        const time = TimeOfDay(hour: 7, minute: 5);
        Map<String, Object> materialValues(MaterialLocalizations value) => {
          'cancel': value.cancelButtonLabel,
          'ok': value.okButtonLabel,
          'date': value.formatFullDate(date),
          'compactDate': value.formatCompactDate(date),
          'month': value.formatMonthYear(date),
          'time': value.formatTimeOfDay(time, alwaysUse24HourFormat: true),
          'numbers': value.formatDecimal(12345),
        };
        Map<String, Object> cupertinoValues(CupertinoLocalizations value) => {
          'cancel': value.cancelButtonLabel,
          'year': value.datePickerYear(1999),
          'month': value.datePickerMonth(11),
          'day': value.datePickerDayOfMonth(23),
          'hour': value.datePickerHour(7),
          'minute': value.datePickerMinute(5),
          'date': value.datePickerMediumDate(date),
        };

        final expectedMaterial = materialValues(
          await GlobalMaterialLocalizations.delegate.load(locale),
        );
        final expectedCupertino = cupertinoValues(
          await GlobalCupertinoLocalizations.delegate.load(locale),
        );
        final material = h5Localizations
            .whereType<LocalizationsDelegate<MaterialLocalizations>>()
            .single;
        final cupertino = h5Localizations
            .whereType<LocalizationsDelegate<CupertinoLocalizations>>()
            .single;
        expect(material.isSupported(locale), isTrue);
        expect(cupertino.isSupported(locale), isTrue);
        expect(materialValues(await material.load(locale)), expectedMaterial);
        expect(
          cupertinoValues(await cupertino.load(locale)),
          expectedCupertino,
        );
      },
    );
  }
}
