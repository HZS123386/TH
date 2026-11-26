import 'package:flutter_test/flutter_test.dart';
import 'package:fate_h5/app/languages.dart';

void main() {
  test('fresh and unsupported entry languages default to Thai', () {
    expect(h5Language(null), 'th');
    expect(h5Language('unsupported'), 'th');
    for (final option in h5Languages) {
      expect(h5Language(option.$1), option.$1);
    }
  });
}
