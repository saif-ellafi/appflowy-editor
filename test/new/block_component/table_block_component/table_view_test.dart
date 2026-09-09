import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/testable_editor.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('table_view.dart', () {
    testWidgets('row height stays put for short single-line text', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final row0beforeHeight = tableNode.getRowHeight(0);
      final row1beforeHeight = tableNode.getRowHeight(1);
      expect(row0beforeHeight, row1beforeHeight);

      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.ime.insertText('aaa');
      await tester.pumpAndSettle();

      final transaction = editor.editorState.transaction;
      tableNode.updateRowHeight(0, transaction: transaction);
      await editor.editorState.apply(transaction);

      expect(tableNode.getRowHeight(0), row0beforeHeight);
      expect(
        tableNode.getRowHeight(0),
        cell10.children.first.rect.height + tableCellHeightPadding,
      );
      expect(tableNode.getRowHeight(1), row1beforeHeight);
      await editor.dispose();
    });

    testWidgets('middle row grows when a newline paragraph is inserted',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['top', 'mid', 'bot'],
        ['top', 'mid', 'bot'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final middle = getCellNode(tableNode.node, 0, 1)!;
      final before = tableNode.getRowHeight(1);
      await editor.updateSelection(
        Selection.single(
          path: middle.children.first.path,
          startOffset: middle.children.first.delta!.length,
        ),
      );
      await editor.editorState.insertNewLine();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(middle.children.length, greaterThan(1));
      expect(tableNode.getRowHeight(1), greaterThan(before));
      await editor.dispose();
    });

    testWidgets('wrapping long text grows the row height', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final before = tableNode.getRowHeight(0);
      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.ime.insertText(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(tableNode.getRowHeight(0), greaterThan(before));
      await editor.dispose();
    });

    testWidgets('widening a column can shrink a wrapped row back', (tester) async {
      final tableNode = TableNode.fromList([
        ['', ''],
        ['', ''],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting();
      await tester.pumpAndSettle();

      final row0beforeHeight = tableNode.getRowHeight(0);

      final cell10 = getCellNode(tableNode.node, 1, 0)!;
      await editor.updateSelection(
        Selection.single(
          path: cell10.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
      await editor.ime.insertText('aaaaaaaaa');

      Transaction transaction = editor.editorState.transaction;
      tableNode.updateRowHeight(0, transaction: transaction);
      await editor.editorState.apply(transaction);
      await tester.pumpAndSettle();

      // With current cell padding this short string may already wrap once.
      transaction = editor.editorState.transaction;
      tableNode.setColWidth(1, 302.5, transaction: transaction);
      await editor.editorState.apply(transaction);

      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(tableNode.getRowHeight(0), row0beforeHeight);
      await editor.dispose();
    });
  });
}
