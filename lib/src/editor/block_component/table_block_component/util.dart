import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:collection/collection.dart';

/// The rectangle of cells between the two ends of a selection, in row order.
///
/// Null when the selection stays inside one cell, or is not inside one table.
class TableCellSpan {
  const TableCellSpan({
    required this.table,
    required this.row0,
    required this.row1,
    required this.col0,
    required this.col1,
  });

  final Node table;
  final int row0;
  final int row1;
  final int col0;
  final int col1;

  bool contains(int row, int col) => row >= row0 && row <= row1 && col >= col0 && col <= col1;
}

/// Cells are stored down each column. A selection still means the rectangle
/// from one cell to the other, read across the row and then down.
TableCellSpan? tableCellSpan(Node root, Selection selection) {
  final normalized = selection.normalized;
  final start = root.childAtPath(normalized.start.path);
  final end = root.childAtPath(normalized.end.path);
  if (start == null || end == null) {
    return null;
  }
  final startCell = start.findParent((n) => n.type == TableCellBlockKeys.type);
  final endCell = end.findParent((n) => n.type == TableCellBlockKeys.type);
  if (startCell == null || endCell == null || startCell.id == endCell.id) {
    return null;
  }
  final table = startCell.parent;
  if (table == null || table.id != endCell.parent?.id || table.type != TableBlockKeys.type) {
    return null;
  }
  final startRow = startCell.attributes[TableCellBlockKeys.rowPosition];
  final startCol = startCell.attributes[TableCellBlockKeys.colPosition];
  final endRow = endCell.attributes[TableCellBlockKeys.rowPosition];
  final endCol = endCell.attributes[TableCellBlockKeys.colPosition];
  if (startRow is! int || startCol is! int || endRow is! int || endCol is! int) {
    return null;
  }

  return TableCellSpan(
    table: table,
    row0: startRow < endRow ? startRow : endRow,
    row1: startRow > endRow ? startRow : endRow,
    col0: startCol < endCol ? startCol : endCol,
    col1: startCol > endCol ? startCol : endCol,
  );
}

Node pageOf(Node node) {
  var current = node;
  while (current.parent != null) {
    current = current.parent!;
  }

  return current;
}

bool nodeInTable(Node node, Node table) {
  final found = node.findParent((n) => n.type == TableBlockKeys.type);

  return found?.id == table.id;
}

bool nodeInCellSpan(Node node, TableCellSpan span) {
  if (!nodeInTable(node, span.table)) {
    return false;
  }
  final cell = node.findParent((n) => n.type == TableCellBlockKeys.type);
  if (cell == null) {
    return false;
  }
  final row = cell.attributes[TableCellBlockKeys.rowPosition];
  final col = cell.attributes[TableCellBlockKeys.colPosition];

  return row is int && col is int && span.contains(row, col);
}

/// The cells of [span], row by row, each cell followed by what is inside it.
List<Node> nodesInCellSpan(TableCellSpan span) {
  final nodes = <Node>[];
  for (var row = span.row0; row <= span.row1; row++) {
    for (var col = span.col0; col <= span.col1; col++) {
      final cell = getCellNode(span.table, col, row);
      if (cell == null) {
        continue;
      }
      nodes.add(cell);
      void walk(Node node) {
        for (final child in node.children) {
          nodes.add(child);
          walk(child);
        }
      }

      walk(cell);
    }
  }

  return nodes;
}

/// The table [node] sits in. A table is not inside itself.
Node? enclosingTable(Node node) {
  if (node.type == TableBlockKeys.type) {
    return null;
  }

  return node.findParent((n) => n.type == TableBlockKeys.type);
}

/// The cells of [table], row by row.
List<Node> cellsInReadingOrder(Node table) {
  final cols = table.attributes[TableBlockKeys.colsLen];
  final rows = table.attributes[TableBlockKeys.rowsLen];
  if (cols is! int || rows is! int) {
    return [];
  }

  return [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++) getCellNode(table, col, row),
  ].whereType<Node>().toList();
}

/// The first block with text in [node], [node] included, in reading order.
Node? firstTextIn(Node node) {
  if (node.delta != null) {
    return node;
  }
  for (final child in node.children) {
    final found = firstTextIn(child);
    if (found != null) {
      return found;
    }
  }

  return null;
}

