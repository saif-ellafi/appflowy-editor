import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/util/platform_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const _pageScroll = Duration(milliseconds: 150);

/// Page Up / Page Down. Scrolls one screen, then puts the caret on the line
/// that lands at the caret's old place on screen. Shift keeps the anchor and
/// moves the other end. On a phone the keys only scroll, as before.
KeyEventResult handlePageKey(
  EditorState editorState, {
  required bool up,
  required bool extend,
}) {
  if (PlatformExtension.isMobile) {
    if (up) {
      assert(false, 'pageUpCommand is not supported on mobile platform.');
      return KeyEventResult.ignored;
    }
    _scrollPage(editorState, up: false);
    return KeyEventResult.handled;
  }

  final scrollService = editorState.service.scrollService;
  final selection = editorState.selection;
  if (scrollService == null || selection == null) {
    return KeyEventResult.ignored;
  }
  final pageHeight = scrollService.onePageHeight;
  if (pageHeight == null) {
    return KeyEventResult.ignored;
  }

  final before = scrollService.dy;
  if (up && before <= 0) {
    _moveToDocumentEdge(editorState, up: true, extend: extend);
    return KeyEventResult.handled;
  }

  final target = up ? before - pageHeight : max(0, before) + pageHeight;
  final clamped = target.clamp(
      scrollService.minScrollExtent, scrollService.maxScrollExtent);
  final anchor = _caretPoint(editorState);
  scrollService.scrollTo(clamped.toDouble(), duration: _pageScroll);
  if ((clamped - before).abs() <= 0.5) {
    _moveToDocumentEdge(editorState, up: up, extend: extend);
    return KeyEventResult.handled;
  }

  final captured = anchor;
  Future<void>.delayed(const Duration(milliseconds: 200), () {
    if (editorState.isDisposed) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (editorState.isDisposed) {
        return;
      }
      _placeCaretAtPoint(editorState, captured, up: up, extend: extend);
    });
  });
  return KeyEventResult.handled;
}

KeyEventResult _scrollPage(EditorState editorState, {required bool up}) {
  final scrollService = editorState.service.scrollService;
  final pageHeight = scrollService?.onePageHeight;
  if (scrollService == null || pageHeight == null) {
    return KeyEventResult.ignored;
  }
  final before = up ? scrollService.dy : max(0, scrollService.dy);
  scrollService.scrollTo(
    up ? before - pageHeight : before + pageHeight,
    duration: _pageScroll,
  );
  return KeyEventResult.handled;
}

/// The caret at the moving end of the selection, in global coordinates.
/// A backward selection's moving end is its top, so this cannot use the
/// last highlight rect.
Offset? _caretPoint(EditorState editorState) {
  final end = editorState.selection?.end;
  if (end == null) {
    return null;
  }
  final selectable = editorState.getNodeAtPath(end.path)?.selectable;
  final rect = selectable?.getCursorRectInPosition(
    end,
    shiftWithBaseOffset: true,
  );
  if (selectable == null || rect == null) {
    return null;
  }
  return selectable
      .transformRectToGlobal(rect, shiftWithBaseOffset: true)
      .center;
}

void _placeCaretAtPoint(
  EditorState editorState,
  Offset? anchor, {
  required bool up,
  required bool extend,
}) {
  Position? position;
  if (anchor != null) {
    final node = editorState.service.selectionService.getNodeInOffset(anchor);
    final selectable = node?.selectable;
    if (selectable != null) {
      position = selectable.getPositionInOffset(anchor);
    }
  }
  position ??= _documentEdge(editorState, up: up);
  _apply(editorState, position, extend: extend);
}

void _moveToDocumentEdge(EditorState editorState,
    {required bool up, required bool extend}) {
  _apply(editorState, _documentEdge(editorState, up: up), extend: extend);
}

Position? _documentEdge(EditorState editorState, {required bool up}) {
  if (up) {
    final first = editorState.getFirstSelectable();
    if (first == null) {
      return null;
    }
    return first.$2.start(first.$1);
  }
  final last = editorState.getLastSelectable();
  if (last == null) {
    return null;
  }
  return last.$2.end(last.$1);
}

void _apply(EditorState editorState, Position? position,
    {required bool extend}) {
  final selection = editorState.selection;
  if (selection == null || position == null) {
    return;
  }
  // The page scroll already moved the view. Following the caret would scroll again.
  editorState.disableAutoScroll = true;
  editorState.updateSelectionWithReason(
    extend ? selection.copyWith(end: position) : Selection.collapsed(position),
    reason: SelectionUpdateReason.uiEvent,
  );
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!editorState.isDisposed) {
      editorState.disableAutoScroll = false;
    }
  });
}
