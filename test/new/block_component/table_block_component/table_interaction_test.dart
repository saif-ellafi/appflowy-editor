import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_action_handler.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_action_menu.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_interaction.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/testable_editor.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> activateTable(
    TestableEditor editor,
    TableNode tableNode, {
    int col = 0,
    int row = 0,
  }) async {
    final cell = tableNode.getCell(col, row);
    await editor.updateSelection(
      Selection.single(
        path: cell.children.first.path,
        startOffset: 0,
      ),
    );
  }

  group('TableInteractionController', () {
    test('preview width is clamped to the minimum', () {
      final controller = TableInteractionController();
      controller.beginResize(0, 160);
      controller.updatePreview(10, minWidth: 40);
      expect(controller.previewWidth, 40);
      expect(controller.atMinWidth, isTrue);
      controller.endResize();
      expect(controller.isResizing, isFalse);
    });

    test('setCaret tracks the active cell', () {
      final controller = TableInteractionController();
      expect(controller.isActive, isFalse);
      controller.setCaret(inTable: true, col: 1, row: 2);
      expect(controller.isActive, isTrue);
      expect(controller.activeCol, 1);
      expect(controller.activeRow, 2);
      controller.setActive(false);
      expect(controller.isActive, isFalse);
      expect(controller.activeCol, isNull);
    });
  });

  group('table action menu placement', () {
    test('flips above when keyboard steals space below', () {
      final placement = debugPlaceTableActionMenu(
        anchor: const Rect.fromLTWH(20, 500, 24, 14),
        menuSize: const Size(200, 230),
        viewport: const Size(400, 800),
        keyboardInset: 320,
      );
      expect(placement.top, isNull);
      expect(placement.bottom, isNotNull);
    });

    test('stays below when there is room above the keyboard', () {
      final placement = debugPlaceTableActionMenu(
        anchor: const Rect.fromLTWH(20, 80, 24, 14),
        menuSize: const Size(200, 230),
        viewport: const Size(400, 800),
        keyboardInset: 0,
      );
      expect(placement.top, isNotNull);
      expect(placement.bottom, isNull);
      expect(placement.top, greaterThan(80));
    });
  });

  group('table interaction', () {
    testWidgets('desktop tables keep add controls and 12px resize overlays',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('table_col_resize_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('table_col_resize_1')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('table_col_resize_0'))).width,
        tableDesktopResizeHitWidth,
      );
      expect(find.byKey(const ValueKey('table_add_column')), findsOneWidget);
      expect(find.byKey(const ValueKey('table_add_row')), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byType(TableBorderHandle), findsNothing);

      await editor.dispose();
    });

    testWidgets('selecting a cell shows add buttons and row/column handles',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode, col: 1, row: 0);

      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.byType(TableBorderHandle), findsNWidgets(2));
      expect(find.byKey(const ValueKey('table_structure_toggle')), findsNothing);

      await editor.dispose();
    });

    testWidgets('add-column button inserts a column once the table is selected',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode);

      expect(tableNode.colsLen, 2);
      await tester.ensureVisible(find.byKey(const ValueKey('table_add_column')));
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('table_add_column')),
          matching: find.byType(Icon),
        ),
      );
      await tester.pumpAndSettle();
      expect(TableNode(node: tableNode.node).colsLen, 3);

      await editor.dispose();
    });

    testWidgets('activating the table does not shift the grid', (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();

      final table = find.byType(TableView);
      final before = tester.getTopLeft(table);
      final sizeBefore = tester.getSize(table);

      await activateTable(editor, tableNode);

      expect(tester.getTopLeft(table), before);
      expect(tester.getSize(table), sizeBefore);

      await editor.dispose();
    });

    testWidgets('resize previews without mutating, then commits once',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);
      editor.editorState.disableSealTimer = true;

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode);

      final original = tableNode.getColWidth(0);
      final handle = find.byKey(const ValueKey('table_col_resize_0'));
      expect(handle, findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      expect(tableNode.getColWidth(0), original);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(tableNode.getColWidth(0), closeTo(original + 50, 1));
      await editor.dispose();
    });

    testWidgets('dragging a divider shows a width tooltip', (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode);

      final handle = find.byKey(const ValueKey('table_col_resize_0'));
      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();

      expect(find.textContaining('px'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.textContaining('px'), findsNothing);
      await editor.dispose();
    });

    testWidgets('one undo reverses one resize', (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);
      editor.editorState.disableSealTimer = true;

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode);

      if (editor.editorState.undoManager.undoStack.isNonEmpty) {
        editor.editorState.undoManager.undoStack.last.seal();
      }

      final original = tableNode.getColWidth(0);
      final handle = find.byKey(const ValueKey('table_col_resize_0'));

      await tester.drag(
        handle,
        const Offset(40, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(tableNode.getColWidth(0), closeTo(original + 40, 1));

      editor.editorState.undoManager.undo();
      await tester.pumpAndSettle();

      expect(tableNode.getColWidth(0), closeTo(original, 1));
      await editor.dispose();
    });

    testWidgets('escape cancels an in-progress resize', (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode);

      final original = tableNode.getColWidth(0);
      final handle = find.byKey(const ValueKey('table_col_resize_0'));

      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await simulateKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tableNode.getColWidth(0), original);
      await editor.dispose();
    });

    testWidgets('resize cannot go below the minimum width', (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode);

      final handle = find.byKey(const ValueKey('table_col_resize_0'));
      await tester.drag(
        handle,
        const Offset(-400, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(
        tableNode.getColWidth(0),
        tableNode.config.colMinimumWidth,
      );
      await editor.dispose();
    });

    testWidgets('divider layout width stays at borderWidth', (tester) async {
      final tableNode = TableNode.fromList([
        ['a'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();

      final border = find.byKey(const ValueKey('table_col_border_0_resizable'));
      expect(tester.getSize(border).width, tableNode.config.borderWidth);

      await activateTable(editor, tableNode);

      expect(tester.getSize(border).width, tableNode.config.borderWidth);
      expect(
        tester.getSize(find.byKey(const ValueKey('table_col_resize_0'))).width,
        tableDesktopResizeHitWidth,
      );

      await editor.dispose();
    });

    testWidgets('mobile editing shows controls and wide resize overlays',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'c'],
        ['b', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.android);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('table_col_resize_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('table_col_resize_1')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('table_col_resize_0'))).width,
        tableMobileResizeHitWidth,
      );
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byType(TableBorderHandle), findsNothing);

      await activateTable(editor, tableNode);

      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.byType(TableBorderHandle), findsNWidgets(2));
      expect(find.byKey(const ValueKey('table_structure_toggle')), findsNothing);

      // Visible oval stays compact; hit box is 44px for fat fingers.
      final rowHandle = find.byKey(const ValueKey('table_row_menu_0_0'));
      expect(tester.getSize(rowHandle).width, tableMobileHandleHitThickness);
      expect(
        tester
            .getSize(
              find.descendant(
                of: rowHandle,
                matching: find.byType(TableBorderHandle),
              ),
            )
            .width,
        tableMobileHandleOvalThickness,
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byKey(const ValueKey('table_col_menu_0')),
            matching: find.byType(TableBorderHandle),
          ),
        ),
        const Size(
          tableMobileHandleOvalLength,
          tableMobileHandleOvalThickness,
        ),
      );

      await tester.tap(rowHandle);
      await tester.pumpAndSettle();
      // Positional popup near the handle (not a bottom sheet).
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byIcon(Icons.delete), findsOneWidget);

      final border = find.byKey(const ValueKey('table_col_border_0_resizable'));
      expect(tester.getSize(border).width, tableNode.config.borderWidth);

      await editor.dispose();
    });

    testWidgets('mobile touch drag resizes a column', (tester) async {
      final tableNode = TableNode.fromList([
        ['a', 'c'],
        ['b', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);
      editor.editorState.disableSealTimer = true;

      await editor.startTesting(platform: TargetPlatform.android);
      await tester.pumpAndSettle();

      final original = tableNode.getColWidth(0);
      final handle = find.byKey(const ValueKey('table_col_resize_0'));
      await tester.drag(
        handle,
        const Offset(50, 0),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();

      expect(tableNode.getColWidth(0), closeTo(original + 50, 1));
      await editor.dispose();
    });

    testWidgets('cancelled resize does not persist preview row heights',
        (tester) async {
      final tableNode = TableNode.fromList([
        ['aaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'b'],
        ['c', 'd'],
      ]);
      final editor = tester.editor..addNode(tableNode.node);

      await editor.startTesting(platform: TargetPlatform.windows);
      await tester.pumpAndSettle();
      await activateTable(editor, tableNode);

      final originalHeight = tableNode.getRowHeight(0);
      final originalWidth = tableNode.getColWidth(0);
      final handle = find.byKey(const ValueKey('table_col_resize_0'));

      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();

      expect(tableNode.getColWidth(0), originalWidth);
      expect(tableNode.getRowHeight(0), originalHeight);

      await simulateKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tableNode.getColWidth(0), originalWidth);
      expect(tableNode.getRowHeight(0), originalHeight);
      await editor.dispose();
    });
  });
}
