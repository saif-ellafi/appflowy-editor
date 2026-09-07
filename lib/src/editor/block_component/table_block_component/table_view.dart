import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_action_handler.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_add_button.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_col.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_col_border.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_interaction.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableView extends StatefulWidget {
  const TableView({
    super.key,
    required this.editorState,
    required this.tableNode,
    required this.tableStyle,
    this.menuBuilder,
  });

  final EditorState editorState;
  final TableNode tableNode;
  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableStyle tableStyle;

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  @override
  Widget build(BuildContext context) {
    final interaction = TableInteractionScope.of(context);
    final touch =
        widget.tableStyle.touchLayout || tableIsTouchLayout(context);
    final showResize = widget.editorState.editable;
    final hitWidth = touch
        ? tableMobileResizeHitWidth
        : tableDesktopResizeHitWidth;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: tableBorderChrome,
                    left: tableBorderChrome,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildColumns(context),
                  ),
                ),
                if (showResize)
                  ..._buildResizeHandles(interaction, hitWidth),
                ..._buildBorderHandles(interaction),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: tableBorderChrome),
              child: TableActionButton(
                key: const ValueKey('table_add_column'),
                padding: const EdgeInsets.only(),
                icon: widget.tableStyle.addIcon,
                width: 28,
                height: widget.tableNode.colsHeight,
                visible: interaction.isActive,
                onPressed: () {
                  TableActions.add(
                    widget.tableNode.node,
                    widget.tableNode.colsLen,
                    widget.editorState,
                    TableDirection.col,
                  );
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: tableBorderChrome),
          child: TableActionButton(
            key: const ValueKey('table_add_row'),
            padding: const EdgeInsets.only(top: 1, right: 30),
            icon: widget.tableStyle.addIcon,
            height: 28,
            width: widget.tableNode.tableWidth,
            visible: interaction.isActive,
            onPressed: () {
              TableActions.add(
                widget.tableNode.node,
                widget.tableNode.rowsLen,
                widget.editorState,
                TableDirection.row,
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildColumns(BuildContext context) {
    return List.generate(
      widget.tableNode.colsLen,
      (i) => TableCol(
        colIdx: i,
        editorState: widget.editorState,
        tableNode: widget.tableNode,
        tableStyle: widget.tableStyle,
      ),
    );
  }

  List<Widget> _buildBorderHandles(TableInteractionController interaction) {
    if (!interaction.isActive || !widget.editorState.editable) {
      return const [];
    }

    final borderWidth = widget.tableNode.config.borderWidth;
    final handles = <Widget>[];
    final col = interaction.activeCol;
    final row = interaction.activeRow;

    if (col != null && col >= 0 && col < widget.tableNode.colsLen) {
      double x = tableBorderChrome + borderWidth;
      for (var i = 0; i < col; i++) {
        x += interaction.previewWidthFor(i) ?? widget.tableNode.getColWidth(i);
        x += borderWidth;
      }
      final width =
          interaction.previewWidthFor(col) ?? widget.tableNode.getColWidth(col);
      handles.add(
        Positioned(
          left: x,
          width: width,
          top: tableBorderChrome +
              borderWidth / 2 -
              tableHandleOvalThickness / 2,
          height: tableHandleOvalThickness,
          child: Center(
            child: TableActionHandler(
              key: ValueKey('table_col_menu_$col'),
              visible: true,
              node: widget.tableNode.node,
              editorState: widget.editorState,
              position: col,
              menuBuilder: widget.menuBuilder,
              dir: TableDirection.col,
            ),
          ),
        ),
      );
    }

    if (row != null && row >= 0 && row < widget.tableNode.rowsLen) {
      double y = tableBorderChrome + borderWidth;
      for (var i = 0; i < row; i++) {
        y += widget.tableNode.getRowHeight(i) + borderWidth;
      }
      handles.add(
        Positioned(
          left: tableBorderChrome +
              borderWidth / 2 -
              tableHandleOvalThickness / 2,
          width: tableHandleOvalThickness,
          top: y,
          height: widget.tableNode.getRowHeight(row),
          child: Center(
            child: TableActionHandler(
              key: ValueKey('table_row_menu_0_$row'),
              visible: true,
              node: widget.tableNode.node,
              editorState: widget.editorState,
              position: row,
              menuBuilder: widget.menuBuilder,
              dir: TableDirection.row,
            ),
          ),
        ),
      );
    }

    return handles;
  }

  List<Widget> _buildResizeHandles(
    TableInteractionController interaction,
    double hitWidth,
  ) {
    final borderWidth = widget.tableNode.config.borderWidth;
    final height = context.select(
          (Node n) => n.attributes[TableBlockKeys.colsHeight],
        ) ??
        widget.tableNode.colsHeight;
    double x = tableBorderChrome + borderWidth;
    final handles = <Widget>[];

    for (var i = 0; i < widget.tableNode.colsLen; i++) {
      x += interaction.previewWidthFor(i) ?? widget.tableNode.getColWidth(i);
      handles.add(
        Positioned(
          left: x + borderWidth / 2 - hitWidth / 2,
          width: hitWidth,
          top: tableBorderChrome,
          height: height,
          child: TableColResizeHandle(
            key: ValueKey('table_col_resize_$i'),
            tableNode: widget.tableNode,
            editorState: widget.editorState,
            colIdx: i,
            guideColor: widget.tableStyle.borderHoverColor,
          ),
        ),
      );
      x += borderWidth;
    }

    return handles;
  }
}
