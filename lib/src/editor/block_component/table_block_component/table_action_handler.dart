import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_action_menu.dart';
import 'package:flutter/material.dart';

class TableActionHandler extends StatefulWidget {
  const TableActionHandler({
    super.key,
    this.visible = false,
    required this.node,
    required this.editorState,
    required this.position,
    required this.dir,
    this.menuBuilder,
  });

  final bool visible;
  final Node node;
  final EditorState editorState;
  final int position;
  final TableDirection dir;
  final TableBlockComponentMenuBuilder? menuBuilder;

  @override
  State<TableActionHandler> createState() => _TableActionHandlerState();
}

class _TableActionHandlerState extends State<TableActionHandler> {
  bool _menuShown = false;

  @override
  Widget build(BuildContext context) {
    final show =
        (widget.visible || _menuShown) && widget.editorState.editable;
    final horizontal = widget.dir == TableDirection.col;
    return SizedBox(
      width: horizontal ? tableHandleOvalLength : tableHandleOvalThickness,
      height: horizontal ? tableHandleOvalThickness : tableHandleOvalLength,
      child: show
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: widget.menuBuilder != null
                  ? widget.menuBuilder!(
                      widget.node,
                      widget.editorState,
                      widget.position,
                      widget.dir,
                      () => _menuShown = true,
                      () => setState(() => _menuShown = false),
                    )
                  : GestureDetector(
                      onTap: () => showActionMenu(
                        context,
                        widget.node,
                        widget.editorState,
                        widget.position,
                        widget.dir,
                      ),
                      child: TableBorderHandle(
                        axis: horizontal ? Axis.horizontal : Axis.vertical,
                      ),
                    ),
            )
          : const SizedBox.shrink(),
    );
  }
}

Widget tableChromeChip(BuildContext context, {required Widget child}) {
  final style = TableStyleScope.of(context);
  final color = style.handlerColor;
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: SizedBox(
      width: tableHandleSize,
      height: tableHandleSize,
      child: Material(
        color: style.handleBackgroundColor.withValues(alpha: 0.94),
        elevation: 0,
        shape: CircleBorder(
          side: BorderSide(
            color: color.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: FittedBox(
              fit: BoxFit.contain,
              child: IconTheme(
                data: IconThemeData(
                  size: 12,
                  color: color.withValues(alpha: 0.55),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Border-centered menu mark: stadium plate + three-dot grip.
class TableBorderHandle extends StatelessWidget {
  const TableBorderHandle({
    super.key,
    required this.axis,
  });

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final style = TableStyleScope.of(context);
    final horizontal = axis == Axis.horizontal;
    final width = horizontal ? tableHandleOvalLength : tableHandleOvalThickness;
    final height = horizontal ? tableHandleOvalThickness : tableHandleOvalLength;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.handleBackgroundColor.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: style.handlerColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: CustomPaint(
        size: Size(width, height),
        painter: _TableMoreDotsPainter(
          axis: axis,
          color: style.handlerColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _TableMoreDotsPainter extends CustomPainter {
  const _TableMoreDotsPainter({
    required this.axis,
    required this.color,
  });

  final Axis axis;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const radius = 1.35;
    const gap = 3.4;
    final cx = size.width / 2;
    final cy = size.height / 2;
    if (axis == Axis.horizontal) {
      canvas.drawCircle(Offset(cx - gap, cy), radius, paint);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
      canvas.drawCircle(Offset(cx + gap, cy), radius, paint);
    } else {
      canvas.drawCircle(Offset(cx, cy - gap), radius, paint);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
      canvas.drawCircle(Offset(cx, cy + gap), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_TableMoreDotsPainter oldDelegate) {
    return oldDelegate.axis != axis || oldDelegate.color != color;
  }
}
