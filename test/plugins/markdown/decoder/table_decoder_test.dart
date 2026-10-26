import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  group('ordered list decoder', () {
    final parser = DocumentMarkdownDecoder(
      markdownElementParsers: [
        const MarkdownTableListParserV2(),
      ],
    );

    test('convert table', () {
      final result = parser.convert('''
| Month    | Savings |
| -------- | ------- |
| January  | \$250    |
| February | \$80     |
| March    | \$420    |
''');
      expect(result.root.children[0].toJson(), {
        'type': 'table',
        'children': [
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'Month'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 0,
              'rowPosition': 0,
              'height': 40.0,
              'width': 160.0,
            },
          },
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'January'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 0,
              'rowPosition': 1,
              'height': 40.0,
              'width': 160.0,
            },
          },
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'February'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 0,
              'rowPosition': 2,
              'height': 40.0,
              'width': 160.0,
            },
          },
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'March'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 0,
              'rowPosition': 3,
              'height': 40.0,
              'width': 160.0,
            },
          },
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': 'Savings'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 1,
              'rowPosition': 0,
              'height': 40.0,
              'width': 160.0,
            },
          },
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': '\$250'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 1,
              'rowPosition': 1,
              'height': 40.0,
              'width': 160.0,
            },
          },
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': '\$80'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 1,
              'rowPosition': 2,
              'height': 40.0,
              'width': 160.0,
            },
          },
          {
            'type': 'table/cell',
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {'insert': '\$420'},
                  ],
                },
              }
            ],
            'data': {
              'colPosition': 1,
              'rowPosition': 3,
              'height': 40.0,
              'width': 160.0,
            },
          }
        ],
        'data': {
          'colsLen': 2,
          'rowsLen': 4,
          'colDefaultWidth': 160.0,
          'rowDefaultHeight': 40.0,
          'colMinimumWidth': 40.0,
        },
      });
    });

    test('heading inside a cell', () {
      final document = markdownToDocument('|## Title|Rank|\n|-|-|\n|Spot|50|');
      final table = TableNode(node: document.root.children.single);
      final title = table.getCell(0, 0).children.first;
      expect(title.type, HeadingBlockKeys.type);
      expect(title.attributes[HeadingBlockKeys.level], 2);
      expect(title.delta!.toPlainText(), 'Title');
      expect(table.getCell(1, 0).children.first.delta!.toPlainText(), 'Rank');
      expect(table.getCell(0, 1).children.first.delta!.toPlainText(), 'Spot');
    });

    test('a heading and a line under it in one cell', () {
      final document = markdownToDocument('|## Title<br>body|Rank|\n|-|-|');
      final cell = TableNode(node: document.root.children.single).getCell(0, 0);
      expect(cell.children, hasLength(2));
      expect(cell.children[0].type, HeadingBlockKeys.type);
      expect(cell.children[0].delta!.toPlainText(), 'Title');
      expect(cell.children[1].type, ParagraphBlockKeys.type);
      expect(cell.children[1].delta!.toPlainText(), 'body');
    });

    test('line breaks in a cell stay in one paragraph', () {
      final document = markdownToDocument('|line1<br>line2<br/>**line3**|b|\n|-|-|');
      final cell = TableNode(node: document.root.children.single).getCell(0, 0);
      expect(cell.children, hasLength(1));
      expect(cell.children.single.delta!.toPlainText(), 'line1\nline2\nline3');
    });
  });
}
