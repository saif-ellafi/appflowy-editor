import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/scroll/desktop_scroll_service.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/scroll/mobile_scroll_service.dart';
import 'package:appflowy_editor/src/editor/toolbar/mobile/utils/keyboard_height_observer.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScrollServiceWidget extends StatefulWidget {
  const ScrollServiceWidget({
    super.key,
    required this.editorScrollController,
    required this.child,
  });

  final EditorScrollController editorScrollController;

  final Widget child;

  @override
  State<ScrollServiceWidget> createState() => _ScrollServiceWidgetState();
}

class _ScrollServiceWidgetState extends State<ScrollServiceWidget>
    with WidgetsBindingObserver
    implements AppFlowyScrollService {
  final _forwardKey =
      GlobalKey(debugLabel: 'forward_to_platform_scroll_service');
  late AppFlowyScrollService forward =
      _forwardKey.currentState as AppFlowyScrollService;

  late EditorState editorState = context.read<EditorState>();

  @override
  late ScrollController scrollController = ScrollController();

  Selection? lastSelection;
  double _lastViewInsetsBottom = 0;

  @override
  void initState() {
    super.initState();
    editorState.selectionNotifier.addListener(_onSelectionChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scrollController.dispose();
    editorState.selectionNotifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!PlatformExtension.isMobile) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final keyboardGrew = bottomInset > _lastViewInsetsBottom + 1.0;
      _lastViewInsetsBottom = bottomInset;
      if (keyboardGrew) {
        _ensureSelectionVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: widget.editorScrollController,
      child: Builder(
        builder: (context) {
          if (PlatformExtension.isDesktopOrWeb) {
            return _buildDesktopScrollService(context);
          } else if (PlatformExtension.isMobile) {
            return _buildMobileScrollService(context);
          }
          throw UnimplementedError();
        },
      ),
    );
  }

  Widget _buildDesktopScrollService(
    BuildContext context,
  ) {
    return DesktopScrollService(
      key: _forwardKey,
      child: widget.child,
    );
  }

  Widget _buildMobileScrollService(
    BuildContext context,
  ) {
    return MobileScrollService(
      key: _forwardKey,
      child: widget.child,
    );
  }

  void _onSelectionChanged() {
    // should auto scroll after the cursor or selection updated.
    final selection = editorState.selection;
    final reason = editorState.selectionUpdateReason;
    // Remote transactions rebase the local selection so it stays valid, but
    // they must not make this client follow that selection in the viewport.
    if (selection == null ||
        reason == SelectionUpdateReason.remote ||
        reason == SelectionUpdateReason.selectAll) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectionRects = editorState.selectionRects();
      if (selectionRects.isEmpty) {
        return;
      }

      Rect targetRect;
      AxisDirection? direction;
      final dynamic dragMode =
          editorState.selectionExtraInfo?['selection_drag_mode'];

      // For desktop: if auto-scroller is already scrolling (from drag-to-select),
      // don't override it here. The desktop_selection_service handles drag scrolling.
      if (PlatformExtension.isDesktopOrWeb &&
          (editorState.autoScroller?.scrolling ?? false)) {
        return;
      }

      switch (dragMode?.toString()) {
        case 'MobileSelectionDragMode.leftSelectionHandle':
          targetRect = selectionRects.first;
          direction = AxisDirection.up;
          break;

        case 'MobileSelectionDragMode.rightSelectionHandle':
          targetRect = selectionRects.last;
          direction = AxisDirection.down;
          break;

        case 'MobileSelectionDragMode.cursor':
          targetRect = selectionRects.last;
          if (lastSelection != null) {
            final isMovingUp = selection.end.path < lastSelection!.end.path ||
                (selection.end.path.equals(lastSelection!.end.path) &&
                    selection.end.offset < lastSelection!.end.offset);
            direction = isMovingUp ? AxisDirection.up : AxisDirection.down;
          }
          break;

        default:
          targetRect = selectionRects.last;

          // sometimes moving up in a long single node may be not working
          // so we need to special handle this case.
          final isLastSelectionSingle = lastSelection?.isSingle ?? false;
          final isLastSelectionPathEqual =
              lastSelection?.start.path.equals(selection.start.path) ?? false;
          final isInSingleNode =
              isLastSelectionSingle && isLastSelectionPathEqual;
          if (selection.isForward && isInSingleNode) {
            targetRect = selectionRects.first;
          }
      }

      lastSelection = selection;

      final endTouchPoint = targetRect.centerRight;

      if (PlatformExtension.isMobile) {
        // Determine if this is a drag operation
        final bool isDragOperation = dragMode != null &&
            (dragMode.toString() ==
                    'MobileSelectionDragMode.leftSelectionHandle' ||
                dragMode.toString() ==
                    'MobileSelectionDragMode.rightSelectionHandle' ||
                dragMode.toString() == 'MobileSelectionDragMode.cursor');

        // Use animation for drag operations, instant for others
        final scrollDuration =
            isDragOperation ? const Duration(milliseconds: 2) : Duration.zero;

        // soft keyboard
        // workaround: wait for the soft keyboard to show up
        final keyboardDelay = KeyboardHeightObserver.currentKeyboardHeight == 0
            ? const Duration(milliseconds: 250)
            : Duration.zero;

        Future.delayed(keyboardDelay, () {
          if (_forwardKey.currentContext == null) {
            return;
          }
          if (isDragOperation) {
            // Mobile needs to continuously update scroll position/direction
            // during drag. Don't skip even if already scrolling, because
            // direction may have changed.
            startAutoScroll(
              endTouchPoint,
              edgeOffset: editorState.autoScrollEdgeOffset,
              direction: direction,
              duration: scrollDuration,
            );
            return;
          }
          // Edge-dragging only nudges a few pixels per tick and does not
          // continue after a tap. After the soft keyboard resizes the
          // viewport, jump the caret fully back into view.
          _ensureSelectionVisible();
        });
      } else {
        if (_forwardKey.currentContext == null) {
          return;
        }
        startAutoScroll(
          endTouchPoint,
          edgeOffset: editorState.autoScrollEdgeOffset,
          direction: direction,
          duration: Duration.zero,
        );
      }
    });
  }

  @override
  void disable() => forward.disable();

  @override
  double get dy => forward.dy;

  @override
  void enable() => forward.enable();

  @override
  double get maxScrollExtent => forward.maxScrollExtent;

  @override
  double get minScrollExtent => forward.minScrollExtent;

  @override
  double? get onePageHeight => forward.onePageHeight;

  @override
  int? get page => forward.page;

  @override
  void scrollTo(
    double dy, {
    Duration duration = const Duration(milliseconds: 150),
  }) =>
      forward.scrollTo(dy, duration: duration);

  @override
  void jumpTo(int index) => forward.jumpTo(index);

  @override
  void jumpToTop() {
    forward.jumpToTop();
  }

  @override
  void jumpToBottom() {
    forward.jumpToBottom();
  }

  @override
  void startAutoScroll(
    Offset offset, {
    double edgeOffset = 100,
    AxisDirection? direction,
    Duration? duration,
  }) {
    forward.startAutoScroll(
      offset,
      edgeOffset: edgeOffset,
      direction: direction,
      duration: duration,
    );
  }

  @override
  void stopAutoScroll() => forward.stopAutoScroll();

  @override
  void goBallistic(double velocity) => forward.goBallistic(velocity);

  void _ensureSelectionVisible() {
    if (editorState.disableAutoScroll) {
      return;
    }
    final selectionRects = editorState.selectionRects();
    if (selectionRects.isEmpty) {
      return;
    }
    final scrollBox = editorState.renderBox;
    if (scrollBox == null || !scrollBox.hasSize) {
      return;
    }

    final targetRect = selectionRects.last;
    final localSelection = Rect.fromPoints(
      scrollBox.globalToLocal(targetRect.topLeft),
      scrollBox.globalToLocal(targetRect.bottomRight),
    );
    final delta = computeSelectionVisibleScrollDelta(
      localSelection: localSelection,
      viewportSize: scrollBox.size,
      edgeOffset: editorState.autoScrollEdgeOffset,
    );
    if (delta == null || delta == 0) {
      return;
    }

    final targetOffset =
        widget.editorScrollController.offsetNotifier.value + delta;
    widget.editorScrollController.animateTo(
      offset: targetOffset,
      duration: Duration.zero,
    );
  }
}

/// How far to scroll so [localSelection] stays inside the viewport.
///
/// [localSelection] is in the scrollable viewport's local coordinates.
/// Positive scrolls down; negative scrolls up. Returns null if already visible.
double? computeSelectionVisibleScrollDelta({
  required Rect localSelection,
  required Size viewportSize,
  double edgeOffset = 0,
}) {
  if (viewportSize.height <= 0) {
    return null;
  }

  final visibleTop = edgeOffset;
  final visibleBottom = viewportSize.height - edgeOffset;
  if (visibleBottom <= visibleTop) {
    return localSelection.center.dy - viewportSize.height / 2;
  }
  if (localSelection.bottom > visibleBottom) {
    return localSelection.bottom - visibleBottom;
  }
  if (localSelection.top < visibleTop) {
    return localSelection.top - visibleTop;
  }
  return null;
}
