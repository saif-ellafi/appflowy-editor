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
  int _ensureGeneration = 0;

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

  void _ensureSelectionVisible({int attempt = 0}) {
    if (editorState.disableAutoScroll) {
      return;
    }
    if (attempt == 0) {
      _ensureGeneration++;
    }
    final generation = _ensureGeneration;
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final edge = editorState.autoScrollEdgeOffset;
    final bottomEdge = keyboardBottomScrollClearance(
      edgeOffset: edge,
      keyboardInset: keyboardInset,
      keyboardOverlap: keyboardViewportOverlap(
        viewport: scrollBox,
        screenSize: MediaQuery.sizeOf(context),
        keyboardInset: keyboardInset,
      ),
    );
    final delta = computeSelectionVisibleScrollDelta(
      localSelection: localSelection,
      viewportSize: scrollBox.size,
      edgeOffset: edge,
      bottomEdgeOffset: bottomEdge > 0 ? bottomEdge : edge,
    );
    if (delta != null && delta.abs() > 0.5) {
      final future = _scrollBy(delta, animate: attempt == 0);
      if (attempt < 2) {
        future.then((_) {
          if (!mounted || generation != _ensureGeneration) {
            return;
          }
          _ensureSelectionVisible(attempt: attempt + 1);
        });
      }
      return;
    }
    // Scroll extent can lag the keyboard inset / footer layout by a frame.
    if (attempt == 0 && keyboardInset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _ensureGeneration) {
          return;
        }
        _ensureSelectionVisible(attempt: 1);
      });
    }
  }

  Future<void> _scrollBy(double delta, {required bool animate}) {
    final controller = widget.editorScrollController;
    // Relative to the live scroll position. offsetNotifier can desync after
    // a keyboard hide/show; jumping to (staleNotifier + delta) looks like a
    // reset-to-top followed by a second scroll.
    const duration = Duration(milliseconds: 100);
    if (controller.shrinkWrap) {
      if (!controller.scrollController.hasClients) {
        return Future.value();
      }
      final position = controller.scrollController.position;
      final target = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (!animate) {
        controller.scrollController.jumpTo(target);
        return Future.value();
      }
      return controller.scrollController.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOut,
      );
    }
    return controller.scrollOffsetController.animateScroll(
      offset: delta,
      duration: animate ? duration : const Duration(milliseconds: 1),
      curve: Curves.easeOut,
    );
  }
}

/// Extra list extent below the last line while the IME is visible.
const double appFlowyEditorKeyboardCaretGap = 32.0;

/// How much of [viewport] sits under the software keyboard, in local px.
double keyboardViewportOverlap({
  required RenderBox viewport,
  required Size screenSize,
  required double keyboardInset,
}) {
  if (keyboardInset <= 0 || !viewport.hasSize) {
    return 0;
  }
  final boxBottom =
      viewport.localToGlobal(Offset(0, viewport.size.height)).dy;
  final keyboardTop = screenSize.height - keyboardInset;
  final covered = boxBottom - keyboardTop;
  return covered > 0 ? covered : 0;
}

/// Real bottom spacer height so the last line can sit above the keyboard.
///
/// Includes [keyboardOverlap] when the editor viewport is not fully resized
/// above the IME; a fixed pad cannot substitute for that measured amount.
double keyboardBottomScrollClearance({
  required double edgeOffset,
  required double keyboardInset,
  double keyboardOverlap = 0,
}) {
  if (keyboardInset <= 0) {
    return 0;
  }
  return edgeOffset + appFlowyEditorKeyboardCaretGap + keyboardOverlap;
}

/// How far to scroll so [localSelection] stays inside the viewport.
///
/// [localSelection] is in the scrollable viewport's local coordinates.
/// Positive scrolls down; negative scrolls up. Returns null if already visible.
double? computeSelectionVisibleScrollDelta({
  required Rect localSelection,
  required Size viewportSize,
  double edgeOffset = 0,
  double? bottomEdgeOffset,
}) {
  if (viewportSize.height <= 0) {
    return null;
  }

  final visibleTop = edgeOffset;
  final visibleBottom = viewportSize.height - (bottomEdgeOffset ?? edgeOffset);
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
