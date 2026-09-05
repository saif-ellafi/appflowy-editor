import 'package:appflowy_editor/src/editor/editor_component/service/scroll_service_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeSelectionVisibleScrollDelta', () {
    const viewport = Size(400, 600);

    test('returns null when the caret is already inside the padded viewport',
        () {
      const caret = Rect.fromLTWH(16, 200, 2, 20);
      expect(
        computeSelectionVisibleScrollDelta(
          localSelection: caret,
          viewportSize: viewport,
          edgeOffset: 20,
        ),
        isNull,
      );
    });

    test('scrolls down when the caret sits below the visible area', () {
      const caret = Rect.fromLTWH(16, 590, 2, 20);
      expect(
        computeSelectionVisibleScrollDelta(
          localSelection: caret,
          viewportSize: viewport,
          edgeOffset: 20,
        ),
        caret.bottom - (viewport.height - 20),
      );
    });

    test('scrolls up when the caret sits above the visible area', () {
      const caret = Rect.fromLTWH(16, 4, 2, 20);
      expect(
        computeSelectionVisibleScrollDelta(
          localSelection: caret,
          viewportSize: viewport,
          edgeOffset: 20,
        ),
        caret.top - 20,
      );
    });

    test('returns null for an empty viewport', () {
      expect(
        computeSelectionVisibleScrollDelta(
          localSelection: const Rect.fromLTWH(0, 0, 2, 20),
          viewportSize: Size.zero,
        ),
        isNull,
      );
    });
  });
}
