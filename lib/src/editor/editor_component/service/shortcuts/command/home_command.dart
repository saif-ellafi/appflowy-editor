import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Home key event.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent homeCommand = CommandShortcutEvent(
  key: 'go to the top of the document',
  getDescription: () => AppFlowyEditorL10n.current.cmdScrollToTop,
  command: 'ctrl+home',
  macOSCommand: 'home',
  handler: _homeCommandHandler,
);

CommandShortcutEventHandler _homeCommandHandler = (editorState) {
  final root = editorState.document.root;
  if (root.children.isEmpty) {
    return KeyEventResult.ignored;
  }

  // Move caret to the very first block, offset 0
  final first = root.children.first;
  editorState.updateSelectionWithReason(
    Selection(
      start: Position(path: first.path, offset: 0),
      end: Position(path: first.path, offset: 0),
    ),
  );

  // Optionally still scroll to top so the caret is visible:
  final scrollService = editorState.service.scrollService;
  if (scrollService != null) {
    scrollService.scrollTo(
      scrollService.minScrollExtent,
      duration: const Duration(milliseconds: 150),
    );
  }


  return KeyEventResult.handled;
};

/// Ctrl+Shift+Home: select from the caret to the start of the document.
final CommandShortcutEvent selectToDocumentStartCommand = CommandShortcutEvent(
  key: 'select to the start of the document',
  getDescription: () => AppFlowyEditorL10n.current.cmdMoveCursorTopSelect,
  command: 'ctrl+shift+home',
  handler: _selectToDocumentStartCommandHandler,
);

CommandShortcutEventHandler _selectToDocumentStartCommandHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  final result = editorState.getFirstSelectable();
  if (result == null) {
    return KeyEventResult.ignored;
  }
  editorState.scrollService?.jumpToTop();
  editorState.updateSelectionWithReason(
    selection.copyWith(end: result.$2.start(result.$1)),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
};