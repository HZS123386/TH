import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fate_h5/ui/chinese_coverage.dart';
import 'package:fate_h5/ui/language_fonts.dart';

void main() {
  test(
    'startup loads only the small UI font; Thai does not download Chinese',
    () async {
      final assets = <String>[];
      final fonts = LanguageFonts(
        loadFont: (family, path) async => assets.add(path),
      );
      await fonts.ensure('th');
      expect(assets, isEmpty);
      await fonts.ensure('zh');
      await fonts.ensureText('zh', '出生日期，立即解析');
      expect(assets, ['assets/fonts/FateChineseUI.otf']);
    },
  );

  test(
    'additional text loads common then full fonts only when needed and deduplicates concurrent requests',
    () async {
      final ui = chineseUiCharacters.runes.toSet();
      final common = chineseCommonCharacters.runes.toSet();
      final extra = String.fromCharCode(
        common.firstWhere((code) => !ui.contains(code)),
      );
      expect(common.contains('龘'.runes.single), isFalse);
      final loaded = <String>[];
      final gate = Completer<void>();
      final fonts = LanguageFonts(
        loadFont: (family, path) async {
          loaded.add(family);
          if (family == 'NotoSansSCCommon') await gate.future;
        },
      );
      await fonts.ensure('zh');
      final first = fonts.ensureText('zh', extra),
          second = fonts.ensureText('zh', extra);
      await Future<void>.delayed(Duration.zero);
      expect(loaded, ['NotoSansSC', 'NotoSansSCCommon']);
      gate.complete();
      await Future.wait([first, second]);
      await fonts.ensureText('zh', '龘');
      await fonts.ensureText('zh', '龘');
      expect(loaded, ['NotoSansSC', 'NotoSansSCCommon', 'NotoSansSCFull']);
    },
  );

  test('a failed font load can be retried', () async {
    var attempts = 0;
    final fonts = LanguageFonts(
      loadFont: (family, path) async {
        if (++attempts == 1) throw StateError('network');
      },
    );
    await expectLater(fonts.ensure('zh'), throwsStateError);
    await fonts.ensure('zh');
    await fonts.ensure('zh');
    expect(attempts, 2);
  });
}