/// The last block with text in [node], [node] included, in reading order.
Node? lastTextIn(Node node) {
  for (final child in node.children.reversed) {
    final found = lastTextIn(child);
    if (found != null) {
      return found;
    }
  }

  return node.delta != null ? node : null;
}

/// The part of a table a selection covers when only one of its ends is in
/// the table: from the cell it starts in to the last cell, or from the first
/// cell to the one it ends in, row by row.
class TableEdge {
  const TableEdge({
    required this.table,
    required this.nodes,
    required this.holdsStart,
    required this.coversTable,
  });

  final Node table;

  /// Cells and what is inside them, row by row. The cell an end sits in is
  /// left out itself; only its blocks from that end on (or up to it) are in.
  final List<Node> nodes;

  /// The selection starts in this table, and ends after it.
  final bool holdsStart;

  /// Every cell is selected, from the first character to the last.
  final bool coversTable;

  bool containsNode(Node node) => nodes.any((n) => n.id == node.id);
}

/// The tables where exactly one end of [selection] sits: at most two.
List<TableEdge> tableEdges(Node root, Selection selection) {
  final normalized = selection.normalized;
  final start = root.childAtPath(normalized.start.path);
  final end = root.childAtPath(normalized.end.path);
  if (start == null || end == null) {
    return [];
  }
  final startTable = enclosingTable(start);
  final endTable = enclosingTable(end);
  if (startTable != null && startTable.id == endTable?.id) {
    return [];
  }

  final edges = <TableEdge>[];
  if (startTable != null) {
    edges.add(
      _tableEdge(startTable, start, normalized.start.offset, holdsStart: true),
    );
  }
  if (endTable != null) {
    edges.add(
      _tableEdge(endTable, end, normalized.end.offset, holdsStart: false),
    );
  }

  return edges;
}

TableEdge _tableEdge(Node table, Node at, int offset, {required bool holdsStart}) {
  final cells = cellsInReadingOrder(table);
  final atCell = at.findParent((n) => n.type == TableCellBlockKeys.type);
  final index = cells.indexWhere((cell) => cell.id == atCell?.id);
  final nodes = <Node>[];
  void walk(Node node, bool Function(Node node) keep) {
    for (final child in node.children) {
      if (keep(child)) {
        nodes.add(child);
      }
      walk(child, keep);
    }
  }

  for (var i = 0; i < cells.length; i++) {
    final cell = cells[i];
    if (holdsStart ? i < index : i > index) {
      continue;
    }
    if (i == index) {
      walk(
        cell,
        (node) => holdsStart ? !(node.path < at.path) : !(node.path > at.path),
      );
      continue;
    }
    nodes.add(cell);
    walk(cell, (_) => true);
  }

  final bool coversTable;
  if (index < 0 || cells.isEmpty) {
    coversTable = false;
  } else if (holdsStart) {
    coversTable = index == 0 && firstTextIn(cells.first)?.id == at.id && offset == 0;
  } else {
    coversTable = index == cells.length - 1 &&
        lastTextIn(cells.last)?.id == at.id &&
        offset >= (at.delta?.length ?? 0);
  }

  return TableEdge(
    table: table,
    nodes: nodes,
    holdsStart: holdsStart,
    coversTable: coversTable,
  );
}

Node? getCellNode(Node tableNode, int col, int row) {
  return tableNode.children.firstWhereOrNull(
    (n) =>
        n.attributes[TableCellBlockKeys.colPosition] == col &&
        n.attributes[TableCellBlockKeys.rowPosition] == row,
  );
}

extension TableCellNodeDynamicExtension on dynamic {
  double toDouble({double defaultValue = 0.0}) {
    if (this is int) {
      return this.toDouble();
    } else if (this is double) {
      return this;
    } else {
      return double.tryParse(toString()) ?? defaultValue;
    }
  }
}

extension TableCellNodeAttributesExtension on Node {
  double get cellWidth {
    assert(type == TableCellBlockKeys.type);

    return attributes[TableCellBlockKeys.width]?.toDouble() ??
        TableDefaults.colWidth;
  }

  double get cellHeight {
    assert(type == TableCellBlockKeys.type);

    return attributes[TableCellBlockKeys.height]?.toDouble() ??
        TableDefaults.rowHeight;
  }

  double get colHeight {
    assert(type == TableBlockKeys.type);

    return attributes[TableBlockKeys.colsHeight]?.toDouble() ??
        TableDefaults.rowHeight;
  }
}
