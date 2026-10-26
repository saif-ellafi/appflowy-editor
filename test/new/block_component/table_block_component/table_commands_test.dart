import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/testable_editor.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('table_shortcut_event.dart', () {
    testWidgets('enter key on middle cells', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.enter);

      final selection = editor.selection!;
      final cell01 = getCellNode(tableNode.node, 0, 1)!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell01.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);
      await editor.dispose();
    });

    testWidgets('enter key on last cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell11 = getCellNode(tableNode.node, 1, 1)!;

      await editor.updateSelection(
        Selection.single(
          path: cell11.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.enter);

      final selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, editor.nodeAtPath([1])!.path);
      expect(selection.start.offset, 0);
      expect(editor.documentRootLen, 2);
      await editor.dispose();
    });

    testWidgets('backspace on beginning of cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell10 = getCellNode(tableNode.node, 1, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      final selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);
      await editor.dispose();
    });

    testWidgets('backspace joins a newline inside a cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['Hello'],
      ]);
      tableNode.getCell(0, 0).insert(paragraphNode(text: 'There'));
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final second = getCellNode(tableNode.node, 0, 0)!.childAtIndexOrNull(1)!;
      await editor.updateSelection(
        Selection.collapsed(Position(path: second.path)),
      );
      await editor.pressKey(key: LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      final cell = getCellNode(editor.nodeAtPath([0])!, 0, 0)!;
      expect(cell.children, hasLength(1));
      expect(cell.children.single.delta!.toPlainText(), 'HelloThere');
      expect(
        editor.selection,
        Selection.collapsed(
          Position(path: cell.children.single.path, offset: 'Hello'.length),
        ),
      );

      await editor.dispose();
    });

    testWidgets('backspace on multiple cell selection', (tester) async {
      // final tableNode = TableNode.fromList([
      //   ['ab', 'cd'],
      //   ['ef', 'hi']
      // ]);
      // final editor = tester.editor..addNode(tableNode.node);

      // await editor.startTesting();
      // await tester.pumpAndSettle();

      // var cell11 = getCellNode(tableNode.node, 1, 1)!;
      // var cell10 = getCellNode(tableNode.node, 1, 0)!;

      // await editor.updateSelection(
      //   Selection(
      //     start: Position(
      //       path: cell11.childAtIndexOrNull(0)!.path,
      //       offset: 1,
      //     ),
      //     end: Position(
      //       path: cell10.childAtIndexOrNull(0)!.path,
      //       offset: 1,
      //     ),
      //   ),
      // );
      // await editor.pressKey(key: LogicalKeyboardKey.backspace);

      // var selection = editor.selection!;

      // expect(selection.isCollapsed, true);
      // expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      // expect(selection.start.offset, 1);

      // cell11 = getCellNode(tableNode.node, 1, 1)!;
      // cell10 = getCellNode(tableNode.node, 1, 0)!;
      // expect(cell10.childAtIndexOrNull(0)!.delta?.toPlainText(), 'e');
      // expect(cell11.childAtIndexOrNull(0)!.delta?.toPlainText(), 'i');

      // await editor.dispose();
    });

    testWidgets('backspace on cell and after table node selection',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cd'],
        ['ef', 'hi'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);
      editor.addParagraph(initialText: 'Testing');

      await editor.startTesting();
      await tester.pumpAndSettle();

      var cell11 = getCellNode(tableNode.node, 1, 1)!;

      await editor.updateSelection(
        Selection(
          start: Position(
            path: cell11.childAtIndexOrNull(0)!.path,
            offset: 1,
          ),
          end: Position(
            path: editor.document.last!.path,
            offset: 3,
          ),
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.backspace);

      final selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell11.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 1);

      cell11 = getCellNode(tableNode.node, 1, 1)!;
      expect(cell11.childAtIndexOrNull(0)!.delta?.toPlainText(), 'h');
      expect(editor.document.last!.delta?.toPlainText(), 'ting');

      await editor.dispose();
    });

    testWidgets('backspace on whole table in selection', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cd'],
        ['ef', 'hi'],
      ]);
      final editor = tester.editor..addParagraph(initialText: 'Start');
      editor.addNode(tableNode.node);
      editor.addParagraph(initialText: 'Testing');

      await editor.startTesting();
      await tester.pumpAndSettle();

      await editor.updateSelection(
        Selection(
          start: Position(
            path: editor.document.first!.path,
            offset: 1,
          ),
          end: Position(
            path: editor.document.last!.path,
            offset: 3,
          ),
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.backspace);

      final selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, editor.document.first!.path);
      expect(selection.start.offset, 1);

      expect(editor.document.last!.delta?.toPlainText(), 'Sting');

      await editor.dispose();
    });

    testWidgets('up arrow key move to above row with same column',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell01 = getCellNode(tableNode.node, 0, 1)!;
      final cell00 = getCellNode(tableNode.node, 0, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell01.childAtIndexOrNull(0)!.path,
          startOffset: 1,
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowUp);

      var selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell00.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 1);

      await editor.updateSelection(
        Selection.single(
          path: cell01.childAtIndexOrNull(0)!.path,
          startOffset: 3,
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowUp);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell00.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 2);
      await editor.dispose();
    });

    testWidgets('down arrow key move to down row with same column',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['abc', 'de'],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell01 = getCellNode(tableNode.node, 0, 1)!;
      final cell00 = getCellNode(tableNode.node, 0, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 1,
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowDown);

      var selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell01.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 1);

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 3,
        ),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowDown);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell01.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 2);
      await editor.dispose();
    });

    testWidgets('arrowLeft key on beginning of a cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      final cell00 = getCellNode(tableNode.node, 0, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.arrowLeft);

      var selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell00.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 2);

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.arrowLeft);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell00.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      await editor.dispose();
    });

    testWidgets('arrowLeft key on middle of a cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell10 = getCellNode(tableNode.node, 1, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 1,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.arrowLeft);

      final selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      await editor.dispose();
    });

    testWidgets('arrowRight key on beginning of a cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.arrowRight);

      final selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell00.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 1);

      await editor.dispose();
    });

    testWidgets('arrowRight key on end of a cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;
      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      final cell11 = getCellNode(tableNode.node, 1, 1)!;

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 2,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.arrowRight);

      var selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      // right arrow on the last cell leaves the table
      await editor.updateSelection(
        Selection.single(
          path: cell11.childAtIndexOrNull(0)!.path,
          startOffset: 2,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.arrowRight);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, [1]);
      expect(selection.start.offset, 0);
      expect(editor.documentRootLen, 2);

      await editor.dispose();
    });

    testWidgets('arrowRight on the last cell moves to the next block', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final editor = tester.editor
        ..addNode(tableNode.node)
        ..addNode(paragraphNode(text: 'After'));

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell11 = getCellNode(tableNode.node, 1, 1)!;
      await editor.updateSelection(
        Selection.single(
          path: cell11.childAtIndexOrNull(0)!.path,
          startOffset: 2,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.arrowRight);

      final selection = editor.selection!;
      expect(selection.isCollapsed, true);
      expect(selection.start.path, [1]);
      expect(selection.start.offset, 0);
      expect(editor.documentRootLen, 2);
      expect(editor.nodeAtPath([1])!.delta!.toPlainText(), 'After');

      await editor.dispose();
    });

    testWidgets('arrowDown on the bottom row moves to the next block', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final editor = tester.editor
        ..addNode(tableNode.node)
        ..addNode(paragraphNode(text: 'After'));
      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell01 = getCellNode(tableNode.node, 0, 1)!;
      await editor.updateSelection(
        Selection.single(path: cell01.childAtIndexOrNull(0)!.path, startOffset: 1),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowDown);

      expect(editor.selection, Selection.collapsed(Position(path: [1])));
      expect(editor.documentRootLen, 2);
      await editor.dispose();
    });

    testWidgets('arrowDown on the bottom row of a last table opens a line', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final editor = tester.editor
        ..addParagraph(initialText: 'Before')
        ..addNode(tableNode.node);
      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell11 = getCellNode(tableNode.node, 1, 1)!;
      await editor.updateSelection(
        Selection.single(path: cell11.childAtIndexOrNull(0)!.path, startOffset: 0),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowDown);

      expect(editor.documentRootLen, 3);
      expect(editor.nodeAtPath([2])!.type, ParagraphBlockKeys.type);
      expect(editor.selection, Selection.collapsed(Position(path: [2])));
      await editor.dispose();
    });

    testWidgets('arrowUp on the top row moves to the end of the block above', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final editor = tester.editor
        ..addParagraph(initialText: 'Before')
        ..addNode(tableNode.node);
      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      await editor.updateSelection(
        Selection.single(path: cell10.childAtIndexOrNull(0)!.path, startOffset: 1),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowUp);

      expect(
        editor.selection,
        Selection.collapsed(Position(path: [0], offset: 'Before'.length)),
      );
      await editor.dispose();
    });

    testWidgets('arrowUp on the top row of a first table opens a line above', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);
      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;
      await editor.updateSelection(
        Selection.single(path: cell00.childAtIndexOrNull(0)!.path, startOffset: 0),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowUp);

      expect(editor.documentRootLen, 2);
      expect(editor.nodeAtPath([0])!.type, ParagraphBlockKeys.type);
      expect(editor.nodeAtPath([1])!.type, TableBlockKeys.type);
      expect(editor.selection, Selection.collapsed(Position(path: [0])));
      await editor.dispose();
    });

    testWidgets('enter at the start of the first cell text opens a line above', (tester) async {
      final tableNode = TableNode.fromList([
        ['Skill', 'Rank'],
        ['Spot', '50'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);
      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;
      await editor.updateSelection(
        Selection.single(path: cell00.childAtIndexOrNull(0)!.path, startOffset: 0),
      );
      await editor.pressKey(key: LogicalKeyboardKey.enter);

      expect(editor.documentRootLen, 2);
      expect(editor.nodeAtPath([0])!.delta!.toPlainText(), '');
      expect(editor.nodeAtPath([1])!.type, TableBlockKeys.type);
      expect(cell00.children.first.delta!.toPlainText(), 'Skill');
      expect(editor.selection, Selection.collapsed(Position(path: [0])));
      await editor.dispose();
    });

    testWidgets('arrowUp on the second line of a cell stays in the cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final cell01 = tableNode.getCell(0, 1);
      cell01.insert(paragraphNode(text: 'second'));
      final editor = tester.editor
        ..addParagraph(initialText: 'Before')
        ..addNode(tableNode.node);
      await editor.startTesting();
      await tester.pumpAndSettle();

      await editor.updateSelection(
        Selection.single(path: cell01.children[1].path, startOffset: 1),
      );
      await editor.pressKey(key: LogicalKeyboardKey.arrowUp);

      expect(editor.selection!.start.path, cell01.children[0].path);
      await editor.dispose();
    });

    testWidgets('arrows from the text around a table land in its cells', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final editor = tester.editor
        ..addParagraph(initialText: 'Before')
        ..addNode(tableNode.node)
        ..addParagraph(initialText: 'After');
      await editor.startTesting();
      await tester.pumpAndSettle();

      await editor.updateSelection(Selection.collapsed(Position(path: [2], offset: 1)));
      await editor.pressKey(key: LogicalKeyboardKey.arrowUp);
      final up = editor.editorState.getNodeAtPath(editor.selection!.start.path)!;
      expect(up.parent?.type, TableCellBlockKeys.type);

      await editor.updateSelection(Selection.collapsed(Position(path: [0], offset: 1)));
      await editor.pressKey(key: LogicalKeyboardKey.arrowDown);
      final down = editor.editorState.getNodeAtPath(editor.selection!.start.path)!;
      expect(down.parent?.type, TableCellBlockKeys.type);
      await editor.dispose();
    });

    testWidgets('tab key navigates to next cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', 'jk'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;
      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      final cell11 = getCellNode(tableNode.node, 1, 1)!;

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.tab);

      var selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 1,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.tab);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      // tab doesn't navigate when at last cell
      await editor.updateSelection(
        Selection.single(
          path: cell11.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.tab);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell11.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      await editor.dispose();
    });

    testWidgets('shift+tab key navigates to the previous cell', (tester) async {
      final tableNode = TableNode.fromList([
        ['ab', 'cde'],
        ['fghi', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final cell00 = getCellNode(tableNode.node, 0, 0)!;
      final cell01 = getCellNode(tableNode.node, 0, 1)!;
      final cell10 = getCellNode(tableNode.node, 1, 0)!;

      await editor.updateSelection(
        Selection.single(
          path: cell01.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.tab, isShiftPressed: true);

      var selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      await editor.updateSelection(
        Selection.single(
          path: cell01.childAtIndexOrNull(0)!.path,
          startOffset: 1,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.tab, isShiftPressed: true);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell10.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      // shift+tab doesn't navigate when at first cell
      await editor.updateSelection(
        Selection.single(
          path: cell00.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      await editor.pressKey(key: LogicalKeyboardKey.tab, isShiftPressed: true);

      selection = editor.selection!;

      expect(selection.isCollapsed, true);
      expect(selection.start.path, cell00.childAtIndexOrNull(0)!.path);
      expect(selection.start.offset, 0);

      await editor.dispose();
    });
  });
}
