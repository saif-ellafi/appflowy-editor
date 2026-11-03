import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infra/testable_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ctrl+up and ctrl+down step one paragraph', (tester) async {
    const lines = ['one', 'two', 'three'];
    final editor = tester.editor
      ..addParagraph(initialText: lines[0])
      ..addParagraph(initialText: lines[1])
      ..addParagraph(initialText: lines[2]);
    await editor.startTesting();
    await editor.updateSelection(Selection.collapsed(Position(path: [1], offset: 2)));

    await _paragraph(editor, up: true);
    expect(editor.selection, Selection.collapsed(Position(path: [1])));

    await _paragraph(editor, up: true);
    expect(editor.selection, Selection.collapsed(Position(path: [0])));

    await _paragraph(editor, up: false);
    expect(editor.selection, Selection.collapsed(Position(path: [1])));

    await _paragraph(editor, up: false);
    expect(editor.selection, Selection.collapsed(Position(path: [2])));

    await editor.updateSelection(Selection.collapsed(Position(path: [1], offset: 2)));
    await _paragraph(editor, up: false, shift: true);
    expect(
      editor.selection,
      Selection(
        start: Position(path: [1], offset: 2),
        end: Position(path: [2]),
      ),
    );

    await editor.dispose();
  });

  testWidgets('shift+page down selects to the end when the page already shows it', (tester) async {
    const text = 'Hello';
    final editor = tester.editor..addParagraphs(3, initialText: text);
    await editor.startTesting();
    final selection = Selection.collapsed(Position(path: [1], offset: 1));
    await editor.updateSelection(selection);

    await editor.pressKey(
      key: LogicalKeyboardKey.pageDown,
      isShiftPressed: true,
    );

    expect(
      editor.selection,
      selection.copyWith(end: Position(path: [2], offset: text.length)),
    );
    await editor.dispose();
  });
}

Future<void> _paragraph(TestableEditor editor, {required bool up, bool shift = false}) {
  return editor.pressKey(
    key: up ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowDown,
    isShiftPressed: shift,
    isControlPressed: !Platform.isMacOS,
    isAltPressed: Platform.isMacOS,
  );
}
