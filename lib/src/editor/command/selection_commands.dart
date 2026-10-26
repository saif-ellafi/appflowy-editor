import 'package:appflowy_editor/appflowy_editor.dart';

enum SelectionMoveRange {
  character,
  word,
  line,
  block,
}

enum SelectionMoveDirection {
  forward,
  backward,
}

extension SelectionTransform on EditorState {
  /// backward delete one character
  Future<bool> deleteBackward() async {
    final selection = this.selection;
    if (selection == null || !selection.isCollapsed) {
      return false;
    }
    final node = getNodeAtPath(selection.start.path);
    final delta = node?.delta;
    if (node == null || delta == null) {
      return false;
    }
    final transaction = this.transaction;
    final index = delta.prevRunePosition(selection.startIndex);
    transaction.deleteText(node, index, selection.startIndex - index);
    await apply(transaction);

    return true;
  }

  /// [selection] (normalized) without a block without text it only touches:
  /// one it starts right after (offset past 0), or ends right before
  /// (offset 0). Null when nothing is left.
  Selection? _withoutEdgeBlocks(Selection selection) {
    var start = selection.start;
    var end = selection.end;
    if (start.path.equals(end.path)) {
      return selection;
    }
    final first = getNodeAtPath(start.path);
    if (first != null && first.delta == null && start.offset > 0) {
      final next = _nextInOrder(first);
      if (next == null) {
        return null;
      }
      start = Position(path: next.path);
    }
    final last = getNodeAtPath(end.path);
    if (last != null && last.delta == null && end.offset == 0) {
      final previous = _previousInOrder(last);
      if (previous == null) {
        return null;
      }
      end = Position(
        path: previous.path,
        offset: previous.delta?.length ?? 1,
      );
    }
    if (end.path < start.path ||
        (end.path.equals(start.path) && end.offset <= start.offset)) {
      return null;
    }
    return Selection(start: start, end: end);
  }

  /// The node after [node] in reading order: its first child, its next
  /// sibling, or the next sibling of the closest ancestor that has one.
  Node? _nextInOrder(Node node) {
    if (node.children.isNotEmpty) {
      return node.children.first;
    }
    Node? current = node;
    while (current != null && current.parent != null) {
      if (current.next != null) {
        return current.next;
      }
      current = current.parent;
    }
    return null;
  }

  /// The node before [node] in reading order: the deepest last descendant of
  /// its previous sibling, or else its parent (not the document root).
  Node? _previousInOrder(Node node) {
    var previous = node.previous;
    if (previous == null) {
      final parent = node.parent;
      return parent == null || parent.parent == null ? null : parent;
    }
    while (previous!.children.isNotEmpty) {
      previous = previous.children.last;
    }
    return previous;
  }

