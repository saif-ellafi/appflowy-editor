import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// End key event.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent endCommand = CommandShortcutEvent(
  key: 'go to the bottom of the document',
  getDescription: () => AppFlowyEditorL10n.current.cmdScrollToBottom,
  command: 'ctrl+end',
  macOSCommand: 'end',
  handler: _endCommandHandler,
);

CommandShortcutEventHandler _endCommandHandler = (editorState) {
  final root = editorState.document.root;
  if (root.children.isEmpty) {
    return KeyEventResult.ignored;
  }

  // Move caret to the very end of the last block
  final last = root.children.last;
  final textLength = last.delta?.toPlainText().length ?? 0;

  editorState.updateSelectionWithReason(
    Selection(
      start: Position(path: last.path, offset: textLength),
      end: Position(path: last.path, offset: textLength),
    ),
  );

  // Optionally scroll to bottom so the caret is visible
  final scrollService = editorState.service.scrollService;
  if (scrollService != null) {
    scrollService.scrollTo(
      scrollService.maxScrollExtent,
      duration: const Duration(milliseconds: 150),
    );
  }


  return KeyEventResult.handled;
};