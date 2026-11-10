import 'package:flutter/services.dart';

class LanguageFonts {
  Future<void>? _chinese;
  Future<void> ensure(String language) async {
    if (language != 'zh') return;
    try {
      await (_chinese ??=
          (FontLoader('NotoSansSC')..addFont(
                rootBundle.load('assets/fonts/NotoSansSC-Regular.otf'),
              ))
              .load());
    } catch (_) {
      _chinese = null;
      rethrow;
    }
  }
}
