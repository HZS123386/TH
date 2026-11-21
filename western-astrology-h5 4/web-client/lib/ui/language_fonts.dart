import 'package:flutter/services.dart';
import 'chinese_coverage.dart';

class LanguageFonts {
  LanguageFonts({Future<void> Function(String, String)? loadFont})
    : _loadFont = loadFont ?? _load;
  final Future<void> Function(String, String) _loadFont;
  final _pending = <String, Future<void>>{};
  static final _ui = chineseUiCharacters.runes.toSet();
  static final _common = chineseCommonCharacters.runes.toSet();

  static Future<void> _load(String family, String asset) =>
      (FontLoader(family)..addFont(rootBundle.load(asset))).load();

  Future<void> _ensure(String family, String asset) async {
    final pending = _pending.putIfAbsent(family, () async {
      for (var attempt = 0; ; attempt++) {
        try {
          await _loadFont(family, asset);
          return;
        } catch (_) {
          if (attempt == 2) rethrow;
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
        }
      }
    });
    try {
      await pending;
    } catch (_) {
      if (identical(_pending[family], pending)) _pending.remove(family);
      rethrow;
    }
  }

  Future<void> ensure(String language) async {
    final regional = {
      'my': ('NotoMyanmar', 'NotoSansMyanmar-Regular.ttf'),
      'km': ('NotoKhmer', 'NotoSansKhmer-Regular.ttf'),
      'lo': ('NotoLao', 'NotoSansLao-Regular.ttf'),
    }[language];
    if (regional != null) {
      await _ensure(regional.$1, 'assets/fonts/${regional.$2}');
    }
    if (language != 'zh') return;
    await _ensure('NotoSansSC', 'assets/fonts/FateChineseUI.otf');
  }

  Future<void> warmSwitchLanguages() async {
    // Register the small switch fonts after first paint; large CJK sets stay on demand.
    await Future.wait([
      for (final language in ['zh', 'my', 'km', 'lo'])
        ensure(language).catchError((_) {}),
    ]);
  }

  Future<void> ensureCommon(String language) async {
    await ensure(language);
    if (language != 'zh') return;
    await _ensure('NotoSansSCCommon', 'assets/fonts/FateChineseCommon.otf');
  }

  Future<void> ensureText(String language, String value) async {
    await ensure(language);
    if (language != 'zh') return;
    final codes = value.runes.where(_isChinese).toSet();
    if (codes.every(_ui.contains)) return;
    await ensureCommon(language);
    if (codes.every(_common.contains)) return;
    await _ensure('NotoSansSCFull', 'assets/fonts/NotoSansSC-Regular.otf');
  }

  static bool _isChinese(int c) =>
      c >= 0x2e80 && c <= 0x9fff ||
      c >= 0xf900 && c <= 0xfaff ||
      c >= 0xff00 && c <= 0xffef ||
      c >= 0x20000 && c <= 0x323af;
}
