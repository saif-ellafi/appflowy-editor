import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_interaction.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class TableColBorder extends StatelessWidget {
  const TableColBorder({
    super.key,
    required this.tableNode,
    required this.borderColor,
  });

  final TableNode tableNode;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tableNode.config.borderWidth,
      height: context.select(
        (Node n) => n.attributes[TableBlockKeys.colsHeight],
      ),
      color: borderColor,
    );
  }
}

/// Transparent overlay centered on a column divider.
///
/// Layout width of the table is unchanged; this handle is positioned by the
/// parent stack. Mounted whenever the editor is editable so a drag cannot
/// unmount the handle by changing selection.
class TableColResizeHandle extends StatefulWidget {
  const TableColResizeHandle({
    super.key,
    required this.tableNode,
    required this.editorState,
    required this.colIdx,
    required this.guideColor,
    this.invertDrag = false,
    this.touchGrip = false,
  });

  final int colIdx;
  final TableNode tableNode;
  final EditorState editorState;
  final Color guideColor;
  /// Left-edge handle: dragging left widens the column, dragging right
  /// narrows it. Right-edge handles keep the opposite mapping.
  final bool invertDrag;
  /// Touch: a visible grip that only takes clearly horizontal drags, so
  /// scrolling and long-press selection win over resizing.
  final bool touchGrip;

  @override
  State<TableColResizeHandle> createState() => _TableColResizeHandleState();
}

class _TableColResizeHandleState extends State<TableColResizeHandle> {
  bool _dragActive = false;
  bool _tooltipInserted = false;
  int? _pointer;
  double _startGlobalX = 0;
  Offset _tooltipPosition = Offset.zero;
  OverlayEntry? _tooltip;

