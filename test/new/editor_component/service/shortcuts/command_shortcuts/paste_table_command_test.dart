import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../infra/testable_editor.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('paste table nodes', () {
    testWidgets('paste table into a cell flattens to text, not a nested table',
        (tester) async {
      final host = TableNode.fromList([
        ['keep'],
      ]);
      final editor = tester.editor..addNode(host.node);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [0, 0, 0])),
      );

      await editor.editorState.pasteSingleLineNode(
        TableNode.fromList([
          ['A', 'B'],
          ['1', '2'],
        ]).node,
      );
      await tester.pumpAndSettle();

      final cell = editor.nodeAtPath([0, 0])!;
      expect(cell.type, TableCellBlockKeys.type);
      expect(cell.children, hasLength(1));
      expect(cell.children.first.type, ParagraphBlockKeys.type);
      expect(editor.nodeAtPath([0])!.type, TableBlockKeys.type);
      expect(
        cell.children.first.delta!.toPlainText().contains('keep'),
        isTrue,
      );
      expect(
        cell.children.first.delta!.toPlainText().contains('|'),
        isTrue,
      );

      await editor.dispose();
    });

    testWidgets('paste table splits the host paragraph at the caret',
        (tester) async {
      const text = 'Hello World';
      final editor = tester.editor..addParagraph(initialText: text);
      await editor.startTesting();
      await editor.updateSelection(
        Selection.collapsed(Position(path: [0], offset: 5)),
      );

      await editor.editorState.pasteSingleLineNode(
        TableNode.fromList([
          ['A'],
          ['1'],
        ]).node,
      );
      await tester.pumpAndSettle();

      expect(editor.nodeAtPath([0])!.delta!.toPlainText(), 'Hello');
      expect(editor.nodeAtPath([1])!.type, TableBlockKeys.type);
      expect(editor.nodeAtPath([2])!.delta!.toPlainText(), ' World');
      expect(
        editor.editorState.selection,
        Selection.collapsed(Position(path: [2])),
      );

      await editor.dispose();
    });
  });
}
