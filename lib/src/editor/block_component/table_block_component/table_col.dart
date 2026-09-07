import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_col_border.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_interaction.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableCol extends StatefulWidget {
  const TableCol({
    super.key,
    required this.tableNode,
    required this.editorState,
    required this.colIdx,
    required this.tableStyle,
  });

  final int colIdx;
  final EditorState editorState;
  final TableNode tableNode;
  final TableStyle tableStyle;

  @override
  State<TableCol> createState() => _TableColState();
}

class _TableColState extends State<TableCol> {
  Map<String, void Function()> listeners = {};

  @override
  Widget build(BuildContext context) {
    final interaction = TableInteractionScope.of(context);
    final storedWidth = context.select(
      (Node n) => getCellNode(n, widget.colIdx, 0)?.cellWidth,
    );
    final width =
        interaction.previewWidthFor(widget.colIdx) ?? storedWidth;

    final List<Widget> children = [];
    if (widget.colIdx == 0) {
      children.add(
        TableColBorder(
          key: ValueKey('table_col_border_${widget.colIdx}_fixed'),
          tableNode: widget.tableNode,
          borderColor: widget.tableStyle.borderColor,
        ),
      );
    }

    children.addAll([
      SizedBox(
        width: width,
        child: Column(
          children: _buildCells(context, interaction.isResizing),
        ),
      ),
      TableColBorder(
        key: ValueKey('table_col_border_${widget.colIdx}_resizable'),
        tableNode: widget.tableNode,
        borderColor: widget.tableStyle.borderColor,
      ),
    ]);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<Widget> _buildCells(BuildContext context, bool isResizing) {
    final rowsLen = widget.tableNode.rowsLen;
    final List<Widget> cells = [];
    final Widget cellBorder = Container(
      height: widget.tableNode.config.borderWidth,
      color: widget.tableStyle.borderColor,
    );

    for (var i = 0; i < rowsLen; i++) {
      final node = widget.tableNode.getCell(widget.colIdx, i);
      if (!isResizing) {
        updateRowHeightCallback(i);
      }
      addListener(node, i);
      for (final child in node.children) {
        addListener(child, i);
      }

      cells.addAll([
        widget.editorState.renderer.build(
          context,
          node,
        ),
        cellBorder,
      ]);
    }

    return [
      cellBorder,
      ...cells,
    ];
  }

  void addListener(Node node, int row) {
    if (listeners.containsKey(node.id)) {
      return;
    }

    listeners[node.id] = () {
      if (!mounted) {
        return;
      }
      if (TableInteractionScope.maybeOf(context)?.isResizing ?? false) {
        return;
      }
      updateRowHeightCallback(row);
    };
    node.addListener(listeners[node.id]!);
  }

  void updateRowHeightCallback(int row) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (TableInteractionScope.maybeOf(context)?.isResizing ?? false) {
          return;
        }
        if (row >= widget.tableNode.rowsLen) {
          return;
        }

        final transaction = widget.editorState.transaction;
        widget.tableNode.updateRowHeight(
          row,
          editorState: widget.editorState,
          transaction: transaction,
        );
        if (transaction.operations.isNotEmpty) {
          transaction.afterSelection = transaction.beforeSelection;
          widget.editorState.apply(transaction);
        }
      });
}