  /// Deletes the selection.
  ///
  /// If the selection is collapsed, this function does nothing.
  ///
  /// If the node contains a delta, this function deletes the text in the selection,
  ///   else the node does not contain a delta, this function deletes the node.
  ///
  /// If both the first node and last node contain a delta,
  ///   this function merges the delta of the last node into the first node,
  ///   and deletes the nodes in between.
  ///
  /// If only the first node contains a delta,
  ///   this function deletes the text in the first node,
  ///   and deletes the nodes expect for the first node.
  ///
  /// For the other cases, this function just deletes all the nodes.
  Future<bool> deleteSelection(
    Selection selection, {
    List<String> ignoreNodeTypes = const [
      TableCellBlockKeys.type,
    ],
  }) async {
    // Nothing to do if the selection is collapsed.
    if (selection.isCollapsed) {
      return false;
    }

    // Normalize the selection so that it is never reversed or extended.
    selection = selection.normalized;

    // A block without text (a picture) that the selection only touches at
    // its outer edge isn't part of it: leave it out, as copying does.
    final trimmed = _withoutEdgeBlocks(selection);
    if (trimmed == null) {
      return false;
    }
    selection = trimmed;

    // Start a new transaction.
    final transaction = this.transaction;

    // Get the nodes that are fully or partially selected.
    final nodes = getNodesInSelection(selection);
    if (nodes.isEmpty) {
      return false;
    }

    // A rectangle of cells is cleared as text. Removing the cells would
    // leave a table the editor can only draw as "placeholder". From the
    // first character to the last, it is the whole table, which goes.
    final span = tableCellSpan(document.root, selection);
    final spanCoversTable = span != null && _spanCoversTable(span, selection);
    if (span != null && !spanCoversTable) {
      _deleteTextInCellSpan(transaction, span, selection);
      transaction.afterSelection = selection.collapse(atStart: true);
      await apply(transaction);

      return true;
    }

    // One end in a table and the other outside it.
    final edges = tableEdges(document.root, selection);
    if (edges.isNotEmpty) {
      _deleteAcrossTableEdges(transaction, selection, nodes, edges);
      await apply(transaction);

      return true;
    }

    // Two lines of one cell join, as they would outside a table.
    final startNode = getNodeAtPath(selection.start.path);
    final endNode = getNodeAtPath(selection.end.path);
    final startTable = startNode == null || spanCoversTable ? null : enclosingTable(startNode);
    if (startNode != null &&
        endNode != null &&
        startNode.id != endNode.id &&
        startTable != null &&
        startTable.id == enclosingTable(endNode)?.id) {
      _deleteInOneCell(transaction, selection, nodes, startNode, endNode);
      await apply(transaction);

      return true;
    }

    // A selection that covers a table deletes the table. Deleting its cells
    // one by one leaves a grid the editor can only draw as "placeholder".
    final coveredTables = _tablesCoveredBy(nodes, startTable);
    if (coveredTables.isNotEmpty) {
      final coveredIds = coveredTables.map((table) => table.id).toSet();
      bool inCoveredTable(Node node) {
        if (coveredIds.contains(node.id)) {
          return true;
        }
        final table = node.findParent((n) => n.type == TableBlockKeys.type);

        return table != null && coveredIds.contains(table.id);
      }

      final startedInTable = inCoveredTable(nodes.first);
      final endedInTable = inCoveredTable(nodes.last);
      nodes.removeWhere(inCoveredTable);

      final leavesParagraph = document.root.children.every(
        (child) => coveredIds.contains(child.id) || nodes.any((node) => node.id == child.id),
      );
      if (leavesParagraph && (nodes.isEmpty || (startedInTable && endedInTable))) {
        transaction.insertNode(document.root.children.last.path.next, paragraphNode());
      }
      for (final table in coveredTables) {
        transaction.deleteNode(table);
      }

      if (nodes.isEmpty || (startedInTable && endedInTable)) {
        for (final node in nodes) {
          if (ignoreNodeTypes.contains(node.type) || ignoreNodeTypes.contains(node.parent?.type)) {
            continue;
          }
          transaction.deleteNode(node);
        }
        transaction.afterSelection = Selection.collapsed(
          leavesParagraph ? Position(path: [0]) : _caretBesideTables(coveredTables, coveredIds),
        );
        await apply(transaction);

        return true;
      }

      if (startedInTable || endedInTable) {
        for (var i = 0; i < nodes.length; i++) {
          final node = nodes[i];
          if (ignoreNodeTypes.contains(node.type) || ignoreNodeTypes.contains(node.parent?.type)) {
            continue;
          }
          final atStart = i == 0 && !startedInTable;
          final atEnd = i == nodes.length - 1 && !endedInTable;
          if (node.delta != null && (atStart || atEnd)) {
            final index = atStart ? selection.startIndex : 0;
            final length = atStart ? node.delta!.length - index : selection.endIndex.clamp(0, node.delta!.length);
            if (length > 0) {
              transaction.deleteText(node, index, length);
            }
          } else {
            transaction.deleteNode(node);
          }
        }
        transaction.afterSelection = startedInTable
            ? Selection.collapsed(_caretBesideTables(coveredTables, coveredIds))
            : selection.collapse(atStart: true);
        await apply(transaction);

        return true;
      }
    }

    // If only one node is selected, then we can just delete the selected text
    // or node.
    if (nodes.length == 1) {
      // If table cell is selected, clear the cell node child.
      final node = ignoreNodeTypes.contains(nodes.first.type)
          ? nodes.first.children.first
          : nodes.first;
      if (node.delta != null) {
        transaction.deleteText(
          node,
          selection.startIndex,
          selection.length,
        );
      } else if (!ignoreNodeTypes.contains(node.parent?.type)) {
        if (node.next == null) {
          // Leave a line to type on rather than no caret at all. It goes in
          // before the deletion, which would shift its path up.
          transaction.insertNode(node.path.next, paragraphNode());
        }
        transaction.deleteNode(node);
      }
    }

    // Otherwise, multiple nodes are selected, so we have to do more work.
    else {
      // The nodes are guaranteed to be in order, so we can determine which
      // nodes are at the beginning, middle, and end of the selection.
      assert(nodes.first.path < nodes.last.path);
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];

        // The first node is at the beginning of the selection.
        // All other nodes can be deleted.
        if (i != 0) {
          // Never delete a table cell node child
          if (ignoreNodeTypes.contains(node.parent?.type)) {
            if (!nodes.any((n) => n.id == node.parent?.parent?.id)) {
              transaction.deleteText(
                node,
                0,
                selection.end.offset,
              );
            }
          }
          // If first node was inside table cell then it wasn't mergable to last
          // node, So we should not delete the last node. Just delete part of
          // the text inside selection
          else if (node.id == nodes.last.id &&
              ignoreNodeTypes.contains(nodes.first.parent?.type)) {
            transaction.deleteText(
              node,
              0,
              selection.end.offset,
            );
          } else if (!ignoreNodeTypes.contains(node.type)) {
            transaction.deleteNode(node);
          }
          continue;
        }

        // If the last node is also a text node and not a node inside table cell,
        // and also the current node isn't inside table cell, then we can merge
        // the text between the two nodes.
        if (nodes.last.delta != null &&
            ![node.parent?.type, nodes.last.parent?.type]
                .any((type) => ignoreNodeTypes.contains(type))) {
          transaction.mergeText(
            node,
            nodes.last,
            leftOffset: selection.startIndex,
            rightOffset: selection.endIndex,
          );

          // combine the children of the last node into the first node.
          final last = nodes.last;

          if (last.children.isNotEmpty) {
            if (indentableBlockTypes.contains(node.type)) {
              transaction.insertNodes(
                node.path + [0],
                last.children,
              );
            } else {
              transaction.insertNodes(
                node.path.next,
                last.children,
              );
            }
          }
        }

        // Otherwise, we can just delete the selected text.
        else {
          // A table, or a cell, has no text of its own.
          if (node.delta == null) {
            if (!ignoreNodeTypes.contains(node.type) && !ignoreNodeTypes.contains(node.parent?.type)) {
              if (node.next == null) {
                transaction.insertNode(node.path.next, paragraphNode());
              }
              transaction.deleteNode(node);
            }
          }
          // If the last or first node is inside table we will only delete
          // selection part of first node.
          else if (ignoreNodeTypes.contains(nodes.last.parent?.type) ||
              ignoreNodeTypes.contains(node.parent?.type)) {
            transaction.deleteText(
              node,
              selection.startIndex,
              node.delta!.length - selection.startIndex,
            );
          } else {
            transaction.deleteText(
              node,
              selection.startIndex,
              selection.length,
            );
          }
        }
      }
    }

    // After the selection is deleted, we want to move the selection to the
    // beginning of the deleted selection.
    transaction.afterSelection = selection.collapse(atStart: true);
    AppFlowyEditorLog.editor
        .debug(transaction.operations.map((e) => e.toString()).toString());

    // Apply the transaction.
    await apply(transaction);

    return true;
  }

  /// Deletes every root block and leaves one empty paragraph, with the caret
  /// on it. Used when the whole document is selected, including a table.
  void leaveOneEmptyParagraph() {
    final children = document.root.children.toList();
    if (children.isEmpty) {
      return;
    }
    final transaction = this.transaction;
    transaction.insertNode(children.last.path.next, paragraphNode());
    for (final child in children) {
      transaction.deleteNode(child);
    }
    transaction.afterSelection = Selection.collapsed(Position(path: [0]));
    apply(transaction);
  }

  /// move the cursor forward.
  ///
  /// Don't hardcode the logic here.
  /// For example,
  ///   final position = node.selectable?.moveForward(selection.startIndex);
  ///   if (position == null) { ... // move to the previous node}
  ///   else { ... // move to the position }
  void moveCursorForward([
    SelectionMoveRange range = SelectionMoveRange.character,
  ]) {
    moveCursor(SelectionMoveDirection.forward, range);
  }

  /// move the cursor backward.
  void moveCursorBackward(SelectionMoveRange range) {
    moveCursor(SelectionMoveDirection.backward, range);
  }

  void moveCursor(
    SelectionMoveDirection direction, [
    SelectionMoveRange range = SelectionMoveRange.character,
  ]) {
    final selection = this.selection?.normalized;
    if (selection == null) {
      return;
    }

    // If the selection is not collapsed, then we want to collapse the selection
    if (!selection.isCollapsed && range != SelectionMoveRange.line) {
      // move the cursor to the start or end of the selection
      this.selection = selection.collapse(
        atStart: direction == SelectionMoveDirection.forward,
      );

      return;
    }

    final node = getNodeAtPath(selection.start.path);
    if (node == null) {
      return;
    }

    // Originally, I want to make this function as pure as possible,
    //  but I have to import the selectable here to compute the selection.
    final start = node.selectable?.start();
    final end = node.selectable?.end();
    final offset = direction == SelectionMoveDirection.forward
        ? selection.startIndex
        : selection.endIndex;
    {
      // the cursor is at the start of the node
      // move the cursor to the end of the previous node
      if (direction == SelectionMoveDirection.forward &&
          start != null &&
          start.offset >= offset) {
        final previousEnd = node
            .previousNodeWhere((element) => element.selectable != null)
            ?.selectable
            ?.end();
        if (previousEnd != null) {
          updateSelectionWithReason(
            Selection.collapsed(previousEnd),
            reason: SelectionUpdateReason.uiEvent,
          );
        }

        return;
      }
      // the cursor is at the end of the node
      // move the cursor to the start of the next node
      else if (direction == SelectionMoveDirection.backward &&
          end != null &&
          end.offset <= offset) {
        final nextStart = node
            .nextNodeWhere((element) => element.selectable != null)
            ?.selectable
            ?.start();
        if (nextStart != null) {
          updateSelectionWithReason(
            Selection.collapsed(nextStart),
            reason: SelectionUpdateReason.uiEvent,
          );
        }

        return;
      }
    }

    final delta = node.delta;
    // A block without text, such as a picture, has two caret places: before
    // it and after it, whatever the step.
    if (delta == null && start != null && end != null) {
      updateSelectionWithReason(
        Selection.collapsed(
          direction == SelectionMoveDirection.forward ? start : end,
        ),
        reason: SelectionUpdateReason.uiEvent,
      );
      return;
    }
    switch (range) {
      case SelectionMoveRange.character:
        if (delta != null) {
          // move the cursor to the left or right by one character
          updateSelectionWithReason(
            Selection.collapsed(
              selection.start.copyWith(
                offset: direction == SelectionMoveDirection.forward
                    ? delta.prevRunePosition(offset)
                    : delta.nextRunePosition(offset),
              ),
            ),
            reason: SelectionUpdateReason.uiEvent,
          );
        } else {
          throw UnimplementedError();
        }
        break;

      case SelectionMoveRange.word:
        final delta = node.delta;
        if (delta != null) {
          final position = direction == SelectionMoveDirection.forward
              ? Position(
                  path: node.path,
                  offset: delta.prevRunePosition(offset),
                )
              : selection.start;
          // move the cursor to the left or right by one line
          final wordSelection =
              node.selectable?.getWordBoundaryInPosition(position);
          if (wordSelection != null) {
            updateSelectionWithReason(
              Selection.collapsed(
                direction == SelectionMoveDirection.forward
                    ? wordSelection.start
                    : wordSelection.end,
              ),
              reason: SelectionUpdateReason.uiEvent,
            );
          }
        } else {
          throw UnimplementedError();
        }

        break;

      case SelectionMoveRange.line:
        if (delta != null) {
          // move the cursor to the left or right by one line
          updateSelectionWithReason(
            Selection.collapsed(
              selection.start.copyWith(
                offset: direction == SelectionMoveDirection.forward
                    ? 0
                    : delta.length,
              ),
            ),
            reason: SelectionUpdateReason.uiEvent,
          );
        } else {
          throw UnimplementedError();
        }
        break;

      default:
        throw UnimplementedError();
    }
  }
}

