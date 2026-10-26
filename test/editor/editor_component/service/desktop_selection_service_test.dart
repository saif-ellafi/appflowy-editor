import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helper.dart';

void main() {
  group('DesktopSelectionServiceWidget', () {
    testWidgets(
      'does not crash when selection is cleared before metric debounce fires',
      (tester) async {
        final editorState = EditorState(document: Document.blank());

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        tester.view.devicePixelRatio = 1.0;

        await tester.buildAndPump(
          AppFlowyEditor(
            editorState: editorState,
          ),
        );

        editorState.selectionService.updateSelection(
          Selection.collapsed(Position(path: [0])),
        );
        await tester.pump();

        tester.view.physicalSize = const Size(1600, 1200);
        await tester.pump();

        editorState.selection = null;
        await tester.pump(const Duration(milliseconds: 101));

        expect(tester.takeException(), isNull);
        expect(editorState.selectionService.currentSelection.value, isNull);
      },
    );

    testWidgets(
      'click below a trailing table opens a paragraph',
      (tester) async {
        final table = TableNode.fromList([
          ['Cell'],
        ]);
        final editorState = EditorState(
          document: Document.blank()..insert([0], [table.node]),
        );

        await tester.buildAndPump(
          AppFlowyEditor(
            editorState: editorState,
          ),
        );
        await tester.pumpAndSettle();

        final box = tester.renderObject<RenderBox>(
          find.byType(TableBlockComponentWidget),
        );
        final below = box.localToGlobal(
          Offset(box.size.width / 2, box.size.height + 24),
        );
        await tester.tapAt(below);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final children = editorState.document.root.children;
        expect(children.length, 2);
        expect(children.last.type, ParagraphBlockKeys.type);
        expect(
          editorState.selection,
          Selection.collapsed(Position(path: [1])),
        );
      },
    );

    testWidgets(
      'click on a trailing table does not insert a paragraph',
      (tester) async {
        final table = TableNode.fromList([
          ['Cell'],
        ]);
        final editorState = EditorState(
          document: Document.blank()..insert([0], [table.node]),
        );

        await tester.buildAndPump(
          AppFlowyEditor(
            editorState: editorState,
          ),
        );
        await tester.pumpAndSettle();

        final box = tester.renderObject<RenderBox>(
          find.byType(TableBlockComponentWidget),
        );
        await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
        await tester.pump();

        expect(editorState.document.root.children.length, 1);
        expect(
          editorState.document.root.children.single.type,
          TableBlockKeys.type,
        );
      },
    );
  });
}
