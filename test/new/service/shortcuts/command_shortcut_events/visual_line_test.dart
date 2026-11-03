import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infra/testable_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home and end stop at the wrapped row', (tester) async {
    final text = List.filled(80, 'alpha').join(' ');
    final editor = tester.editor..addParagraph(initialText: text);
    await editor.startTesting();

    final selectable = editor.nodeAtPath([0])!.selectable!;
    final first = selectable.getLineBoundaryInPosition(Position(path: [0]))!;
    expect(first.end, lessThan(text.length),
        reason: 'the paragraph did not wrap');
    final second = selectable
        .getLineBoundaryInPosition(Position(path: [0], offset: first.end))!;
    expect(second.start, greaterThan(0));
    expect(second.end, greaterThan(second.start));
    final middle = second.start + (second.end - second.start) ~/ 2;

    await editor.updateSelection(
        Selection.collapsed(Position(path: [0], offset: middle)));
    await editor.pressKey(key: LogicalKeyboardKey.home);
    expect(editor.selection,
        Selection.collapsed(Position(path: [0], offset: second.start)));

    // The row's last offset is also where the next row starts, so End stops one earlier.
    await editor.pressKey(key: LogicalKeyboardKey.end);
    expect(editor.selection,
        Selection.collapsed(Position(path: [0], offset: second.end - 1)));
    final rowTop = selectable
        .getCursorRectInPosition(Position(path: [0], offset: second.start))!
        .top;
    expect(
        selectable.getCursorRectInPosition(editor.selection!.end)!.top, rowTop);

    // Repeating End or going Home stays on the same row.
    await editor.pressKey(key: LogicalKeyboardKey.end);
    expect(editor.selection,
        Selection.collapsed(Position(path: [0], offset: second.end - 1)));
    await editor.pressKey(key: LogicalKeyboardKey.home);
    expect(editor.selection,
        Selection.collapsed(Position(path: [0], offset: second.start)));

    await editor.updateSelection(
        Selection.collapsed(Position(path: [0], offset: middle)));
    await editor.pressKey(key: LogicalKeyboardKey.home, isShiftPressed: true);
    expect(
      editor.selection,
      Selection(
        start: Position(path: [0], offset: middle),
        end: Position(path: [0], offset: second.start),
      ),
    );

    await editor.dispose();
  });
}
