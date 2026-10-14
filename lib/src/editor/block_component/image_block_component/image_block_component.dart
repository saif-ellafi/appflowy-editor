import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ImageBlockKeys {
  const ImageBlockKeys._();

  static const String type = 'image';

  /// The align data of a image block.
  ///
  /// The value is a String.
  /// left, center, right
  static const String align = 'align';

  /// The image src of a image block.
  ///
  /// The value is a String.
  /// It can be a url or a base64 string(web).
  static const String url = 'url';

  /// The height of a image block.
  ///
  /// The value is a double.
  static const String width = 'width';

  /// The width of a image block.
  ///
  /// The value is a double.
  static const String height = 'height';
}

Node imageNode({
  required String url,
  String align = 'center',
  double? height,
  double? width,
}) {
  return Node(
    type: ImageBlockKeys.type,
    attributes: {
      ImageBlockKeys.url: url,
      ImageBlockKeys.align: align,
      ImageBlockKeys.height: height,
      ImageBlockKeys.width: width,
    },
  );
}

typedef ImageBlockComponentMenuBuilder = Widget Function(
  Node node,
  ImageBlockComponentWidgetState state,
);

class ImageBlockComponentBuilder extends BlockComponentBuilder {
  ImageBlockComponentBuilder({
    super.configuration,
    this.showMenu = false,
    this.menuBuilder,
    this.showSelection = false,
  });

  /// Whether to show the menu of this block component.
  final bool showMenu;

  ///
  final ImageBlockComponentMenuBuilder? menuBuilder;

  /// Outlines the picture while it is selected, and lets the caret sit before
  /// or after it: a click beside the picture places the caret on that side, a
  /// click on the picture selects it.
  ///
  /// Off by default: a click selects the picture without showing it.
  final bool showSelection;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;

    return ImageBlockComponentWidget(
      key: node.key,
      node: node,
      showActions: showActions(node),
      configuration: configuration,
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
      showMenu: showMenu,
      menuBuilder: menuBuilder,
      showSelection: showSelection,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

class ImageBlockComponentWidget extends BlockComponentStatefulWidget {
  const ImageBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.showMenu = false,
    this.menuBuilder,
    this.showSelection = false,
  });

  /// Whether to show the menu of this block component.
  final bool showMenu;

  final ImageBlockComponentMenuBuilder? menuBuilder;

  /// See [ImageBlockComponentBuilder.showSelection].
  final bool showSelection;

  @override
  State<ImageBlockComponentWidget> createState() =>
      ImageBlockComponentWidgetState();
}

