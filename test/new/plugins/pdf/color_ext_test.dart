import 'package:appflowy_editor/src/plugins/pdf/extension/color_ext.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the HTML encoder rgba strings, alpha 0-255 or a fraction', () {
    final solid = ColorExt.fromRgbaString('rgba(136, 8, 0, 255)')!;
    expect(solid.toInt(), 0xFF880800);

    final faint = ColorExt.fromRgbaString('rgba(255, 136, 0, 51)')!;
    expect(faint.alpha, closeTo(0.2, 0.001));
    expect(ColorExt.fromRgbaString('rgba(255, 136, 0, 0.5)')!.alpha, 0.5);

    expect(ColorExt.fromRgbaString('red'), isNull);
  });
}
