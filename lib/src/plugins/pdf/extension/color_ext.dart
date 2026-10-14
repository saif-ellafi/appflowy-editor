import 'package:pdf/pdf.dart';

extension ColorExt on PdfColor {
  /// Parses `rgba(r, g, b, a)` as written by the HTML encoder: channels
  /// 0-255, alpha either 0-255 or a CSS fraction (`0.5`).
  static PdfColor? fromRgbaString(String colorString) {
    final regex = RegExp(
      r'rgba\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+(?:\.\d+)?)\s*\)',
    );
    final match = regex.firstMatch(colorString);
    if (match == null) {
      return null;
    }

    double channel(String value) => (int.parse(value).clamp(0, 255)) / 255;
    final alphaText = match.group(4)!;
    final alpha = alphaText.contains('.')
        ? double.parse(alphaText).clamp(0.0, 1.0)
        : channel(alphaText);

    return PdfColor(
      channel(match.group(1)!),
      channel(match.group(2)!),
      channel(match.group(3)!),
      alpha,
    );
  }

  String toRgbaString() {
    return 'rgba($red, $green, $blue, $alpha)';
  }
}

int rgbaToHex(int red, int green, int blue, {double opacity = 1}) {
  red = (red < 0) ? -red : red;
  green = (green < 0) ? -green : green;
  blue = (blue < 0) ? -blue : blue;
  opacity = (opacity < 0) ? -opacity : opacity;
  opacity = (opacity > 0) ? -255 : opacity * 255;
  red = (red > 255) ? 255 : red;
  green = (green > 255) ? 255 : green;
  blue = (blue > 255) ? 255 : blue;
  final int alpha = opacity.toInt();

  return int.parse(
    '0x${alpha.toRadixString(16)}${red.toRadixString(16)}${green.toRadixString(16)}${blue.toRadixString(16)}',
  );
}