void _deleteTextInCellSpan(Transaction transaction, TableCellSpan span, Selection selection) {
  final normalized = selection.normalized;
  final root = span.table.findParent((n) => n.parent == null)!;
  Node? cellOf(Path path) => root.childAtPath(path)?.findParent((n) => n.type == TableCellBlockKeys.type);
  final startCell = cellOf(normalized.start.path);
  final endCell = cellOf(normalized.end.path);
  for (final node in nodesInCellSpan(span)) {
    final delta = node.delta;
    if (delta == null || delta.isEmpty) {
      continue;
    }
    // Lines of the end cells before the selection starts, or after it ends, stay.
    final cell = node.findParent((n) => n.type == TableCellBlockKeys.type);
    if ((cell?.id == startCell?.id && node.path < normalized.start.path) ||
        (cell?.id == endCell?.id && node.path > normalized.end.path)) {
      continue;
    }
    var index = 0;
    var length = delta.length;
    if (node.path.equals(normalized.start.path)) {
      index = normalized.start.offset;
      length = delta.length - index;
    }
    if (node.path.equals(normalized.end.path)) {
      length = normalized.end.offset - index;
    }
    if (index < 0 || length <= 0 || index + length > delta.length) {
      continue;
    }
    transaction.deleteText(node, index, length);
  }
}

