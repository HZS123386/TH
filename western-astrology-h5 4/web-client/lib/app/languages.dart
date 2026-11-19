import 'package:flutter/widgets.dart';

const h5Languages = [
  ('th', 'ภาษาไทย'),
  ('en', 'English'),
  ('zh', '简体中文'),
  ('vi', 'Tiếng Việt'),
  ('my', 'မြန်မာဘာသာ'),
  ('km', 'ខ្មែរ'),
  ('lo', 'ລາວ'),
  ('ms', 'Bahasa Melayu'),
  ('id', 'Bahasa Indonesia'),
];

String h5Language(String? value) =>
    h5Languages.any((item) => item.$1 == value) ? value! : 'th';

String h5BirthCountry(String language) => switch (language) {
  'zh' => 'CN',
  'en' => 'SG',
  'vi' => 'VN',
  'my' => 'MM',
  'km' => 'KH',
  'lo' => 'LA',
  'ms' => 'MY',
  'id' => 'ID',
  _ => 'TH',
};

Locale h5Locale(String language) =>
    language == 'en' ? const Locale('en', 'SG') : Locale(language);

String h5DateLocale(String language) => language == 'en' ? 'en_SG' : language;

const h5Locales = [
  Locale('th'),
  Locale('en', 'SG'),
  Locale('zh'),
  Locale('vi'),
  Locale('my'),
  Locale('km'),
  Locale('lo'),
  Locale('ms'),
  Locale('id'),
];
