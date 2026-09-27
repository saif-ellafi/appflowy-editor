import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> onNonTextUpdate(
  TextEditingDeltaNonTextUpdate nonTextUpdate,
  EditorState editorState,
  List<CharacterShortcutEvent> characterShortcutEvents,
) async {
  AppFlowyEditorLog.input.debug('onNonTextUpdate: $nonTextUpdate');

  // update the selection on Windows
  //
  // when typing characters with CJK IME on Windows, a non-text update is sent
  // with the selection range.
  final selection = editorState.selection;

  if (await _checkIfBacktickPressed(editorState, nonTextUpdate)) {
    return;
  }

  if (PlatformExtension.isWindows) {
    if (selection != null &&
        nonTextUpdate.composing == TextRange.empty &&
        nonTextUpdate.selection.isCollapsed) {
      editorState.selection = Selection.collapsed(
        Position(
          path: selection.start.path,
          offset: nonTextUpdate.selection.start,
        ),
      );
    }
  } else if (PlatformExtension.isLinux) {
    if (selection != null) {
      await editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(
            path: selection.start.path,
            offset: nonTextUpdate.selection.start,
          ),
        ),
      );
    }
  } else if (PlatformExtension.isMacOS || PlatformExtension.isIOS) {
    if (selection != null) {
      await editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(
            path: selection.start.path,
            offset: nonTextUpdate.selection.start,
          ),
        ),
      );
    }
  } else if (PlatformExtension.isAndroid) {
    await handleAndroidNonTextUpdate(nonTextUpdate, editorState);
  } else if (PlatformExtension.isIOS) {
    // on iOS, the cursor movement will trigger the `onFloatingCursor` event.
    // so we don't need to handle the non-text update here.
    AppFlowyEditorLog.input.debug('[iOS] onNonTextUpdate: $nonTextUpdate');
  }
}

@visibleForTesting
Future<bool> handleAndroidNonTextUpdate(
  TextEditingDeltaNonTextUpdate nonTextUpdate,
  EditorState editorState,
) async {
  // Gboard uses non-text updates for space-bar caret movement and for the
  // backspace swipe-to-delete gesture (expanding a range, then deleting it).
  // Other keyboards (e.g. the system keyboard) use `onFloatingCursor` instead.
  AppFlowyEditorLog.input.debug('[Android] onNonTextUpdate: $nonTextUpdate');

  final selection = editorState.selection;
  if (selection == null) {
    return false;
  }

  if (_isDocumentSelectAllNonTextUpdate(nonTextUpdate, editorState)) {
    return selectAllCommand.execute(editorState) == KeyEventResult.handled;
  }

  final imeSelection = nonTextUpdate.selection;
  if (!imeSelection.isValid) {
    return false;
  }

  // Multi-block IME text is concatenated, so offsets are not node-local.
  // Keep the previous caret-only sync in that case.
  if (!selection.isSingle) {
    if (imeSelection.isCollapsed &&
        imeSelection.start != selection.start.offset) {
      await editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(
            path: selection.start.path,
            offset: imeSelection.start,
          ),
        ),
        reason: SelectionUpdateReason.uiEvent,
      );

      return true;
    }

    return false;
  }

  final node = editorState.getNodeAtPath(selection.start.path);
  final maxOffset = node?.delta?.length;
  if (maxOffset == null) {
    return false;
  }

  int clampOffset(int offset) {
    if (offset < 0) {
      return 0;
    }
    if (offset > maxOffset) {
      return maxOffset;
    }
    return offset;
  }
  final nextSelection = Selection(
    start: Position(
      path: selection.start.path,
      offset: clampOffset(imeSelection.baseOffset),
    ),
    end: Position(
      path: selection.start.path,
      offset: clampOffset(imeSelection.extentOffset),
    ),
  );

  if (nextSelection == selection) {
    return false;
  }

  await editorState.updateSelectionWithReason(
    nextSelection,
    reason: SelectionUpdateReason.uiEvent,
    extraInfo: nextSelection.isCollapsed
        ? null
        : const {
            selectionExtraInfoDisableFloatingToolbar: true,
          },
  );

  return true;
}

bool _isDocumentSelectAllNonTextUpdate(
  TextEditingDeltaNonTextUpdate nonTextUpdate,
  EditorState editorState,
) {
  final imeSelection = nonTextUpdate.selection;
  if (nonTextUpdate.oldText.isEmpty ||
      imeSelection.start != 0 ||
      imeSelection.end != nonTextUpdate.oldText.length ||
      imeSelection.isCollapsed ||
      !nonTextUpdate.composing.isCollapsed) {
    return false;
  }

  // The IME is only given the selected block when the caret is in one
  // paragraph. A swipe that covers that buffer must stay local; promoting
  // it to document select-all would delete every block on the follow-up
  // delete.
  final selection = editorState.selection;
  if (selection != null && selection.isSingle) {
    final nodeText = editorState
            .getNodeAtPath(selection.start.path)
            ?.delta
            ?.toPlainText() ??
        '';
    if (nonTextUpdate.oldText == nodeText) {
      return false;
    }
  }

  return true;
}

Future<bool> _checkIfBacktickPressed(
  EditorState editorState,
  TextEditingDeltaNonTextUpdate nonTextUpdate,
) async {
  // if the composing range is not empty, it means the user is typing a text,
  // so we don't need to handle the backtick pressed event
  if (!nonTextUpdate.composing.isCollapsed) {
    return false;
  }

  // if the selection is not collapsed, it means the user is not typing a text,
  // so we need to handle the backtick pressed event
  if (!nonTextUpdate.selection.isCollapsed) {
    return false;
  }

  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    AppFlowyEditorLog.input.debug('selection is null or not collapsed');

    return false;
  }

  final node = editorState.getNodesInSelection(selection).firstOrNull;
  if (node == null) {
    AppFlowyEditorLog.input.debug('node is null');

    return false;
  }

  // get last character of the node
  final lastCharacter = node.delta?.toPlainText().characters.lastOrNull;
  if (lastCharacter != '`') {
    AppFlowyEditorLog.input.debug('last character is not backtick');

    return false;
  }

  // check if the text should be formatted
  final (shouldApplyFormat, _) = checkSingleCharacterFormatShouldBeApplied(
    editorState: editorState,
    // check before the last character
    selection: selection.shift(-1),
    character: '`',
    formatStyle: FormatStyleByWrappingWithSingleChar.code,
  );

  if (!shouldApplyFormat) {
    AppFlowyEditorLog.input.debug('should not apply format');

    return false;
  }

  final transaction = editorState.transaction;
  transaction.deleteText(node, node.delta!.toPlainText().length - 1, 1);
  await editorState.apply(transaction);

  // remove the last backtick, and try to format the text to code block
  final isFormatted = handleFormatByWrappingWithSingleCharacter(
    editorState: editorState,
    character: '`',
    formatStyle: FormatStyleByWrappingWithSingleChar.code,
  );

  if (!isFormatted) {
    AppFlowyEditorLog.input.debug('format failed');
    // revert the transaction
    editorState.undoManager.undo();
  } else {
    editorState.sliceUpcomingAttributes = false;
  }

  return true;
}