bool _spanCoversTable(TableCellSpan span, Selection selection) {
  final cells = cellsInReadingOrder(span.table);
  if (cells.isEmpty) {
    return false;
  }
  final first = firstTextIn(cells.first);
  final last = lastTextIn(cells.last);
  final normalized = selection.normalized;

  return first != null &&
      last != null &&
      first.path.equals(normalized.start.path) &&
      normalized.start.offset == 0 &&
      last.path.equals(normalized.end.path) &&
      normalized.end.offset >= last.delta!.length;
}

/// The tables in [nodes]. Neither end of the selection is inside one of
/// them (except [holdingEnds], which holds both), so each is selected whole.
List<Node> _tablesCoveredBy(List<Node> nodes, Node? holdingEnds) {
  final tables = <String, Node>{};
  for (final node in nodes) {
    final table = node.findParent((n) => n.type == TableBlockKeys.type);
    if (table != null && table.id != holdingEnds?.id) {
      tables[table.id] = table;
    }
  }

  return tables.values.toList();
}

/// One end of [selection] is in a table, the other outside it. The table's
/// selected cells are cleared, row by row from that end, and the table goes
/// only when every cell is selected. Text outside is trimmed and blocks in
/// between go. Nothing merges across a table.
void _deleteAcrossTableEdges(
  Transaction transaction,
  Selection selection,
  List<Node> nodes,
  List<TableEdge> edges,
) {
  final document = transaction.document;
  final start = document.nodeAtPath(selection.start.path)!;
  final end = document.nodeAtPath(selection.end.path)!;
  final edgeIds = {for (final edge in edges) edge.table.id};
  final removed = <Node>[];
  final removedInCells = <Node>[];

  for (final edge in edges) {
    if (edge.coversTable) {
      removed.add(edge.table);
    } else {
      _clearTableEdge(
        transaction,
        edge,
        edge.holdsStart ? selection.start : selection.end,
        removedInCells,
      );
    }
  }

  final startInTable = enclosingTable(start) != null;
  final endInTable = enclosingTable(end) != null;
  if (!startInTable && !edgeIds.contains(start.id)) {
    final delta = start.delta;
    if (delta == null) {
      removed.add(start);
    } else if (selection.start.offset < delta.length) {
      transaction.deleteText(start, selection.start.offset, delta.length - selection.start.offset);
    }
  }
  if (!endInTable && !edgeIds.contains(end.id) && selection.end.offset > 0) {
    final delta = end.delta;
    if (delta == null) {
      removed.add(end);
    } else {
      transaction.deleteText(end, 0, selection.end.offset.clamp(0, delta.length));
    }
  }

  for (final node in nodes) {
    final table = node.findParent((n) => n.type == TableBlockKeys.type);
    if (node.id == start.id ||
        node.id == end.id ||
        (table != null && edgeIds.contains(table.id)) ||
        node.isParentOf(start) ||
        node.isParentOf(end)) {
      continue;
    }
    removed.add(node);
  }
  final topmost = removed.where((node) => !removed.any((other) => other.id != node.id && other.isParentOf(node))).toList();

  // Where the caret goes: where the selection started, or else the first
  // place left to type.
  final startKept = !topmost.any((node) => node.id == start.id || node.isParentOf(start));
  Node? caret;
  var offset = 0;
  if (startKept && start.delta != null) {
    caret = start;
    offset = selection.start.offset;
  } else {
    final endEdge = edges.where((edge) => !edge.holdsStart && !edge.coversTable).firstOrNull;
    final endKept = !topmost.any((node) => node.id == end.id || node.isParentOf(end));
    if (endEdge != null) {
      caret = cellsInReadingOrder(endEdge.table).map(firstTextIn).whereType<Node>().firstOrNull;
      // The first cell is the one the selection ends in, and its first line went.
      if (caret == null || removedInCells.any((node) => node.id == caret!.id)) {
        caret = end;
      }
    } else if (endKept && end.delta != null) {
      caret = end;
    }
  }

  final Path caretPath;
  if (caret == null && topmost.isEmpty) {
    caretPath = selection.start.path;
  } else if (caret == null) {
    // Nothing with text is left at either end: a line takes their place.
    final last = topmost.reduce((a, b) => a.path > b.path ? a : b);
    transaction.insertNode(last.path.next, paragraphNode());
    caretPath = _pathAfterRemoving(last.path.next, topmost);
  } else {
    caretPath = _pathAfterRemoving(caret.path, [...topmost, ...removedInCells]);
  }
  transaction.deleteNodes(topmost);
  transaction.afterSelection = Selection.collapsed(Position(path: caretPath, offset: offset));
}

