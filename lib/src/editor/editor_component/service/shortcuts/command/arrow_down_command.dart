import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import 'paragraph_navigation.dart';

final List<CommandShortcutEvent> arrowDownKeys = [
  moveCursorDownCommand,
  moveCursorBottomSelectCommand,
  moveCursorBottomCommand,
  moveParagraphDownCommand,
  moveParagraphDownSelectCommand,
  moveCursorDownSelectCommand,
];

/// Arrow down key events.
///
/// - support
///   - desktop
///   - web
///

// arrow down key
// move the cursor downward vertically
final CommandShortcutEvent moveCursorDownCommand = CommandShortcutEvent(
  key: 'move the cursor downward',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorDown,
  command: 'arrow down',
  handler: _moveCursorDownCommandHandler,
);

CommandShortcutEventHandler _moveCursorDownCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final downPosition = selection.end.moveVertical(editorState, upwards: false);
  editorState.updateSelectionWithReason(
    downPosition == null ? null : Selection.collapsed(downPosition),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// Cmd+Shift+Down on macOS: select to the end of the document.
/// Windows and Linux use Ctrl+Shift+End for that, and Ctrl+Shift+Down for a paragraph.
CommandShortcutEvent moveCursorBottomSelectCommand = CommandShortcutEvent(
  key: 'move cursor to end of file and select all',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorBottomSelect,
  command: '',
  macOSCommand: 'cmd+shift+arrow down',
  handler: _moveCursorBottomSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorBottomSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final result = editorState.getLastSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.end(result.$1);
  editorState.scrollService?.jumpToBottom();
  editorState.updateSelectionWithReason(
    selection.copyWith(end: position),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// Cmd+Down on macOS: move the caret to the end of the document.
/// Windows and Linux use Ctrl+End for that, and Ctrl+Down for a paragraph.
CommandShortcutEvent moveCursorBottomCommand = CommandShortcutEvent(
  key: 'move cursor to end of file',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorBottom,
  command: '',
  macOSCommand: 'cmd+arrow down',
  handler: _moveCursorBottomCommandHandler,
);

/// Ctrl+Down, or Option+Down on macOS: the next paragraph.
CommandShortcutEvent moveParagraphDownCommand = CommandShortcutEvent(
  key: 'move cursor to the next paragraph',
  getDescription: () => 'move cursor to the next paragraph',
  command: 'ctrl+arrow down',
  macOSCommand: 'alt+arrow down',
  handler: (editorState) => moveByParagraph(editorState, up: false, extend: false),
);

/// Ctrl+Shift+Down, or Option+Shift+Down on macOS: extend the selection by one paragraph.
CommandShortcutEvent moveParagraphDownSelectCommand = CommandShortcutEvent(
  key: 'select the next paragraph',
  getDescription: () => 'select the next paragraph',
  command: 'ctrl+shift+arrow down',
  macOSCommand: 'alt+shift+arrow down',
  handler: (editorState) => moveByParagraph(editorState, up: false, extend: true),
);

CommandShortcutEventHandler _moveCursorBottomCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final result = editorState.getLastSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.end(result.$1);
  editorState.scrollService?.jumpToBottom();
  editorState.updateSelectionWithReason(
    Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// arrow down + shift
/// moves vertically down one line and selects everything between
CommandShortcutEvent moveCursorDownSelectCommand = CommandShortcutEvent(
  key: 'move cursor down and select one line',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorDownSelect,
  command: 'shift+arrow down',
  macOSCommand: 'shift+arrow down',
  handler: _moveCursorDownSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorDownSelectCommandHandler =
    (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final end = selection.end.moveVertical(editorState, upwards: false);
  if (end == null) {
    return KeyEventResult.ignored;
  }
  editorState.updateSelectionWithReason(
    selection.copyWith(end: end),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};
