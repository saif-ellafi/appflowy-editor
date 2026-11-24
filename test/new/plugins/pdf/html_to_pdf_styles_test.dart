import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fill colors (`r g b rg`) the PDF's pages paint text with.
Future<Set<String>> _fillColors(String html) async {
  final pdf = await PdfHTMLEncoder(fontFallback: const []).convert(html);
  final bytes = await pdf.save();
  final raw = String.fromCharCodes(bytes);
  final colors = <String>{};
  for (final match
      in RegExp(r'stream\r?\n(.*?)\r?\nendstream', dotAll: true)
          .allMatches(raw)) {
    List<int> content;
    try {
      content = zlib.decode(match.group(1)!.codeUnits);
    } catch (_) {
      continue;
    }
    colors.addAll(
      RegExp(r'([\d.]+ [\d.]+ [\d.]+) rg')
          .allMatches(String.fromCharCodes(content))
          .map((m) => m.group(1)!),
    );
  }

  return colors;
}

void main() {
  test('a line break inside a paragraph is written as <br>', () {
    final document = Document.blank()
      ..insert([0], [
        paragraphNode(
          delta: Delta()
            ..insert('first\nsecond ')
            ..insert('bold\nline', attributes: {'bold': true}),
        ),
      ]);
    final html = documentToHTML(document);
    expect(html, contains('first<br>second'));
    expect(html, contains('bold<br>line'));
  });

  test('span colors reach the PDF', () async {
    final colors = await _fillColors(
      '<p>plain <span style="color: rgba(198, 40, 40, 255)">red</span></p>',
    );
    expect(colors, contains('0.77647 0.15686 0.15686'));
  });

  test('without a span style the text stays the default color', () async {
    final colors = await _fillColors('<p>plain <strong>bold</strong></p>');
    expect(colors.every((c) => c == '0 0 0'), isTrue);
  });
}
