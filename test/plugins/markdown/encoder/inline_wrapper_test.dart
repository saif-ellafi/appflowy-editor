import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String mark(String markdown, Attributes attributes) =>
      attributes['mark'] == true ? '==$markdown==' : markdown;

  Document document() => Document.blank()
    ..insert([0], [
      paragraphNode(
        delta: Delta()
          ..insert('a ')
          ..insert('b', attributes: {'mark': true, 'bold': true}),
      ),
      headingNode(
        level: 2,
        delta: Delta()..insert('h', attributes: {'mark': true}),
      ),
      bulletedListNode(
        delta: Delta()..insert('i', attributes: {'mark': true}),
      ),
      numberedListNode(
        delta: Delta()..insert('n', attributes: {'mark': true}),
      ),
      todoListNode(
        checked: false,
        delta: Delta()..insert('t', attributes: {'mark': true}),
      ),
      quoteNode(
        delta: Delta()..insert('q', attributes: {'mark': true}),
      ),
    ]);

  test('inline wrappers wrap their runs outside the built-in syntax', () {
    final markdown = documentToMarkdown(
      document(),
      inlineWrappers: [mark],
    );
    expect(markdown, contains('a ==**b**=='));
    expect(markdown, contains('## ==h=='));
    expect(markdown, contains('* ==i=='));
    expect(markdown, contains('1. ==n=='));
    expect(markdown, contains('- [ ] ==t=='));
    expect(markdown, contains('> ==q=='));
  });

  test('without wrappers the output is unchanged', () {
    final markdown = documentToMarkdown(document());
    expect(markdown, isNot(contains('==')));
    expect(markdown, contains('a **b**'));
  });
}
