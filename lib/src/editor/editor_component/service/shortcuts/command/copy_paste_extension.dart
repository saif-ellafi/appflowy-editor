import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';

final _listTypes = [
  BulletedListBlockKeys.type,
  TodoListBlockKeys.type,
  NumberedListBlockKeys.type,
];

extension EditorCopyPaste on EditorState {
  Future<void> pasteSingleLineNode(Node insertedNode) async {
    final selection = await deleteSelectionIfNeeded();
    if (selection == null) {
      return;
    }
    final node = getNodeAtPath(selection.start.path);
    final delta = node?.delta;
    if (node == null || delta == null) {
      return;
    }
    final transaction = this.transaction;
    final insertedDelta = insertedNode.delta;

    if (_isInsideTableCell(node) && insertedDelta == null) {
      _insertFlattenedDelta(
        transaction,
        node,
        selection,
        _flattenNodesToDelta([insertedNode]),
      );
      await apply(transaction);
      return;
    }

    // if the node is empty paragraph (default), replace it with the inserted node.
    if (delta.isEmpty && node.type == ParagraphBlockKeys.type) {
      if (insertedDelta == null) {
        // A table takes the empty line's place. A line is left after it only
        // when nothing else follows, and the caret goes there so typing and
        // the keyboard have a text target. Other blocks always leave a line.
        final isTable = insertedNode.type == TableBlockKeys.type;
        final leaveLine = !isTable || node.next == null;
        transaction
          ..insertNodes(
            selection.end.path,
            [
              insertedNode,
              if (leaveLine) paragraphNode(),
            ],
          )
          ..deleteNode(node)
          ..afterSelection = Selection.collapsed(
            Position(path: selection.end.path.next),
          );
        await apply(transaction);
        return;
      }
      final List<Node> combinedChildren = [
        ...insertedNode.children.map((e) => e.deepCopy()),
        // if the original node has children, copy them to the inserted node.
        ...node.children.map((e) => e.deepCopy()),
      ];
      insertedNode = insertedNode.copyWith(children: combinedChildren);
      transaction.insertNode(selection.end.path, insertedNode);
      transaction.deleteNode(node);
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: selection.end.path,
          offset: insertedDelta.length,
        ),
      );
    } else if (insertedDelta != null) {
      // if the node is not empty, insert the delta from inserted node after the selection.
      transaction.insertTextDelta(node, selection.endIndex, insertedDelta);
      if (_listTypes.contains(node.type) && insertedNode.children.isNotEmpty) {
        transaction.insertNodes(node.path + [0], insertedNode.children);
      }
    } else {
      _insertBlocksAtCaret(transaction, node, selection, [insertedNode]);
    }
    await apply(transaction);
  }

  Future<void> pasteMultiLineNodes(List<Node> nodes) async {
    assert(nodes.length > 1);

    final selection = await deleteSelectionIfNeeded();
    if (selection == null) {
      return;
    }
    final node = getNodeAtPath(selection.start.path);
    final delta = node?.delta;
    if (node == null || delta == null) {
      return;
    }

    if (_isInsideTableCell(node)) {
      final transaction = this.transaction;
      _insertFlattenedDelta(
        transaction,
        node,
        selection,
        _flattenNodesToDelta(nodes),
      );
      await apply(transaction);
      return;
    }

    final transaction = this.transaction;

    // check if the first node is a non-delta node,
    //  if so, insert the nodes after the current selection.
    final startWithNonDeltaBlock = nodes.first.delta == null;
    if (startWithNonDeltaBlock) {
      _insertBlocksAtCaret(transaction, node, selection, nodes);
      await apply(transaction);

      return;
    }

    final lastNodeLength = calculateLength(nodes);
    // merge the current selected node delta into the nodes.
    if (delta.isNotEmpty) {
      final firstNode = nodes.first;
      if (firstNode.delta != null) {
        nodes.first.insertDelta(
          delta.slice(0, selection.startIndex),
          insertAfter: false,
        );
      }

      final lastNode = nodes.last;
      if (lastNode.delta != null) {
        nodes.last.insertDelta(
          delta.slice(selection.endIndex),
        );
      }
    }

    if (delta.isEmpty && node.type != ParagraphBlockKeys.type) {
      nodes[0] = nodes.first.copyWith(
        type: node.type,
        attributes: {
          ...node.attributes,
          ...nodes.first.attributes,
        },
      );
    }

    for (final child in node.children) {
      nodes.last.insert(child);
    }

    transaction.insertNodes(selection.end.path, nodes);

    // delete the current node.
    transaction.deleteNode(node);

    final path = calculatePath(selection.start.path, nodes);
    transaction.afterSelection = Selection.collapsed(
      Position(
        path: path,
        offset: lastNodeLength,
      ),
    );

    await apply(transaction);
  }

  // delete the selection if it's not collapsed.
  Future<Selection?> deleteSelectionIfNeeded() async {
    final selection = this.selection;
    if (selection == null) {
      return null;
    }

    // delete the selection first.
    if (!selection.isCollapsed) {
      await deleteSelection(selection);
    }

    // fetch selection again.selection = editorState.selection;
    assert(this.selection?.isCollapsed == true);

    return this.selection;
  }

  Path calculatePath(Path start, List<Node> nodes) {
    var path = start;
    for (var i = 0; i < nodes.length; i++) {
      path = path.next;
    }
    path = path.previous;
    if (nodes.last.children.isNotEmpty) {
      return [
        ...path,
        ...calculatePath([0], nodes.last.children.toList()),
      ];
    }

    return path;
  }

  int calculateLength(List<Node> nodes) {
    if (nodes.last.children.isNotEmpty) {
      return calculateLength(nodes.last.children.toList());
    }

    return nodes.last.delta?.length ?? 0;
  }
}

