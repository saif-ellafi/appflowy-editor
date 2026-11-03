import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// The caret position at the start or end of the visual row, not the paragraph.
Position? visualLinePosition(EditorState editorState, {required bool atStart}) {
  final selection = editorState.selection;
  if (selection == null) {
    return null;
  }
  final node = editorState.getNodeAtPath(selection.end.path);
  final selectable = node?.selectable;
  if (selectable == null) {
    return null;
  }
  final towardStart =
      atStart != (selectable.textDirection() == TextDirection.rtl);
  final range = selectable.getLineBoundaryInPosition(selection.end);
  if (range != null) {
    if (towardStart) {
      return Position(path: selection.end.path, offset: range.start);
    }
    var end = range.end;
    if (end > range.start) {
      final next = selectable.getLineBoundaryInPosition(
        Position(path: selection.end.path, offset: end),
      );
      // Soft wrap: this offset is drawn at the start of the next row.
      // Step back so the caret stays on this one.
      if (next != null && next.start == end) {
        end -= 1;
      }
    }
    return Position(path: selection.end.path, offset: end);
  }
  return towardStart ? selectable.start() : selectable.end();
}

KeyEventResult moveToVisualLine(
  EditorState editorState, {
  required bool atStart,
  required bool extend,
}) {
  final selection = editorState.selection;
  final position = visualLinePosition(editorState, atStart: atStart);
  if (selection == null || position == null) {
    return KeyEventResult.ignored;
  }
  editorState.updateSelectionWithReason(
    extend ? selection.copyWith(end: position) : Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
}
