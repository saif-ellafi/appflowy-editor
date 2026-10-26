import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter/services.dart';

/// insert a new line block
///
/// - support
///   - desktop
///   - mobile
///   - web
///
final CharacterShortcutEvent insertNewLine = CharacterShortcutEvent(
  key: 'insert a new line',
  character: '\n',
  handler: _insertNewLineHandler,
);

CharacterShortcutEventHandler _insertNewLineHandler = (editorState) async {
  final selection = editorState.selection?.normalized;
  if (selection == null) {
    return false;
  }

  // on desktop or web, shift + enter to insert a '\n' character to the same line.
  // so, we should return the false to let the system handle it.
  if (PlatformExtension.isNotMobile &&
      HardwareKeyboard.instance.isShiftPressed) {
    return false;
  }

  // The mobile key is labeled newline. Inside a cell that is a line break in
  // the cell, the same as Shift+Enter on desktop, so backspace removes it.
  if (PlatformExtension.isMobile) {
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node?.parent?.type == TableCellBlockKeys.type) {
      // At the very start of the table, it opens a line above instead.
      return openLineAboveTable(editorState);
    }
  }

  // delete the selection
  await editorState.deleteSelection(selection);
  // insert a new line
  await editorState.insertNewLine(position: selection.start);

  return true;
};