  @override
  void dispose() {
    _removeKeyHandler();
    _removeTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interaction = TableInteractionScope.maybeOf(context);
    final dragging =
        _dragActive && interaction?.resizingColIdx == widget.colIdx;
    final atMin = dragging && (interaction?.atMinWidth ?? false);
    final Color lineColor;
    if (!dragging) {
      lineColor = Colors.transparent;
    } else if (atMin) {
      lineColor = Colors.orange;
    } else {
      lineColor = widget.guideColor;
    }

    if (widget.touchGrip) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Measure from the touch-down point, not from where the slop ends.
        dragStartBehavior: DragStartBehavior.down,
        // No tap handler: the grip sits over cell text, and taps there
        // still place the caret.
        onHorizontalDragStart: (details) {
          _startGlobalX = details.globalPosition.dx;
          _tooltipPosition = details.globalPosition;
          _beginDrag();
        },
        onHorizontalDragUpdate: (details) =>
            _updateDrag(details.globalPosition),
        onHorizontalDragEnd: (_) => _commitDrag(),
        onHorizontalDragCancel: _cancelDrag,
        child: Center(
          child: TableResizeGrip(
            color: dragging && !atMin ? widget.guideColor : null,
            warning: atMin,
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointer != null) {
            return;
          }
          _pointer = event.pointer;
          _startGlobalX = event.position.dx;
          _tooltipPosition = event.position;
          _beginDrag();
        },
        onPointerMove: (event) {
          if (event.pointer != _pointer) {
            return;
          }
          _updateDrag(event.position);
        },
        onPointerUp: (event) {
          if (event.pointer != _pointer) {
            return;
          }
          _pointer = null;
          _commitDrag();
        },
        onPointerCancel: (event) {
          if (event.pointer != _pointer) {
            return;
          }
          _pointer = null;
          _cancelDrag();
        },
        child: Center(
          child: Container(
            width: dragging ? 3.0 : widget.tableNode.config.borderWidth,
            color: lineColor,
          ),
        ),
      ),
    );
  }

  void _beginDrag() {
    final interaction = TableInteractionScope.maybeOf(context);
    if (interaction == null) {
      return;
    }
    _dragActive = true;
    interaction.beginResize(
      widget.colIdx,
      widget.tableNode.getColWidth(widget.colIdx),
    );
    HardwareKeyboard.instance.addHandler(_handleKey);
    _showTooltip(interaction);
    setState(() {});
  }

  void _updateDrag(Offset globalPosition) {
    if (!_dragActive) {
      return;
    }
    final interaction = TableInteractionScope.maybeOf(context);
    final original = interaction?.originalWidth;
    if (interaction == null || original == null) {
      return;
    }
    final delta = globalPosition.dx - _startGlobalX;
    final next = original + (widget.invertDrag ? -delta : delta);
    interaction.updatePreview(
      next,
      minWidth: widget.tableNode.config.colMinimumWidth,
    );
    _tooltipPosition = globalPosition;
    _showTooltip(interaction);
  }

  void _commitDrag() {
    if (!_dragActive) {
      return;
    }
    _dragActive = false;
    _removeKeyHandler();
    _removeTooltip();

    final interaction = TableInteractionScope.maybeOf(context);
    final width = interaction?.previewWidth;
    final col = interaction?.resizingColIdx ?? widget.colIdx;
    final original = interaction?.originalWidth ??
        widget.tableNode.getColWidth(widget.colIdx);

    if (width != null && (width - original).abs() >= 0.5) {
      final selection = widget.editorState.selection;
      final transaction = widget.editorState.transaction;
      widget.tableNode.setColWidth(
        col,
        width,
        transaction: transaction,
        updateRowHeights: false,
      );
      transaction.afterSelection = selection ?? transaction.beforeSelection;
      widget.editorState.apply(
        transaction,
        skipHistoryDebounce: true,
      );
    }

    interaction?.endResize();
    if (mounted) {
      setState(() {});
    }
  }

  void _cancelDrag() {
    if (!_dragActive) {
      return;
    }
    _pointer = null;
    _dragActive = false;
    _removeKeyHandler();
    _removeTooltip();
    TableInteractionScope.maybeOf(context)?.endResize();
    if (mounted) {
      setState(() {});
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelDrag();
      return true;
    }
    return false;
  }

  void _removeKeyHandler() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
  }

  void _showTooltip(TableInteractionController interaction) {
    final width = interaction.previewWidth;
    if (width == null) {
      return;
    }
    _tooltip ??= OverlayEntry(builder: _buildTooltip);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    if (!_tooltipInserted) {
      overlay.insert(_tooltip!);
      _tooltipInserted = true;
    } else {
      _tooltip!.markNeedsBuild();
    }
  }

  Widget _buildTooltip(BuildContext context) {
    final interaction = TableInteractionScope.maybeOf(this.context);
    final width = interaction?.previewWidth;
    if (width == null) {
      return const SizedBox.shrink();
    }
    final atMin = interaction?.atMinWidth ?? false;
    final label = atMin
        ? '${width.round()} px (min)'
        : '${width.round()} px';

    return Positioned(
      left: _tooltipPosition.dx + 12,
      top: _tooltipPosition.dy - 32,
      child: IgnorePointer(
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(4),
          color: Theme.of(context).colorScheme.inverseSurface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onInverseSurface,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeTooltip() {
    _tooltip?.remove();
    _tooltip = null;
    _tooltipInserted = false;
  }
}

/// Touch resize mark: a small round plate with a two-way arrow, sitting on
/// the column's right border.
class TableResizeGrip extends StatelessWidget {
  const TableResizeGrip({
    super.key,
    this.color,
    this.warning = false,
  });

  /// Accent while dragging; null keeps the resting handle colors.
  final Color? color;
  /// At the minimum width.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final style = TableStyleScope.of(context);
    final accent = warning ? Colors.orange : color;
    return Container(
      width: tableMobileResizeGripSize,
      height: tableMobileResizeGripSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.handleBackgroundColor.withValues(alpha: 0.94),
        shape: BoxShape.circle,
        border: Border.all(
          color: accent ?? style.handlerColor.withValues(alpha: 0.22),
          width: accent == null ? 1 : 2,
        ),
      ),
      child: Icon(
        Icons.swap_horiz,
        size: 14,
        color: accent ?? style.handlerColor.withValues(alpha: 0.7),
      ),
    );
  }
}
