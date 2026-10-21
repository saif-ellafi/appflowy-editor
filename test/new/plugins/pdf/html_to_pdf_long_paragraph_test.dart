import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A paragraph that can't break across pages never gets placed: debug builds
  // throw TooManyPagesException, release builds loop forever.
  test('a paragraph taller than a page breaks across pages', () async {
    final long = List.filled(400, 'Maedhen lowers her hunting spear but keeps her center of gravity firm.').join(' ');
    final pdf = await PdfHTMLEncoder(fontFallback: const []).convert('<p>$long</p>', maxPages: 50);
    expect(await pdf.save(), isNotEmpty);
  });
}
