import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/base_component/widget/ignore_parent_gesture.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:appflowy_editor/src/flutter/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PageBlockKeys {
  static const String type = 'page';
}

Node pageNode({
  required Iterable<Node> children,
  Attributes attributes = const {},
}) {
  return Node(
    type: PageBlockKeys.type,
    children: children,
    attributes: attributes,
  );
}

class PageBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return PageBlockComponent(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      header: blockComponentContext.header,
      footer: blockComponentContext.footer,
      wrapper: blockComponentContext.wrapper,
    );
  }
}

class PageBlockComponent extends BlockComponentStatelessWidget {
  const PageBlockComponent({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.header,
    this.footer,
    this.wrapper,
  });

  final Widget? header;
  final Widget? footer;
  final BlockComponentWrapper? wrapper;

  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorState>();
    final scrollController = context.read<EditorScrollController?>();
    final items = node.children;

    if (scrollController == null || scrollController.shrinkWrap) {
      return SingleChildScrollView(
        child: Builder(
          builder: (context) {
            final scroller = Scrollable.maybeOf(context);
            if (scroller != null) {
              editorState.updateAutoScroller(scroller);
            }

            return Column(
              children: [
                if (header != null) header!,
                ...items.map(
                  (e) {
                    Widget child = editorState.renderer.build(context, e);
                    if (wrapper != null) {
                      child = wrapper!(context, node: e, child: child);
                    }

                    return Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            editorState.editorStyle.maxWidth ?? double.infinity,
                      ),
                      padding: editorState.editorStyle.padding,
                      child: child,
                    );
                  },
                ),
                if (footer != null) footer!,
                if (PlatformExtension.isMobile)
                  _keyboardClearance(context, editorState),
              ],
            );
          },
        ),
      );
    } else {
      final hasHeader = header != null;
      final hasFooter = footer != null;
      final hasClearance = PlatformExtension.isMobile;
      final extentCount =
          (hasHeader ? 1 : 0) + (hasFooter ? 1 : 0) + (hasClearance ? 1 : 0);

      return ScrollablePositionedList.builder(
        shrinkWrap: scrollController.shrinkWrap,
        itemCount: items.length + extentCount,
        itemBuilder: (context, index) {
          editorState.updateAutoScroller(Scrollable.of(context));
          if (hasHeader && index == 0) {
            return IgnoreEditorSelectionGesture(
              child: header!,
            );
          }

          final lastIndex = items.length + extentCount - 1;
          if (hasClearance && index == lastIndex) {
            return _keyboardClearance(context, editorState);
          }
          if (hasFooter && index == lastIndex - (hasClearance ? 1 : 0)) {
            return IgnoreEditorSelectionGesture(
              child: footer!,
            );
          }

          final node = items[index - (header != null ? 1 : 0)];
          Widget child = editorState.renderer.build(
            context,
            node,
          );
          if (wrapper != null) {
            child = wrapper!(context, node: node, child: child);
          }

          return Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: editorState.editorStyle.maxWidth ?? double.infinity,
              ),
              padding: editorState.editorStyle.padding,
              child: child,
            ),
          );
        },
        itemScrollController: scrollController.itemScrollController,
        scrollOffsetController: scrollController.scrollOffsetController,
        itemPositionsListener: scrollController.itemPositionsListener,
        scrollOffsetListener: scrollController.scrollOffsetListener,
      );
    }
  }

  Widget _keyboardClearance(BuildContext context, EditorState editorState) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final viewport = editorState.renderBox;
    return IgnoreEditorSelectionGesture(
      child: SizedBox(
        height: keyboardBottomScrollClearance(
          edgeOffset: editorState.autoScrollEdgeOffset,
          keyboardInset: keyboardInset,
          keyboardOverlap: viewport == null
              ? 0
              : keyboardViewportOverlap(
                  viewport: viewport,
                  screenSize: MediaQuery.sizeOf(context),
                  keyboardInset: keyboardInset,
                ),
        ),
      ),
    );
  }
}
