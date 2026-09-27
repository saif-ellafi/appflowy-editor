import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/delta_input_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../new/infra/testable_editor.dart';

void main() {
  group('onNonTextUpdate', () {
    // Pro-performa test
    test('call', () async {
      await onNonTextUpdate(
        const TextEditingDeltaNonTextUpdate(
          oldText: 'AppFlowy',
          selection: TextSelection(baseOffset: 0, extentOffset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
        EditorState.blank(),
        [],
      );
    });

    testWidgets('handles Android IME select all as document select all',
        (tester) async {
      const text = 'AppFlowy';
      final editor = tester.editor..addParagraphs(3, initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [1], offset: 3)),
      );
      final oldText = List.filled(3, text).join('\n');

      final handled = await handleAndroidNonTextUpdate(
        TextEditingDeltaNonTextUpdate(
          oldText: oldText,
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: oldText.length,
          ),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );

      expect(handled, true);
      expect(
        editor.selection,
        Selection(
          start: Position(path: [0]),
          end: Position(path: [2], offset: text.length),
        ),
      );
      expect(
        editor.editorState.selectionUpdateReason,
        SelectionUpdateReason.selectAll,
      );

      await editor.dispose();
    });

    testWidgets(
        'keeps a full-paragraph Android IME swipe inside that paragraph',
        (tester) async {
      const text = 'AppFlowy';
      final editor = tester.editor..addParagraphs(3, initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [1], offset: text.length)),
      );

      final handled = await _handleAndroidNonTextUpdate(
        tester,
        const TextEditingDeltaNonTextUpdate(
          oldText: text,
          selection: TextSelection(baseOffset: 8, extentOffset: 0),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );

      expect(handled, true);
      expect(
        editor.selection,
        Selection(
          start: Position(path: [1], offset: 8),
          end: Position(path: [1], offset: 0),
        ),
      );
      expect(
        editor.editorState.selectionUpdateReason,
        isNot(SelectionUpdateReason.selectAll),
      );
      expect(editor.nodeAtPath([0])?.delta?.toPlainText(), text);
      expect(editor.nodeAtPath([2])?.delta?.toPlainText(), text);

      await onDelete(
        const TextEditingDeltaDeletion(
          oldText: text,
          deletedRange: TextRange(start: 0, end: 8),
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );

      expect(editor.nodeAtPath([0])?.delta?.toPlainText(), text);
      expect(editor.nodeAtPath([1])?.delta?.toPlainText(), '');
      expect(editor.nodeAtPath([2])?.delta?.toPlainText(), text);

      await editor.dispose();
    });

    testWidgets(
        'applies Android IME range from Gboard backspace swipe-to-delete',
        (tester) async {
      const text = 'Hello world';
      final editor = tester.editor..addParagraph(initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [0], offset: text.length)),
      );

      final handled = await _handleAndroidNonTextUpdate(
        tester,
        const TextEditingDeltaNonTextUpdate(
          oldText: text,
          // Swipe left from the caret over "world".
          selection: TextSelection(baseOffset: 11, extentOffset: 6),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );

      expect(handled, true);
      expect(
        editor.selection,
        Selection(
          start: Position(path: [0], offset: 11),
          end: Position(path: [0], offset: 6),
        ),
      );
      expect(editor.selection!.isCollapsed, false);

      await editor.dispose();
    });

    testWidgets(
        'applies Android IME range when only the extent moves from the caret',
        (tester) async {
      const text = 'Hello world';
      final editor = tester.editor..addParagraph(initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [0], offset: 6)),
      );

      final handled = await _handleAndroidNonTextUpdate(
        tester,
        const TextEditingDeltaNonTextUpdate(
          oldText: text,
          // start stays at the caret; extent expands forward.
          selection: TextSelection(baseOffset: 6, extentOffset: 11),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );

      expect(handled, true);
      expect(
        editor.selection,
        Selection(
          start: Position(path: [0], offset: 6),
          end: Position(path: [0], offset: 11),
        ),
      );

      await editor.dispose();
    });

    testWidgets('keeps Android IME collapsed caret movement', (tester) async {
      const text = 'Hello world';
      final editor = tester.editor..addParagraph(initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [0], offset: 11)),
      );

      final handled = await _handleAndroidNonTextUpdate(
        tester,
        const TextEditingDeltaNonTextUpdate(
          oldText: text,
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );

      expect(handled, true);
      expect(
        editor.selection,
        Selection.collapsed(Position(path: [0], offset: 6)),
      );

      await editor.dispose();
    });

    testWidgets('deletes the Android IME swipe-to-delete selection',
        (tester) async {
      const text = 'Hello world';
      final editor = tester.editor..addParagraph(initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [0], offset: text.length)),
      );

      await _handleAndroidNonTextUpdate(
        tester,
        const TextEditingDeltaNonTextUpdate(
          oldText: text,
          selection: TextSelection(baseOffset: 11, extentOffset: 6),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );
      await onDelete(
        const TextEditingDeltaDeletion(
          oldText: text,
          deletedRange: TextRange(start: 6, end: 11),
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange.empty,
        ),
        editor.editorState,
      );

      expect(
        editor.nodeAtPath([0])?.delta?.toPlainText(),
        'Hello ',
      );
      expect(
        editor.selection,
        Selection.collapsed(Position(path: [0], offset: 6)),
      );

      await editor.dispose();
    });
  });
}

Future<bool> _handleAndroidNonTextUpdate(
  WidgetTester tester,
  TextEditingDeltaNonTextUpdate nonTextUpdate,
  EditorState editorState,
) async {
  final handled = handleAndroidNonTextUpdate(nonTextUpdate, editorState);
  await tester.pump();
  return handled;
}
