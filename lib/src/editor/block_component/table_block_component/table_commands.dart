import 'package:flutter/material.dart';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/util.dart';

final List<CommandShortcutEvent> tableCommands = [
  enterInTableCell,
  leftInTableCell,
  rightInTableCell,
  upInTableCell,
  downInTableCell,
  tabInTableCell,
  shiftTabInTableCell,
  backSpaceInTableCell,
];

final CommandShortcutEvent enterInTableCell = CommandShortcutEvent(
  key: 'Don\'t add new line in table cell',
  getDescription: () => AppFlowyEditorL10n.current.cmdTableLineBreak,
  command: 'enter',
  handler: _enterInTableCellHandler,
);

final CommandShortcutEvent leftInTableCell = CommandShortcutEvent(
  key: 'Move to left cell if its at start of current cell',
  getDescription: () => AppFlowyEditorL10n
      .current.cmdTableMoveToLeftCellIfItsAtStartOfCurrentCell,
  command: 'arrow left',
  handler: _leftInTableCellHandler,
);

final CommandShortcutEvent rightInTableCell = CommandShortcutEvent(
  key: 'Move to right cell if its at the end of current cell',
  getDescription: () => AppFlowyEditorL10n
      .current.cmdTableMoveToRightCellIfItsAtTheEndOfCurrentCell,
  command: 'arrow right',
  handler: _rightInTableCellHandler,
);

final CommandShortcutEvent upInTableCell = CommandShortcutEvent(
  key: 'Move to up cell at same offset',
  getDescription: () =>
      AppFlowyEditorL10n.current.cmdTableMoveToUpCellAtSameOffset,
  command: 'arrow up',
  handler: _upInTableCellHandler,
);

final CommandShortcutEvent downInTableCell = CommandShortcutEvent(
  key: 'Move to down cell at same offset',
  getDescription: () =>
      AppFlowyEditorL10n.current.cmdTableMoveToDownCellAtSameOffset,
  command: 'arrow down',
  handler: _downInTableCellHandler,
);

final CommandShortcutEvent tabInTableCell = CommandShortcutEvent(
  key: 'Navigate around the cells at same offset',
  getDescription: () => AppFlowyEditorL10n.current.cmdTableNavigateCells,
  command: 'tab',
  handler: _tabInTableCellHandler,
);

final CommandShortcutEvent shiftTabInTableCell = CommandShortcutEvent(
  key: 'Navigate around the cells at same offset in reverse',
  getDescription: () => AppFlowyEditorL10n.current.cmdTableNavigateCellsReverse,
  command: 'shift+tab',
  handler: _shiftTabInTableCellHandler,
);

final CommandShortcutEvent backSpaceInTableCell = CommandShortcutEvent(
  key: 'Stop at the beginning of the cell',
  getDescription: () =>
      AppFlowyEditorL10n.current.cmdTableStopAtTheBeginningOfTheCell,
  command: 'backspace',
  handler: _backspaceInTableCellHandler,
);

