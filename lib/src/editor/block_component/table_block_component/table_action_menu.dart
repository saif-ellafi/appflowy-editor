import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const double _menuWidth = 200;
const double _menuHeight = 230;
const double _menuGap = 6;

void showActionMenu(
  BuildContext context,
  Node node,
  EditorState editorState,
  int position,
  TableDirection dir,
) {
  final style = TableStyleScope.of(context);
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return;
  }

  // Free vertical space so the popup can sit near the handle instead of under
  // the soft keyboard. Positional chrome deserves a positional menu.
  FocusManager.instance.primaryFocus?.unfocus();

  final anchor = renderObject.localToGlobal(Offset.zero) & renderObject.size;
  final media = MediaQuery.of(context);

  void present() {
    if (!context.mounted) {
      return;
    }
    final latestMedia = MediaQuery.of(context);
    final placement = _placeNearAnchor(
      anchor: anchor,
      menuSize: const Size(_menuWidth, _menuHeight),
      viewport: latestMedia.size,
      padding: latestMedia.padding,
      // After unfocus, insets may still be animating down; prefer the smaller
      // remaining keyboard so we don't leave a huge empty gap.
      keyboardInset: latestMedia.viewInsets.bottom,
    );
    _insertActionOverlay(
      context,
      style,
      node: node,
      editorState: editorState,
      position: position,
      dir: dir,
      placement: placement,
    );
  }

  // Let one frame clear (or shrink) the keyboard before measuring.
  if (media.viewInsets.bottom > 0) {
    SchedulerBinding.instance.addPostFrameCallback((_) => present());
  } else {
    present();
  }
}

void _insertActionOverlay(
  BuildContext context,
  TableStyle style, {
  required Node node,
  required EditorState editorState,
  required int position,
  required TableDirection dir,
  required _MenuPlacement placement,
}) {
  OverlayEntry? overlay;

  void dismissOverlay() {
    overlay?.remove();
    overlay = null;
  }

  overlay = FullScreenOverlayEntry(
    top: placement.top,
    bottom: placement.bottom,
    left: placement.left,
    builder: (overlayContext) {
      return _tableActionOverlay(
        overlayContext,
        style,
        children: _menuActions(
          overlayContext,
          style,
          node: node,
          editorState: editorState,
          position: position,
          dir: dir,
          dismiss: dismissOverlay,
          showColorPicker: (selectedColorHex, onColor) {
            _showColorOverlay(
              overlayContext,
              top: placement.top,
              bottom: placement.bottom,
              left: placement.left,
              selectedColorHex: selectedColorHex,
              onColor: onColor,
            );
            dismissOverlay();
          },
        ),
      );
    },
  ).build();
  Overlay.of(context, rootOverlay: true).insert(overlay!);
}

class _MenuPlacement {
  const _MenuPlacement({this.top, this.bottom, required this.left});

  final double? top;
  final double? bottom;
  final double left;
}

/// Prefer below the anchor; flip above when the keyboard or viewport would clip.
_MenuPlacement _placeNearAnchor({
  required Rect anchor,
  required Size menuSize,
  required Size viewport,
  required EdgeInsets padding,
  required double keyboardInset,
}) {
  final usableBottom = viewport.height - keyboardInset - padding.bottom;
  final usableTop = padding.top;
  final spaceBelow = usableBottom - anchor.bottom - _menuGap;
  final spaceAbove = anchor.top - usableTop - _menuGap;

  final placeBelow =
      spaceBelow >= menuSize.height || spaceBelow >= spaceAbove;

  double? top;
  double? bottom;
  if (placeBelow) {
    final rawTop = anchor.bottom + _menuGap;
    final maxTop = usableBottom - menuSize.height;
    top = maxTop < usableTop
        ? usableTop
        : rawTop.clamp(usableTop, maxTop).toDouble();
  } else {
    // Positioned.bottom is distance from the overlay's bottom edge.
    final rawBottom = viewport.height - anchor.top + _menuGap;
    final minBottom = keyboardInset + padding.bottom;
    final maxBottom = viewport.height - usableTop - menuSize.height;
    bottom = maxBottom < minBottom
        ? minBottom
        : rawBottom.clamp(minBottom, maxBottom).toDouble();
  }

  final maxLeft = viewport.width - menuSize.width - padding.right;
  final left = maxLeft < padding.left
      ? padding.left
      : anchor.left.clamp(padding.left, maxLeft).toDouble();

  return _MenuPlacement(top: top, bottom: bottom, left: left);
}

