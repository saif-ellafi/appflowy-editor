import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// A paragraph step is one block: a text block, or a leaf such as a picture.
/// A container (a table, a column) is not a stop; the step lands inside it.
bool isParagraphStop(Node node) {
  if (node.parent == null) {
    return false;
  }
  if (node.delta != null) {
    return true;
  }
  return node.selectable != null && node.children.isEmpty;
}

/// Where Ctrl+Up (Option+Up on macOS) lands.
Position? previousParagraphPosition(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return null;
  }
  final node = editorState.getNodeAtPath(selection.end.path);
  if (node == null) {
    return null;
  }
  // In the middle of a paragraph, the first step is that paragraph's start.
  if (selection.end.offset > 0 && isParagraphStop(node)) {
    return node.selectable?.start();
  }
  final previous = node.previousNodeWhere(isParagraphStop);
  return previous?.selectable?.start() ?? node.selectable?.start();
}

/// Where Ctrl+Down (Option+Down on macOS) lands: the start of the next
/// paragraph, or the end of this one when there is no next.
Position? nextParagraphPosition(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return null;
  }
  final node = editorState.getNodeAtPath(selection.end.path);
  if (node == null) {
    return null;
  }
  final next = node.nextNodeWhere(isParagraphStop);
  if (next != null) {
    return next.selectable?.start();
  }
  return node.selectable?.end();
}

KeyEventResult moveByParagraph(EditorState editorState, {required bool up, required bool extend}) {
  final selection = editorState.selection;
  final position = up ? previousParagraphPosition(editorState) : nextParagraphPosition(editorState);
  if (selection == null || position == null) {
    return KeyEventResult.ignored;
  }
  editorState.updateSelectionWithReason(
    extend ? selection.copyWith(end: position) : Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );
  return KeyEventResult.handled;
}