CommandShortcutEventHandler _enterInTableCellHandler = (editorState) {
  final inTableNodes = _inTableNodes(editorState);
  if (inTableNodes.isEmpty) {
    return KeyEventResult.ignored;
  }

  final selection = editorState.selection;
  if (_hasSelectionAndTableCell(inTableNodes, selection)) {
    if (openLineAboveTable(editorState)) {
      return KeyEventResult.handled;
    }
    final cell = inTableNodes.first.parent!;
    final nextNode = _getNextNode(inTableNodes, 0, 1);
    if (nextNode == null) {
      final transaction = editorState.transaction;
      transaction.insertNode(cell.parent!.path.next, paragraphNode());
      transaction.afterSelection =
          Selection.single(path: cell.parent!.path.next, startOffset: 0);
      editorState.apply(transaction);
    } else if (_nodeHasTextChild(nextNode)) {
      editorState.selectionService.updateSelection(
        Selection.single(
          path: nextNode.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );
    }
  }

  return KeyEventResult.handled;
};

CommandShortcutEventHandler _leftInTableCellHandler = (editorState) {
  final inTableNodes = _inTableNodes(editorState);
  final selection = editorState.selection;
  if (_hasSelectionAndTableCell(inTableNodes, selection) &&
      selection!.start.offset == 0) {
    // A later line of the cell steps back onto the line above it.
    if (inTableNodes.first.previous != null) {
      return KeyEventResult.ignored;
    }
    final nextNode = _getPreviousNode(inTableNodes, 1, 0);
    if (_nodeHasTextChild(nextNode)) {
      final target = lastTextIn(nextNode!) ?? nextNode.childAtIndexOrNull(0)!;
      editorState.selectionService.updateSelection(
        Selection.single(
          path: target.path,
          startOffset: target.delta!.length,
        ),
      );
    } else if (nextNode == null) {
      // Before the first cell, the caret leaves the table upward.
      final table = inTableNodes.first.parent!.parent!;
      final before = table.previous;
      if (before != null) {
        editorState.selectionService.updateSelection(
          Selection.collapsed(_endOfBlock(before)),
        );
      }
    }

    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
};

CommandShortcutEventHandler _rightInTableCellHandler = (editorState) {
  final inTableNodes = _inTableNodes(editorState);
  final selection = editorState.selection;
  if (_hasSelectionAndTableCell(inTableNodes, selection) &&
      selection!.start.offset == inTableNodes.first.delta!.length) {
    // An earlier line of the cell steps onto the line below it.
    if (inTableNodes.first.next != null) {
      return KeyEventResult.ignored;
    }
    final nextNode = _getNextNode(inTableNodes, 1, 0);
    if (_nodeHasTextChild(nextNode)) {
      editorState.selectionService.updateSelection(
        Selection.single(
          path: nextNode!.childAtIndexOrNull(0)!.path,
          startOffset: 0,
        ),
      );

      return KeyEventResult.handled;
    }
    // A later cell with no text keeps the key. Past the last cell, the caret
    // leaves the table: onto the next block, or a new line when the table is last.
    if (nextNode != null) {
      return KeyEventResult.handled;
    }

    final table = inTableNodes.first.parent?.parent;
    if (table == null) {
      return KeyEventResult.ignored;
    }
    _leaveTableDownward(editorState, table);

    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
};

/// Past the table's end: onto the next block, or a new line when the table
/// is last.
void _leaveTableDownward(EditorState editorState, Node table) {
  final after = table.next;
  if (after != null) {
    editorState.selectionService.updateSelection(
      Selection.collapsed(_startOfBlock(after)),
    );

    return;
  }

  final transaction = editorState.transaction;
  transaction.insertNode(table.path.next, paragraphNode());
  transaction.afterSelection = Selection.collapsed(Position(path: table.path.next));
  editorState.apply(transaction);
}

Position _startOfBlock(Node node) {
  if (node.type == TableBlockKeys.type) {
    final cells = cellsInReadingOrder(node);
    final first = cells.isEmpty ? null : firstTextIn(cells.first);
    if (first != null) {
      return Position(path: first.path);
    }
  }
  final first = firstTextIn(node);
  if (first != null) {
    return Position(path: first.path);
  }

  return node.selectable?.start() ?? Position(path: node.path);
}

Position _endOfBlock(Node node) {
  if (node.type == TableBlockKeys.type) {
    final cells = cellsInReadingOrder(node);
    final last = cells.isEmpty ? null : lastTextIn(cells.last);
    if (last != null) {
      return Position(path: last.path, offset: last.delta!.length);
    }
  }
  final last = lastTextIn(node);
  if (last != null) {
    return Position(path: last.path, offset: last.delta!.length);
  }

  return node.selectable?.end() ?? Position(path: node.path, offset: 1);
}

/// Whether the caret is on the top (or bottom) line of its cell, so up (or
/// down) leaves the cell. A long line wraps; only its first or last row counts.
bool _onEdgeLineOfCell(Node node, int offset, {required bool top}) {
  if ((top ? node.previous : node.next) != null) {
    return false;
  }
  final selectable = node.selectable;
  final length = node.delta?.length ?? 0;
  final here = selectable?.getCursorRectInPosition(
    Position(path: node.path, offset: offset),
  );
  final edge = selectable?.getCursorRectInPosition(
    Position(path: node.path, offset: top ? 0 : length),
  );
  if (here == null || edge == null) {
    return true;
  }

  return (here.center.dy - edge.center.dy).abs() < here.height / 2;
}

/// Enter at the start of the text in the top-left cell opens a line above
/// the table, with the caret on it. Without this, a table at the top of the
/// document leaves no way to write above it. In an empty cell, Enter still
/// moves down, as it does in any cell.
bool openLineAboveTable(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed || selection.start.offset != 0) {
    return false;
  }
  final node = editorState.getNodeAtPath(selection.start.path);
  final cell = node?.parent;
  final table = cell?.parent;
  if (node == null ||
      node.delta == null ||
      node.previous != null ||
      cell == null ||
      cell.type != TableCellBlockKeys.type ||
      table == null ||
      table.type != TableBlockKeys.type ||
      cell.attributes[TableCellBlockKeys.colPosition] != 0 ||
      cell.attributes[TableCellBlockKeys.rowPosition] != 0) {
    return false;
  }
  if (node.delta!.isEmpty) {
    return false;
  }
  _insertLineAbove(editorState, table);

  return true;
}

void _insertLineAbove(EditorState editorState, Node table) {
  final transaction = editorState.transaction
    ..insertNode(table.path, paragraphNode())
    ..afterSelection = Selection.collapsed(Position(path: table.path));
  editorState.apply(transaction);
}

CommandShortcutEventHandler _upInTableCellHandler = (editorState) {
  final inTableNodes = _inTableNodes(editorState);
  final selection = editorState.selection;
  if (_hasSelectionAndTableCell(inTableNodes, selection)) {
    final node = inTableNodes.first;
    if (!_onEdgeLineOfCell(node, selection!.start.offset, top: true)) {
      return KeyEventResult.ignored;
    }
    final nextNode = _getNextNode(inTableNodes, 0, -1);
    if (_nodeHasTextChild(nextNode)) {
      final target = lastTextIn(nextNode!) ?? nextNode.childAtIndexOrNull(0)!;
      final off = target.delta!.length > selection.start.offset
          ? selection.start.offset
          : target.delta!.length;
      editorState.selectionService.updateSelection(
        Selection.single(path: target.path, startOffset: off),
      );
    } else if (nextNode == null) {
      // Above the top row, the caret leaves the table: onto the block
      // above, or a new line when the table is first.
      final table = node.parent!.parent!;
      final before = table.previous;
      if (before != null) {
        editorState.selectionService.updateSelection(
          Selection.collapsed(_endOfBlock(before)),
        );
      } else {
        _insertLineAbove(editorState, table);
      }
    }

    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
};

CommandShortcutEventHandler _downInTableCellHandler = (editorState) {
  final inTableNodes = _inTableNodes(editorState);
  final selection = editorState.selection;
  if (_hasSelectionAndTableCell(inTableNodes, selection)) {
    final node = inTableNodes.first;
    if (!_onEdgeLineOfCell(node, selection!.start.offset, top: false)) {
      return KeyEventResult.ignored;
    }
    final nextNode = _getNextNode(inTableNodes, 0, 1);
    if (_nodeHasTextChild(nextNode)) {
      final target = nextNode!.childAtIndexOrNull(0)!;
      final off = target.delta!.length > selection.start.offset
          ? selection.start.offset
          : target.delta!.length;
      editorState.selectionService.updateSelection(
        Selection.single(path: target.path, startOffset: off),
      );
    } else if (nextNode == null) {
      // Below the bottom row, the caret leaves the table.
      _leaveTableDownward(editorState, node.parent!.parent!);
    }

    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
};

CommandShortcutEventHandler _tabInTableCellHandler = (editorState) {
  final inTableNodes = _inTableNodes(editorState);
  final selection = editorState.selection;
  if (_hasSelectionAndTableCell(inTableNodes, selection)) {
    final nextNode = _getNextNode(inTableNodes, 1, 0);
    if (nextNode != null && _nodeHasTextChild(nextNode)) {
      final firstChild = nextNode.childAtIndexOrNull(0);
      if (firstChild != null) {
        editorState.selection = Selection.single(
          path: firstChild.path,
          startOffset: 0,
        );
      }
    }

    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
};

CommandShortcutEventHandler _shiftTabInTableCellHandler = (editorState) {
  final inTableNodes = _inTableNodes(editorState);
  final selection = editorState.selection;
  if (_hasSelectionAndTableCell(inTableNodes, selection)) {
    final previousNode = _getPreviousNode(inTableNodes, 1, 0);
    if (previousNode != null && _nodeHasTextChild(previousNode)) {
      final firstChild = previousNode.childAtIndexOrNull(0);
      if (firstChild != null) {
        editorState.selection = Selection.single(
          path: firstChild.path,
          startOffset: 0,
        );
      }
    }

    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
};

CommandShortcutEventHandler _backspaceInTableCellHandler = (editorState) {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    return KeyEventResult.ignored;
  }

  final position = selection.start;
  final node = editorState.getNodeAtPath(position.path);
  if (node == null || node.delta == null) {
    return KeyEventResult.ignored;
  }

  if (node.parent?.type == TableCellBlockKeys.type && position.offset == 0) {
    // A newline inside the cell (mobile Enter, or a second paragraph) joins
    // back into the line above. The first line of the cell stays put.
    final previous = node.previous;
    if (previous == null || previous.delta == null) {
      return KeyEventResult.handled;
    }
    final transaction = editorState.transaction
      ..mergeText(previous, node)
      ..insertNodes(previous.path.next, node.children.toList())
      ..deleteNode(node)
      ..afterSelection = Selection.collapsed(
        Position(path: previous.path, offset: previous.delta!.length),
      );
    editorState.apply(transaction);

    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
};

Iterable<Node> _inTableNodes(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) {
    return [];
  }
  final nodes = editorState.getNodesInSelection(selection);

  return nodes.where(
    (node) => node.parent?.type.contains(TableBlockKeys.type) ?? false,
  );
}

bool _hasSelectionAndTableCell(
  Iterable<Node> nodes,
  Selection? selection,
) =>
    nodes.length == 1 &&
    selection != null &&
    selection.isCollapsed &&
    nodes.first.parent?.type == TableCellBlockKeys.type;

Node? _getNextNode(Iterable<Node> nodes, int colDiff, int rowDiff) {
  final cell = nodes.first.parent!;
  final col = cell.attributes[TableCellBlockKeys.colPosition];
  final row = cell.attributes[TableCellBlockKeys.rowPosition];
  final table = cell.parent;
  if (table == null) {
    return null;
  }

  final numCols =
      table.children.last.attributes[TableCellBlockKeys.colPosition] + 1;
  final numRows =
      table.children.last.attributes[TableCellBlockKeys.rowPosition] + 1;

  // Calculate the next column index, considering the column difference and wrapping around with modulo.
  final nextCol = (col + colDiff) % numCols;

  // Calculate the next row index, taking into account the row difference and adjusting for additional rows due to column change.
  final nextRow = row + rowDiff + ((col + colDiff) ~/ numCols);

  return isValidPosition(nextCol, nextRow, numCols, numRows)
      ? getCellNode(table, nextCol, nextRow)
      : null;
}

Node? _getPreviousNode(Iterable<Node> nodes, int colDiff, int rowDiff) {
  final cell = nodes.first.parent!;
  final col = cell.attributes[TableCellBlockKeys.colPosition];
  final row = cell.attributes[TableCellBlockKeys.rowPosition];
  final table = cell.parent;
  if (table == null) {
    return null;
  }

  final numCols =
      table.children.last.attributes[TableCellBlockKeys.colPosition] + 1;
  final numRows =
      table.children.last.attributes[TableCellBlockKeys.rowPosition] + 1;

  // Calculate the previous column index, ensuring it wraps within the table boundaries using modulo.
  final prevCol = (col - colDiff + numCols) % numCols;

  // Calculate the previous row index, considering table boundaries and adjusting for potential column underflow.
  final prevRow = row - rowDiff - ((col - colDiff) < 0 ? 1 : 0);

  return isValidPosition(prevCol, prevRow, numCols, numRows)
      ? getCellNode(table, prevCol, prevRow)
      : null;
}

bool isValidPosition(int col, int row, int numCols, int numRows) =>
    col >= 0 && col < numCols && row >= 0 && row < numRows;

bool _nodeHasTextChild(Node? n) =>
    n != null &&
    n.children.isNotEmpty &&
    n.childAtIndexOrNull(0)!.delta != null;
