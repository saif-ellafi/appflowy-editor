import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:appflowy_editor/src/editor/toolbar/desktop/items/utils/overlay_util.dart';
import 'package:flutter/material.dart';

void showActionMenu(
  BuildContext context,
  Node node,
  EditorState editorState,
  int position,
  TableDirection dir,
) {
  final style = TableStyleScope.of(context);
  final Offset pos =
      (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero);
  final rect = Rect.fromLTWH(
    pos.dx,
    pos.dy,
    context.size?.width ?? 0,
    context.size?.height ?? 0,
  );
  OverlayEntry? overlay;

  var (top, bottom, left) = positionFromRect(rect, editorState);
  top = top != null ? top - 35 : top;

  void dismissOverlay() {
    overlay?.remove();
    overlay = null;
  }

  overlay = FullScreenOverlayEntry(
    top: top,
    bottom: bottom,
    left: left,
    builder: (overlayContext) {
      return _tableActionOverlay(
        overlayContext,
        style,
        children: [
          _menuItem(
              overlayContext,
              style,
              dir == TableDirection.col
                  ? AppFlowyEditorL10n.current.colAddBefore
                  : AppFlowyEditorL10n.current.rowAddBefore,
              dir == TableDirection.col
                  ? Icons.first_page
                  : Icons.vertical_align_top, () {
            TableActions.add(node, position, editorState, dir);
            dismissOverlay();
          }),
          _menuItem(
              overlayContext,
              style,
              dir == TableDirection.col
                  ? AppFlowyEditorL10n.current.colAddAfter
                  : AppFlowyEditorL10n.current.rowAddAfter,
              dir == TableDirection.col
                  ? Icons.last_page
                  : Icons.vertical_align_bottom, () {
            TableActions.add(node, position + 1, editorState, dir);
            dismissOverlay();
          }),
          _menuItem(
              overlayContext,
              style,
              dir == TableDirection.col
                  ? AppFlowyEditorL10n.current.colRemove
                  : AppFlowyEditorL10n.current.rowRemove,
              Icons.delete, () {
            TableActions.delete(node, position, editorState, dir);
            dismissOverlay();
          }),
          _menuItem(
              overlayContext,
              style,
              dir == TableDirection.col
                  ? AppFlowyEditorL10n.current.colDuplicate
                  : AppFlowyEditorL10n.current.rowDuplicate,
              Icons.content_copy, () {
            TableActions.duplicate(node, position, editorState, dir);
            dismissOverlay();
          }),
          _menuItem(
            overlayContext,
            style,
            AppFlowyEditorL10n.current.backgroundColor,
            Icons.format_color_fill,
            () {
              final cell = dir == TableDirection.col
                  ? getCellNode(node, position, 0)
                  : getCellNode(node, 0, position);
              final key = dir == TableDirection.col
                  ? TableCellBlockKeys.colBackgroundColor
                  : TableCellBlockKeys.rowBackgroundColor;

              _showColorMenu(
                overlayContext,
                (color) async {
                  await TableActions.setBgColor(
                    node,
                    position,
                    editorState,
                    color,
                    dir,
                  );
                },
                top: top,
                bottom: bottom,
                left: left,
                selectedColorHex: cell?.attributes[key],
              );
              dismissOverlay();
            },
          ),
          _menuItem(
              overlayContext,
              style,
              dir == TableDirection.col
                  ? AppFlowyEditorL10n.current.colClear
                  : AppFlowyEditorL10n.current.rowClear,
              Icons.clear, () {
            TableActions.clear(node, position, editorState, dir);
            dismissOverlay();
          }),
        ],
      );
    },
  ).build();
  Overlay.of(context, rootOverlay: true).insert(overlay!);
}

Widget _tableActionOverlay(
  BuildContext context,
  TableStyle style, {
  required List<Widget> children,
}) {
  return Container(
    width: 200,
    height: 230,
    decoration: BoxDecoration(
      color: style.menuBackgroundColor ?? Theme.of(context).cardColor,
      borderRadius: style.menuBorderRadius ?? BorderRadius.circular(6),
      border: style.menuBorderColor != null
          ? Border.all(color: style.menuBorderColor!)
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}

Widget _menuItem(
  BuildContext context,
  TableStyle style,
  String text,
  IconData icon,
  Function() action,
) {
  final foreground = style.menuForegroundColor ??
      Theme.of(context).textTheme.labelLarge?.color;
  return SizedBox(
    height: 36,
    child: TextButton.icon(
      onPressed: () {
        action();
      },
      icon: Icon(icon, color: foreground ?? Theme.of(context).iconTheme.color),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) {
            if (states.contains(WidgetState.hovered)) {
              return (foreground ?? Theme.of(context).hoverColor)
                  .withValues(alpha: 0.12);
            }
            return Colors.transparent;
          },
        ),
        foregroundColor: WidgetStateProperty.all(foreground),
      ),
      label: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: TextStyle(color: foreground),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showColorMenu(
  BuildContext context,
  Function(String?) action, {
  double? top,
  double? bottom,
  double? left,
  String? selectedColorHex,
}) {
  OverlayEntry? overlay;

  void dismissOverlay() {
    overlay?.remove();
    overlay = null;
  }

  overlay = FullScreenOverlayEntry(
    top: top,
    bottom: bottom,
    left: left,
    builder: (context) {
      return ColorPicker(
        title: AppFlowyEditorL10n.current.highlightColor,
        selectedColorHex: selectedColorHex,
        colorOptions: generateHighlightColorOptions(),
        onSubmittedColorHex: (color, _) {
          action(color);
          dismissOverlay();
        },
        resetText: AppFlowyEditorL10n.current.clearHighlightColor,
        resetIconName: 'clear_highlight_color',
      );
    },
  ).build();
  Overlay.of(context, rootOverlay: true).insert(overlay!);
}