class ImageBlockComponentWidgetState extends State<ImageBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final imageKey = GlobalKey();

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  late final editorState = Provider.of<EditorState>(context, listen: false);

  final showActionsNotifier = ValueNotifier<bool>(false);

  bool alwaysShowMenu = false;

  @override
  void dispose() {
    showActionsNotifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final attributes = node.attributes;
    final src = attributes[ImageBlockKeys.url];

    final alignment = AlignmentExtension.fromString(
      attributes[ImageBlockKeys.align] ?? 'center',
    );
    final width = attributes[ImageBlockKeys.width]?.toDouble() ??
        MediaQuery.of(context).size.width;
    final height = attributes[ImageBlockKeys.height]?.toDouble();

    Widget child = ResizableImage(
      src: src,
      width: width,
      height: height,
      editable: editorState.editable,
      alignment: alignment,
      onResize: (width) {
        final transaction = editorState.transaction
          ..updateNode(node, {
            ImageBlockKeys.width: width,
          });
        editorState.apply(transaction);
      },
    );

    child = Padding(
      key: imageKey,
      padding: padding,
      child: child,
    );

    if (widget.showSelection) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          ValueListenableBuilder<Selection?>(
            valueListenable: editorState.selectionNotifier,
            builder: (context, selection, _) {
              final picture = _pictureRect();
              if (selection == null ||
                  picture == null ||
                  !_pictureSelected(selection)) {
                return const SizedBox.shrink();
              }

              return Positioned.fromRect(
                rect: picture.inflate(2),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: editorState.editorStyle.selectionColor
                            .withValues(alpha: 1),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
      supportTypes: widget.showSelection
          ? const [
              BlockSelectionType.block,
              BlockSelectionType.cursor,
            ]
          : const [
              BlockSelectionType.block,
            ],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    if (widget.showMenu && widget.menuBuilder != null) {
      child = MouseRegion(
        onEnter: (_) => showActionsNotifier.value = true,
        onExit: (_) {
          if (!alwaysShowMenu) {
            showActionsNotifier.value = false;
          }
        },
        hitTestBehavior: HitTestBehavior.opaque,
        opaque: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: showActionsNotifier,
          builder: (context, value, child) {
            return Stack(
              children: [
                BlockSelectionContainer(
                  node: node,
                  delegate: this,
                  listenable: editorState.selectionNotifier,
                  remoteSelection: editorState.remoteSelections,
                  cursorColor: editorState.editorStyle.cursorColor,
                  selectionColor: editorState.editorStyle.selectionColor,
                  child: child!,
                ),
                if (value) widget.menuBuilder!(widget.node, this),
              ],
            );
          },
          child: child,
        ),
      );
    }

    child = Padding(
      padding: margin,
      child: child,
    );

    return child;
  }

  @override
  Position start() => Position(path: widget.node.path);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) {
    if (!widget.showSelection) {
      return end();
    }
    final picture = _pictureRect();
    final local = _imageLocal(start);
    if (picture == null || local == null) {
      return end();
    }

    return local.dx < picture.center.dx ? this.start() : end();
  }

  @override
  Selection? getSelectionOnTap(Offset offset) {
    if (!widget.showSelection) {
      return null;
    }
    final picture = _pictureRect();
    final local = _imageLocal(offset);
    if (picture != null &&
        local != null &&
        local.dx >= picture.left &&
        local.dx <= picture.right) {
      return Selection(start: start(), end: end());
    }

    return Selection.collapsed(getPositionInOffset(offset));
  }

  @override
  bool get shouldCursorBlink => widget.showSelection;

  @override
  CursorStyle get cursorStyle =>
      widget.showSelection ? CursorStyle.verticalLine : CursorStyle.cover;

  /// Where the picture is drawn, in the coordinates of the block's selection
  /// area (inside the margin, around the padding).
  Rect? _pictureRect() {
    final box = imageKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }
    final inner = padding.deflateRect(Offset.zero & box.size);
    final attributes = node.attributes;
    final width = min(
      inner.width,
      max(30.0, (attributes[ImageBlockKeys.width] as num?)?.toDouble() ?? inner.width),
    );
    final alignment = AlignmentExtension.fromString(
      attributes[ImageBlockKeys.align] ?? 'center',
    );
    final left = inner.left + (inner.width - width) * (alignment.x + 1) / 2;

    return Rect.fromLTWH(left, inner.top, width, inner.height);
  }

  /// Whether [selection] takes in the picture: a caret beside it doesn't, nor
  /// does a range that only touches its outer edge.
  bool _pictureSelected(Selection selection) {
    final range = selection.normalized;
    final path = node.path;
    if (range.isCollapsed || !path.inSelection(range)) {
      return false;
    }
    final startsAfter = range.start.path.equals(path) && range.start.offset > 0;
    final endsBefore = range.end.path.equals(path) && range.end.offset == 0;

    return !startsAfter && !endsBefore;
  }

  Offset? _imageLocal(Offset global) {
    final box = imageKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }

    return box.globalToLocal(global);
  }

  @override
  Rect getBlockRect({
    bool shiftWithBaseOffset = false,
  }) {
    final imageBox = imageKey.currentContext?.findRenderObject();
    if (imageBox is RenderBox) {
      return Offset.zero & imageBox.size;
    }

    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    if (widget.showSelection) {
      final picture = _pictureRect();
      if (picture == null) {
        return null;
      }
      // A thin caret just outside the picture's edge.
      const caretWidth = 2.0;
      final x = position.offset == 0
          ? max(0.0, picture.left - caretWidth - 2)
          : picture.right + 2;

      return Rect.fromLTWH(x, picture.top, caretWidth, picture.height);
    }
    if (_renderBox == null) {
      return null;
    }
    final size = _renderBox!.size;

    return Rect.fromLTWH(-size.width / 2.0, 0, size.width, size.height);
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (widget.showSelection) {
      final picture = _pictureRect();
      if (picture == null || !_pictureSelected(selection)) {
        return [];
      }

      return [picture];
    }
    if (_renderBox == null) {
      return [];
    }
    final parentBox = context.findRenderObject();
    final imageBox = imageKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && imageBox is RenderBox) {
      return [
        imageBox.localToGlobal(Offset.zero, ancestor: parentBox) &
            imageBox.size,
      ];
    }

    return [Offset.zero & _renderBox!.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  }) =>
      _renderBox!.localToGlobal(offset);
}

extension AlignmentExtension on Alignment {
  static Alignment fromString(String name) {
    switch (name) {
      case 'left':
        return Alignment.centerLeft;

      case 'right':
        return Alignment.centerRight;

      default:
        return Alignment.center;
    }
  }
}
