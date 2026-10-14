import 'package:flutter/material.dart';

import 'package:appflowy_editor/appflowy_editor.dart';

/// Delete key event.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent deleteCommand = CommandShortcutEvent(
  key: 'Delete Key',
  getDescription: () => AppFlowyEditorL10n.current.cmdDeleteRight,
  command: 'delete, shift+delete',
  handler: _deleteCommandHandler,
);

CommandShortcutEventHandler _deleteCommandHandler = (editorState) {
  final selection = editorState.selection;
  final selectionType = editorState.selectionType;
  if (selection == null) {
    return KeyEventResult.ignored;
  }
  if (selectionType == SelectionType.block) {
    return _deleteInBlockSelection(editorState);
  } else if (selection.isCollapsed) {
    return _deleteInCollapsedSelection(editorState);
  } else {
    return _deleteInNotCollapsedSelection(editorState);
  }
};

/// The caret beside a block without text, such as a picture: before it,
/// delete removes the block; after it, delete acts on what is below, removing
/// an empty line or stepping into the text.
KeyEventResult _deleteBesideBlock(
  EditorState editorState,
  Node node,
  Position position,
) {
  final transaction = editorState.transaction;
  if (position.offset == 0) {
    transaction.deleteNode(node);
    if (node.next == null) {
      // Leave a line to type on rather than no caret at all.
      transaction.insertNode(node.path, paragraphNode());
    }
    transaction.afterSelection = Selection.collapsed(
      Position(path: node.path),
    );
    editorState.apply(transaction);

    return KeyEventResult.handled;
  }

  final next = node.next;
  if (next == null) {
    return KeyEventResult.handled;
  }
  if (next.type == ParagraphBlockKeys.type &&
      next.delta?.isEmpty == true &&
      next.children.isEmpty) {
    transaction
      ..deleteNode(next)
      ..afterSelection = Selection.collapsed(position);
    editorState.apply(transaction);
  } else {
    editorState.selection = Selection.collapsed(Position(path: next.path));
  }

  return KeyEventResult.handled;
}

/// Handle delete key event when selection is collapsed.
CommandShortcutEventHandler _deleteInCollapsedSelection = (editorState) {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    return KeyEventResult.ignored;
  }

  final position = selection.start;
  final node = editorState.getNodeAtPath(position.path);
  if (node != null && node.delta == null && node.parent != null) {
    return _deleteBesideBlock(editorState, node, position);
  }
  final delta = node?.delta;
  if (node == null || delta == null) {
    return KeyEventResult.ignored;
  }

  final transaction = editorState.transaction;

  if (position.offset == delta.length) {
    final Node? tableParent =
        node.findParent((element) => element.type == TableBlockKeys.type);
    Node? nextTableParent;
    final next = node.findDownward((element) {
      nextTableParent =
          element.findParent((element) => element.type == TableBlockKeys.type);
      // break if only one is in a table or they're in different tables
      return tableParent != nextTableParent ||
          // merge the next node with delta
          element.delta != null;
    });
    // table nodes should be deleted using the table menu
    // in-table paragraphs should only be deleted inside the table
    if (next != null && tableParent == nextTableParent) {
      if (next.children.isNotEmpty) {
        final path = node.path + [node.children.length];
        transaction.insertNodes(path, next.children);
      }
      transaction
        ..deleteNode(next)
        ..mergeText(
          node,
          next,
        );
      editorState.apply(transaction);

      return KeyEventResult.handled;
    }
  } else {
    final nextIndex = delta.nextRunePosition(position.offset);
    if (nextIndex <= delta.length) {
      transaction.deleteText(
        node,
        position.offset,
        nextIndex - position.offset,
      );
      editorState.apply(transaction);

      return KeyEventResult.handled;
    }
  }

  return KeyEventResult.ignored;
};

/// Handle delete key event when selection is not collapsed.
CommandShortcutEventHandler _deleteInNotCollapsedSelection = (editorState) {
  final selection = editorState.selection;
  if (selection == null || selection.isCollapsed) {
    return KeyEventResult.ignored;
  }
  editorState.deleteSelection(selection);

  return KeyEventResult.handled;
};

CommandShortcutEventHandler _deleteInBlockSelection = (editorState) {
  final selection = editorState.selection;
  if (selection == null || editorState.selectionType != SelectionType.block) {
    return KeyEventResult.ignored;
  }
  final transaction = editorState.transaction;
  transaction.deleteNodesAtPath(selection.start.path);
  editorState
      .apply(transaction)
      .then((value) => editorState.selectionType = null);

  return KeyEventResult.handled;
};