List<Widget> _menuActions(
  BuildContext context,
  TableStyle style, {
  required Node node,
  required EditorState editorState,
  required int position,
  required TableDirection dir,
  required VoidCallback dismiss,
  required void Function(
    String? selectedColorHex,
    Future<void> Function(String?) onColor,
  ) showColorPicker,
}) {
  return [
    _menuItem(
      context,
      style,
      dir == TableDirection.col
          ? AppFlowyEditorL10n.current.colAddBefore
          : AppFlowyEditorL10n.current.rowAddBefore,
      dir == TableDirection.col ? Icons.first_page : Icons.vertical_align_top,
      () {
        TableActions.add(node, position, editorState, dir);
        dismiss();
      },
    ),
    _menuItem(
      context,
      style,
      dir == TableDirection.col
          ? AppFlowyEditorL10n.current.colAddAfter
          : AppFlowyEditorL10n.current.rowAddAfter,
      dir == TableDirection.col
          ? Icons.last_page
          : Icons.vertical_align_bottom,
      () {
        TableActions.add(node, position + 1, editorState, dir);
        dismiss();
      },
    ),
    _menuItem(
      context,
      style,
      dir == TableDirection.col
          ? AppFlowyEditorL10n.current.colRemove
          : AppFlowyEditorL10n.current.rowRemove,
      Icons.delete,
      () {
        TableActions.delete(node, position, editorState, dir);
        dismiss();
      },
    ),
    _menuItem(
      context,
      style,
      dir == TableDirection.col
          ? AppFlowyEditorL10n.current.colDuplicate
          : AppFlowyEditorL10n.current.rowDuplicate,
      Icons.content_copy,
      () {
        TableActions.duplicate(node, position, editorState, dir);
        dismiss();
      },
    ),
    _menuItem(
      context,
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

        showColorPicker(
          cell?.attributes[key] as String?,
          (color) => TableActions.setBgColor(
            node,
            position,
            editorState,
            color,
            dir,
          ),
        );
      },
    ),
    _menuItem(
      context,
      style,
      dir == TableDirection.col
          ? AppFlowyEditorL10n.current.colClear
          : AppFlowyEditorL10n.current.rowClear,
      Icons.clear,
      () {
        TableActions.clear(node, position, editorState, dir);
        dismiss();
      },
    ),
  ];
}

Widget _tableActionOverlay(
  BuildContext context,
  TableStyle style, {
  required List<Widget> children,
}) {
  return Container(
    width: _menuWidth,
    height: _menuHeight,
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

void _showColorOverlay(
  BuildContext context, {
  double? top,
  double? bottom,
  double? left,
  String? selectedColorHex,
  required Future<void> Function(String?) onColor,
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
        onSubmittedColorHex: (color, _) async {
          await onColor(color);
          dismissOverlay();
        },
        resetText: AppFlowyEditorL10n.current.clearHighlightColor,
        resetIconName: 'clear_highlight_color',
      );
    },
  ).build();
  Overlay.of(context, rootOverlay: true).insert(overlay!);
}

/// Test seam for keyboard-aware placement.
@visibleForTesting
({double? top, double? bottom, double left}) debugPlaceTableActionMenu({
  required Rect anchor,
  required Size menuSize,
  required Size viewport,
  EdgeInsets padding = EdgeInsets.zero,
  double keyboardInset = 0,
}) {
  final placement = _placeNearAnchor(
    anchor: anchor,
    menuSize: menuSize,
    viewport: viewport,
    padding: padding,
    keyboardInset: keyboardInset,
  );
  return (top: placement.top, bottom: placement.bottom, left: placement.left);
}
