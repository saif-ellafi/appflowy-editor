import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import 'paragraph_navigation.dart';

final List<CommandShortcutEvent> arrowUpKeys = [
  moveCursorUpCommand,
  moveCursorTopSelectCommand,
  moveCursorTopCommand,
  moveParagraphUpCommand,
  moveParagraphUpSelectCommand,
  moveCursorUpSelectCommand,
];

/// Arrow up key events.
///
/// - support
///   - desktop
///   - web
///

// arrow up key
// move the cursor upward vertically
final CommandShortcutEvent moveCursorUpCommand = CommandShortcutEvent(
  key: 'move the cursor upward',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorUp,
  command: 'arrow up',
  handler: _moveCursorUpCommandHandler,
);

CommandShortcutEventHandler _moveCursorUpCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final upPosition = selection.end.moveVertical(editorState);
  editorState.updateSelectionWithReason(
    upPosition == null ? null : Selection.collapsed(upPosition),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// Cmd+Shift+Up on macOS: select to the start of the document.
/// Windows and Linux use Ctrl+Shift+Home for that, and Ctrl+Shift+Up for a paragraph.
final CommandShortcutEvent moveCursorTopSelectCommand = CommandShortcutEvent(
  key: 'move cursor to start of file and select all',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorTopSelect,
  command: '',
  macOSCommand: 'cmd+shift+arrow up',
  handler: _moveCursorTopSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorTopSelectCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final result = editorState.getFirstSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.start(result.$1);
  editorState.scrollService?.jumpToTop();
  editorState.updateSelectionWithReason(
    selection.copyWith(end: position),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// Cmd+Up on macOS: move the caret to the start of the document.
/// Windows and Linux use Ctrl+Home for that, and Ctrl+Up for a paragraph.
final CommandShortcutEvent moveCursorTopCommand = CommandShortcutEvent(
  key: 'move cursor to start of file',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorTop,
  command: '',
  macOSCommand: 'cmd+arrow up',
  handler: _moveCursorTopCommandHandler,
);

/// Ctrl+Up, or Option+Up on macOS: the previous paragraph.
final CommandShortcutEvent moveParagraphUpCommand = CommandShortcutEvent(
  key: 'move cursor to the previous paragraph',
  getDescription: () => 'move cursor to the previous paragraph',
  command: 'ctrl+arrow up',
  macOSCommand: 'alt+arrow up',
  handler: (editorState) => moveByParagraph(editorState, up: true, extend: false),
);

/// Ctrl+Shift+Up, or Option+Shift+Up on macOS: extend the selection by one paragraph.
final CommandShortcutEvent moveParagraphUpSelectCommand = CommandShortcutEvent(
  key: 'select the previous paragraph',
  getDescription: () => 'select the previous paragraph',
  command: 'ctrl+shift+arrow up',
  macOSCommand: 'alt+shift+arrow up',
  handler: (editorState) => moveByParagraph(editorState, up: true, extend: true),
);

CommandShortcutEventHandler _moveCursorTopCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  final result = editorState.getFirstSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }

  final position = result.$2.start(result.$1);
  editorState.scrollService?.jumpToTop();
  editorState.updateSelectionWithReason(
    Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};

/// arrow up + ctrl or cmd
/// moves vertically down one line and selects everything between
final CommandShortcutEvent moveCursorUpSelectCommand = CommandShortcutEvent(
  key: 'move cursor up and select one line',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorUpSelect,
  command: 'shift+arrow up',
  macOSCommand: 'shift+arrow up',
  handler: _moveCursorUpSelectCommandHandler,
);

CommandShortcutEventHandler _moveCursorUpSelectCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final end = selection.end.moveVertical(editorState);
  if (end == null) {
    return KeyEventResult.ignored;
  }
  editorState.updateSelectionWithReason(
    selection.copyWith(end: end),
    reason: SelectionUpdateReason.uiEvent,
  );

  return KeyEventResult.handled;
};
