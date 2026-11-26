import 'package:flutter_test/flutter_test.dart';
import 'package:godothub/design/design.dart';

void main() {
  test('brand logos come from the Font Awesome brands set, not from our own drawings', () {
    for (final icon in [GhIcons.github, GhIcons.gitlab]) {
      expect(icon.prefix, 'fab');
      expect(icon.path, isNotEmpty);
    }
  });
}