bool _isInsideTableCell(Node node) {
  Node? current = node.parent;
  while (current != null) {
    if (current.type == TableCellBlockKeys.type) {
      return true;
    }
    current = current.parent;
  }
  return false;
}

void _insertFlattenedDelta(
  Transaction transaction,
  Node node,
  Selection selection,
  Delta flattened,
) {
  if (flattened.isEmpty) {
    return;
  }
  transaction.insertTextDelta(node, selection.endIndex, flattened);
  transaction.afterSelection = Selection.collapsed(
    Position(
      path: selection.end.path,
      offset: selection.endIndex + flattened.length,
    ),
  );
}

void _insertBlocksAtCaret(
  Transaction transaction,
  Node node,
  Selection selection,
  List<Node> blocks,
) {
  final delta = node.delta;
  if (delta == null) {
    transaction.insertNodes(node.path.next, blocks);
    return;
  }

  final before = delta.slice(0, selection.startIndex);
  final after = delta.slice(selection.endIndex);
  // A table grows an empty paragraph only when it would be the last block.
  // Text that was after the caret still needs its paragraph.
  final tableAtEnd = blocks.last.type == TableBlockKeys.type;
  final needsTrailingParagraph = after.isNotEmpty ||
      (blocks.last.delta == null && !tableAtEnd) ||
      (tableAtEnd && after.isEmpty && node.next == null);
  final caretOnFollowing =
      tableAtEnd && !needsTrailingParagraph && node.next != null;
  final afterNode = paragraphNode(
    delta: after,
    children: before.isEmpty
        ? node.children.map((child) => child.deepCopy()).toList()
        : const [],
  );
  final toInsert = needsTrailingParagraph ? [...blocks, afterNode] : blocks;
  final caretIndex = needsTrailingParagraph
      ? blocks.length
      : blocks.length - 1;
  final caretOffset = needsTrailingParagraph
      ? 0
      : (blocks.last.delta?.length ??
          (blocks.last.type == TableBlockKeys.type ? 1 : 0));

  final caretPath = caretOnFollowing
      ? _pathPlus(node.path, blocks.length + (before.isEmpty ? 0 : 1))
      : _pathPlus(node.path, caretIndex + (before.isEmpty ? 0 : 1));
  final resolvedOffset = caretOnFollowing ? 0 : caretOffset;

  if (before.isEmpty) {
    transaction
      ..insertNodes(node.path, toInsert)
      ..deleteNode(node)
      ..afterSelection = Selection.collapsed(
        Position(path: caretPath, offset: resolvedOffset),
      );
  } else {
    transaction
      ..updateNode(node, {blockComponentDelta: before.toJson()})
      ..insertNodes(node.path.next, toInsert)
      ..afterSelection = Selection.collapsed(
        Position(path: caretPath, offset: resolvedOffset),
      );
  }
}

Path _pathPlus(Path path, int delta) {
  if (path.isEmpty) {
    return [delta];
  }
  return [...path.sublist(0, path.length - 1), path.last + delta];
}

Delta _flattenNodesToDelta(List<Node> nodes) {
  final delta = Delta();
  var needsBreak = false;
  for (final node in nodes) {
    final piece = _flattenNodeToDelta(node);
    if (piece.isEmpty) {
      continue;
    }
    if (needsBreak) {
      delta.insert('\n');
    }
    delta.addAll(piece.toList());
    needsBreak = true;
  }
  return delta;
}

Delta _flattenNodeToDelta(Node node) {
  if (node.delta != null) {
    return node.delta!;
  }
  if (node.type == TableBlockKeys.type) {
    final markdown = documentToMarkdown(
      Document(root: pageNode(children: [node.deepCopy()])),
    ).trim();
    if (markdown.isEmpty) {
      return Delta();
    }
    return Delta()..insert(markdown);
  }
  return _flattenNodesToDelta(node.children.toList());
}

extension on Node {
  void insertDelta(Delta delta, {bool insertAfter = true}) {
    assert(delta.every((element) => element is TextInsert));
    if (this.delta == null) {
      updateAttributes({
        blockComponentDelta: delta.toJson(),
      });
    } else if (insertAfter) {
      updateAttributes(
        {
          blockComponentDelta: this
              .delta!
              .compose(
                Delta()
                  ..retain(this.delta!.length)
                  ..addAll(delta),
              )
              .toJson(),
        },
      );
    } else {
      updateAttributes(
        {
          blockComponentDelta: delta
              .compose(
                Delta()
                  ..retain(delta.length)
                  ..addAll(this.delta!),
              )
              .toJson(),
        },
      );
    }
  }
}
