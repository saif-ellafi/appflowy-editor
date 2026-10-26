import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/util.dart';

void main() async {
  group('deleteSelection', () {
    test('the selection is collapsed', () async {
      final document = Document.blank().addParagraphs(
        3,
        builder: (index) =>
            Delta()..insert('$index. Welcome to AppFlowy Editor 🔥!'),
      );
      final editorState = EditorState(document: document);

      final selection = Selection.collapsed(
        Position(path: [1], offset: 10),
      );
      final before = editorState.getNodesInSelection(selection).first;
      final result = await editorState.deleteSelection(selection);

      // nothing happens
      expect(result, false);
      final after = editorState.getNodesInSelection(selection).first;
      expect(
        before.toJson(),
        after.toJson(),
      );
    });

    test('the selection is single', () async {
      final document = Document.blank().addParagraphs(
        3,
        builder: (index) =>
            Delta()..insert('$index. Welcome to AppFlowy Editor 🔥!'),
      );
      final editorState = EditorState(document: document);

      // |Welcome|
      final selection = Selection.single(
        path: [1],
        startOffset: 3,
        endOffset: 10,
      );
      final result = await editorState.deleteSelection(selection);

      // nothing happens
      expect(result, true);
      expect(editorState.selection, selection.collapse(atStart: true));
      final after = editorState.getNodesInSelection(selection).first;
      expect(after.delta?.toPlainText(), '1.  to AppFlowy Editor 🔥!');
    });

    test('the selection is not single and not collapsed - 1', () async {
      final document = Document.blank().addParagraphs(
        3,
        builder: (index) =>
            Delta()..insert('$index. Welcome to AppFlowy Editor 🔥!'),
      );
      final editorState = EditorState(document: document);

      // |Welcome
      // ...
      // Welcome|
      final selection = Selection(
        start: Position(
          path: [0],
          offset: 3,
        ),
        end: Position(
          path: [2],
          offset: 10,
        ),
      );
      final result = await editorState.deleteSelection(selection);

      // nothing happens
      expect(result, true);
      expect(editorState.selection, selection.collapse(atStart: true));
      final length = editorState.document.root.children.length;
      expect(length, 1);
      expect(
        editorState.document.nodeAtPath([0])?.delta?.toPlainText(),
        '0.  to AppFlowy Editor 🔥!',
      );
    });

    // Before
    // 0. Welcome |to AppFlowy Editor 🔥!
    //   0.0. Welcome |to AppFlowy Editor 🔥!
    //     0.0.0. Welcome to AppFlowy Editor 🔥!
    //   0.1. Welcome to AppFlowy Editor 🔥!
    // After
    // 0. Welcome to AppFlowy Editor 🔥!
    //   0.0.0. Welcome to AppFlowy Editor 🔥!
    //   0.1. Welcome to AppFlowy Editor 🔥!
    test('the selection is not single and not collapsed - 2', () async {
      final document = Document.blank().addParagraph(
        builder: (index) =>
            Delta()..insert('$index. Welcome to AppFlowy Editor 🔥!'),
        decorator: (index, node) {
          node.addParagraphs(
            2,
            builder: (index2) => Delta()
              ..insert('$index.$index2. Welcome to AppFlowy Editor 🔥!'),
            decorator: (index2, node2) {
              if (index2 == 0) {
                node2.addParagraph(
                  builder: (index3) => Delta()
                    ..insert(
                      '$index.$index2.$index3. Welcome to AppFlowy Editor 🔥!',
                    ),
                );
              }
            },
          );
        },
      );
      final editorState = EditorState(document: document);

      // 0. Welcome |to AppFlowy Editor 🔥!
      //   0.0. Welcome |to AppFlowy Editor 🔥!
      //     0.0.0 Welcome to AppFlowy Editor 🔥!
      //   0.1 Welcome to AppFlowy Editor 🔥!
      final selection = Selection(
        start: Position(
          path: [0],
          offset: '0. Welcome '.length,
        ),
        end: Position(
          path: [0, 0],
          offset: '0.0. Welcome '.length,
        ),
      );
      final result = await editorState.deleteSelection(selection);

      // nothing happens
      expect(result, true);
      expect(editorState.selection, selection.collapse(atStart: true));
      expect(
        editorState.document.nodeAtPath([0])?.delta?.toPlainText(),
        '0. Welcome to AppFlowy Editor 🔥!',
      );
      expect(
        editorState.document.nodeAtPath([0, 0])?.delta?.toPlainText(),
        '0.0.0. Welcome to AppFlowy Editor 🔥!',
      );
      expect(
        editorState.document.nodeAtPath([0, 1])?.delta?.toPlainText(),
        '0.1. Welcome to AppFlowy Editor 🔥!',
      );
    });

    test('deleting a selection that covers a table removes the table', () async {
      final built = TableNode.fromList([
        ['Skill', 'Spot'],
        ['Rank', '50'],
      ]);
      final document = Document.blank()
        ..insert([0], [
          paragraphNode(text: 'Above'),
          built.node,
          paragraphNode(text: 'Below'),
        ]);
      final editorState = EditorState(document: document);
      final table = editorState.getNodeAtPath([1])!;
      final first = TableNode(node: table).getCell(0, 0).children.first;
      final last = TableNode(node: table).getCell(1, 1).children.first;

      final result = await editorState.deleteSelection(
        Selection(
          start: Position(path: first.path),
          end: Position(path: last.path, offset: last.delta!.length),
        ),
      );

      expect(result, true);
      expect(editorState.document.root.children.length, 2);
      expect(editorState.document.root.children[0].delta!.toPlainText(), 'Above');
      expect(editorState.document.root.children[1].delta!.toPlainText(), 'Below');
      expect(editorState.selection, Selection.collapsed(Position(path: [1])));
    });

    // Columns: 'aaaaa' 'bbbbb' on the first row, 'ccccc' 'ddddd' on the second.
    TableNode grid() => TableNode.fromList([
          ['aaaaa', 'ccccc'],
          ['bbbbb', 'ddddd'],
        ]);
    String cellText(Node table, int col, int row) => TableNode(node: table)
        .getCell(col, row)
        .children
        .map((n) => n.delta?.toPlainText() ?? '')
        .join('|');

    test('a selection from text into a table clears only the cells it reaches', () async {
      final editorState = EditorState(
        document: Document.blank()..insert([0], [paragraphNode(text: 'Above text'), grid().node]),
      );
      final table = editorState.getNodeAtPath([1])!;
      // Ends inside the first cell of the second row.
      final end = TableNode(node: table).getCell(0, 1).children.first;

      await editorState.deleteSelection(
        Selection(
          start: Position(path: [0], offset: 3),
          end: Position(path: end.path, offset: 2),
        ),
      );

      final after = editorState.getNodeAtPath([1])!;
      expect(editorState.getNodeAtPath([0])!.delta!.toPlainText(), 'Abo');
      expect(after.type, TableBlockKeys.type);
      expect(cellText(after, 0, 0), '');
      expect(cellText(after, 1, 0), '');
      expect(cellText(after, 0, 1), 'ccc');
      expect(cellText(after, 1, 1), 'ddddd');
      expect(editorState.selection, Selection.collapsed(Position(path: [0], offset: 3)));
    });

    test('a selection from a table into the text below clears cells row by row', () async {
      final editorState = EditorState(
        document: Document.blank()..insert([0], [grid().node, paragraphNode(text: 'Below text')]),
      );
      final table = editorState.getNodeAtPath([0])!;
      // Starts in the second cell of the first row.
      final start = TableNode(node: table).getCell(1, 0).children.first;

      await editorState.deleteSelection(
        Selection(
          start: Position(path: start.path, offset: 1),
          end: Position(path: [1], offset: 3),
        ),
      );

      final after = editorState.getNodeAtPath([0])!;
      expect(cellText(after, 0, 0), 'aaaaa');
      expect(cellText(after, 1, 0), 'b');
      expect(cellText(after, 0, 1), '');
      expect(cellText(after, 1, 1), '');
      expect(editorState.getNodeAtPath([1])!.delta!.toPlainText(), 'ow text');
      expect(editorState.selection, Selection.collapsed(Position(path: start.path, offset: 1)));
    });

    test('a selection from the start of a table into the text below removes the table', () async {
      final editorState = EditorState(
        document: Document.blank()..insert([0], [grid().node, paragraphNode(text: 'Below text')]),
      );
      final first = TableNode(node: editorState.getNodeAtPath([0])!).getCell(0, 0).children.first;

      await editorState.deleteSelection(
        Selection(
          start: Position(path: first.path),
          end: Position(path: [1], offset: 6),
        ),
      );

      expect(editorState.document.root.children, hasLength(1));
      expect(editorState.getNodeAtPath([0])!.delta!.toPlainText(), 'text');
      expect(editorState.selection, Selection.collapsed(Position(path: [0])));
    });

    test('a select-all over a lone table leaves one empty line', () async {
      final editorState = EditorState(
        document: Document.blank()..insert([0], [grid().node]),
      );
      final last = TableNode(node: editorState.getNodeAtPath([0])!).getCell(1, 1).children.first;

      await editorState.deleteSelection(
        Selection(
          start: Position(path: [0]),
          end: Position(path: last.path, offset: last.delta!.length),
        ),
      );

      expect(editorState.document.root.children, hasLength(1));
      expect(editorState.getNodeAtPath([0])!.type, ParagraphBlockKeys.type);
      expect(editorState.selection, Selection.collapsed(Position(path: [0])));
    });

    test('a rectangle short of the whole table clears text and keeps the table', () async {
      final editorState = EditorState(
        document: Document.blank()..insert([0], [grid().node]),
      );
      final table = editorState.getNodeAtPath([0])!;
      final first = TableNode(node: table).getCell(0, 0).children.first;
      final last = TableNode(node: table).getCell(1, 1).children.first;

      await editorState.deleteSelection(
        Selection(
          start: Position(path: first.path, offset: 1),
          end: Position(path: last.path, offset: 5),
        ),
      );

      final after = editorState.getNodeAtPath([0])!;
      expect(after.type, TableBlockKeys.type);
      expect(cellText(after, 0, 0), 'a');
      expect(cellText(after, 1, 0), '');
      expect(cellText(after, 0, 1), '');
      expect(cellText(after, 1, 1), '');
    });

    test('a rectangle keeps the lines of its first cell before the selection', () async {
      final built = grid();
      built.getCell(0, 0).insert(paragraphNode(text: 'second'));
      final editorState = EditorState(
        document: Document.blank()..insert([0], [built.node]),
      );
      final table = editorState.getNodeAtPath([0])!;
      final second = TableNode(node: table).getCell(0, 0).children[1];
      final end = TableNode(node: table).getCell(1, 0).children.first;

      await editorState.deleteSelection(
        Selection(
          start: Position(path: second.path, offset: 3),
          end: Position(path: end.path, offset: 1),
        ),
      );

      expect(cellText(editorState.getNodeAtPath([0])!, 0, 0), 'aaaaa|sec');
      expect(cellText(editorState.getNodeAtPath([0])!, 1, 0), 'bbbb');
    });

    test('two lines of one cell join', () async {
      final built = grid();
      built.getCell(0, 0).insert(paragraphNode(text: 'second'));
      final editorState = EditorState(
        document: Document.blank()..insert([0], [built.node]),
      );
      final cell = TableNode(node: editorState.getNodeAtPath([0])!).getCell(0, 0);

      await editorState.deleteSelection(
        Selection(
          start: Position(path: cell.children[0].path, offset: 2),
          end: Position(path: cell.children[1].path, offset: 3),
        ),
      );

      expect(cellText(editorState.getNodeAtPath([0])!, 0, 0), 'aaond');
      expect(editorState.getNodeAtPath([0])!.type, TableBlockKeys.type);
    });

    test('nodes in a selection that leaves a table run row by row', () {
      final editorState = EditorState(
        document: Document.blank()..insert([0], [grid().node, paragraphNode(text: 'Below')]),
      );
      final start = TableNode(node: editorState.getNodeAtPath([0])!).getCell(1, 0).children.first;

      final texts = editorState
          .getNodesInSelection(
            Selection(start: Position(path: start.path), end: Position(path: [1], offset: 2)),
          )
          .where((node) => node.delta != null)
          .map((node) => node.delta!.toPlainText())
          .toList();

      expect(texts, ['bbbbb', 'ccccc', 'ddddd', 'Below']);
    });

    test('deleting the only table leaves a paragraph', () async {
      final built = TableNode.fromList([
        ['Skill', 'Spot'],
        ['Rank', '50'],
      ]);
      final editorState = EditorState(
        document: Document.blank()..insert([0], [built.node]),
      );
      final table = editorState.getNodeAtPath([0])!;
      final last = TableNode(node: table).getCell(1, 1).children.first;

      final result = await editorState.deleteSelection(
        Selection(
          start: Position(path: [0]),
          end: Position(path: last.path, offset: last.delta!.length),
        ),
      );

      expect(result, true);
      expect(editorState.document.root.children.length, 1);
      expect(editorState.document.root.children.single.type, ParagraphBlockKeys.type);
      expect(editorState.document.root.children.single.delta!.toPlainText(), '');
      expect(editorState.selection, Selection.collapsed(Position(path: [0])));
    });

    test('a selection across a row stays on that row', () async {
      final built = TableNode.fromList([
        ['Skill', 'Spot'],
        ['Rank', '50'],
      ]);
      final editorState = EditorState(
        document: Document.blank()..insert([0], [built.node]),
      );
      final grid = TableNode(node: editorState.getNodeAtPath([0])!);
      final left = grid.getCell(0, 0).children.first;
      final right = grid.getCell(1, 0).children.first;
      final selection = Selection(
        start: Position(path: left.path),
        end: Position(path: right.path, offset: right.delta!.length),
      );

      final cells = editorState
          .getNodesInSelection(selection)
          .where((node) => node.type == TableCellBlockKeys.type)
          .map(
            (node) => (
              node.attributes[TableCellBlockKeys.colPosition],
              node.attributes[TableCellBlockKeys.rowPosition],
            ),
          )
          .toList();
      expect(cells, [
        (0, 0),
        (1, 0),
      ]);

      final result = await editorState.deleteSelection(selection);

      expect(result, true);
      final after = TableNode(node: editorState.getNodeAtPath([0])!);
      expect(after.colsLen, 2);
      expect(after.rowsLen, 2);
      expect(after.getCell(0, 0).children.first.delta!.toPlainText(), '');
      expect(after.getCell(1, 0).children.first.delta!.toPlainText(), '');
      expect(after.getCell(0, 1).children.first.delta!.toPlainText(), 'Spot');
      expect(after.getCell(1, 1).children.first.delta!.toPlainText(), '50');
    });

    test('deleting text in one cell keeps the table', () async {
      final built = TableNode.fromList([
        ['Skill', 'Spot'],
        ['Rank', '50'],
      ]);
      final editorState = EditorState(
        document: Document.blank()..insert([0], [built.node]),
      );
      final text = TableNode(node: editorState.getNodeAtPath([0])!).getCell(0, 0).children.first;

      final result = await editorState.deleteSelection(
        Selection.single(path: text.path, startOffset: 0, endOffset: 2),
      );

      expect(result, true);
      expect(editorState.document.root.children.single.type, TableBlockKeys.type);
      expect(editorState.document.root.children.single.children.length, 4);
      expect(text.delta!.toPlainText(), 'ill');
    });
  });
}