/// Clears the cells of [edge], row by row from [at]: the line [at] is on
/// is cut there, and other lines are emptied. A cell keeps one line.
void _clearTableEdge(
  Transaction transaction,
  TableEdge edge,
  Position at,
  List<Node> removedInCells,
) {
  final atNode = transaction.document.nodeAtPath(at.path);
  final atCell = atNode?.findParent((n) => n.type == TableCellBlockKeys.type);
  for (final node in edge.nodes) {
    final delta = node.delta;
    if (delta == null) {
      continue;
    }
    if (node.path.equals(at.path)) {
      final from = edge.holdsStart ? at.offset : 0;
      final to = edge.holdsStart ? delta.length : at.offset.clamp(0, delta.length);
      if (to > from) {
        transaction.deleteText(node, from, to - from);
      }
      continue;
    }
    final cell = node.parent;
    final direct = cell != null && cell.type == TableCellBlockKeys.type;
    if (direct && (cell.id == atCell?.id || cell.children.first.id != node.id)) {
      transaction.deleteNode(node);
      removedInCells.add(node);
    } else if (delta.isNotEmpty) {
      transaction.deleteText(node, 0, delta.length);
    }
  }
}

/// Both ends in one cell, on different lines: the lines between go and the
/// two ends join, as they would outside a table.
void _deleteInOneCell(
  Transaction transaction,
  Selection selection,
  List<Node> nodes,
  Node start,
  Node end,
) {
  transaction.mergeText(
    start,
    end,
    leftOffset: selection.startIndex,
    rightOffset: selection.endIndex,
  );
  if (end.children.isNotEmpty) {
    transaction.insertNodes(start.path.next, end.children.toList());
  }
  final doomed = nodes.where((node) => node.id != start.id && !node.isParentOf(start)).toList();
  transaction.deleteNodes(
    doomed.where((node) => !doomed.any((other) => other.id != node.id && other.isParentOf(node))),
  );
  transaction.afterSelection = selection.collapse(atStart: true);
}

/// [path] once [removed] are gone: one step back for each removed block
/// before it, or before one of its parents, under the same parent.
Path _pathAfterRemoving(Path path, List<Node> removed) {
  final result = path.toList();
  for (final node in removed) {
    final at = node.path;
    if (at.length > result.length) {
      continue;
    }
    final level = at.length - 1;
    var sameParent = true;
    for (var i = 0; i < level; i++) {
      if (at[i] != result[i]) {
        sameParent = false;
        break;
      }
    }
    if (sameParent && at[level] < result[level]) {
      result[level]--;
    }
  }

  return result;
}

/// Where the caret goes once [covered] tables are gone and other blocks remain.
Position _caretBesideTables(List<Node> covered, Set<String> coveredIds) {
  final first = covered.first;
  final next = first.next;
  if (next != null && !coveredIds.contains(next.id)) {
    return Position(path: first.path);
  }
  var previous = first.previous;
  while (previous != null && coveredIds.contains(previous.id)) {
    previous = previous.previous;
  }
  if (previous != null) {
    return Position(
      path: previous.path,
      offset: previous.delta?.length ?? 0,
    );
  }

  return Position(path: first.path);
}
