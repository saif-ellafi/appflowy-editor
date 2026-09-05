import 'package:appflowy_editor/src/editor/editor_component/service/scroll_service_widget.dart';
import 'package:appflowy_editor/src/flutter/scrollable_positioned_list/scrollable_positioned_list.dart';
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

    test('uses a larger bottom edge when the keyboard overlaps the viewport', () {
      const caret = Rect.fromLTWH(16, 500, 2, 20);
      expect(
        computeSelectionVisibleScrollDelta(
          localSelection: caret,
          viewportSize: viewport,
          edgeOffset: 20,
          bottomEdgeOffset: 120,
        ),
        caret.bottom - (viewport.height - 120),
      );
    });

    test('keyboard clearance is real extent only while the IME is visible', () {
      expect(
        keyboardBottomScrollClearance(edgeOffset: 20, keyboardInset: 0),
        0,
      );
      expect(
        keyboardBottomScrollClearance(edgeOffset: 20, keyboardInset: 300),
        20 + appFlowyEditorKeyboardCaretGap,
      );
    });

    test('keyboard clearance includes measured keyboard overlap', () {
      expect(
        keyboardBottomScrollClearance(
          edgeOffset: 20,
          keyboardInset: 300,
          keyboardOverlap: 100,
        ),
        20 + appFlowyEditorKeyboardCaretGap + 100,
      );
    });
  });

  testWidgets('last line reaches requested keyboard clearance', (tester) async {
    final items = ItemScrollController();
    final offsets = ScrollOffsetController();
    const viewportKey = ValueKey('viewport');
    const caretKey = ValueKey('caret');
    const edgeOffset = 20.0;
    final clearance = keyboardBottomScrollClearance(
      edgeOffset: edgeOffset,
      keyboardInset: 300,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: viewportKey,
              width: 400,
              height: 300,
              child: ScrollablePositionedList.builder(
                itemScrollController: items,
                scrollOffsetController: offsets,
                itemCount: 31,
                itemBuilder: (_, index) {
                  if (index == 30) {
                    return SizedBox(height: clearance);
                  }
                  return SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        key: index == 29 ? caretKey : null,
                        width: 2,
                        height: 20,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    items.jumpTo(index: 29);
    await tester.pump();

    double? delta() {
      final box = tester.getRect(find.byKey(viewportKey));
      final caret = tester.getRect(find.byKey(caretKey)).shift(-box.topLeft);
      return computeSelectionVisibleScrollDelta(
        localSelection: caret,
        viewportSize: box.size,
        edgeOffset: edgeOffset,
        bottomEdgeOffset: clearance,
      );
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final distance = delta();
      if (distance == null) {
        break;
      }
      offsets.animateScroll(
        offset: distance,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(
      delta(),
      isNull,
      reason: 'The requested ${clearance}px clearance must be reachable '
          'at the end of the document',
    );
  });

  testWidgets('last line reaches clearance with keyboard overlap',
      (tester) async {
    final items = ItemScrollController();
    final offsets = ScrollOffsetController();
    const viewportKey = ValueKey('viewport');
    const caretKey = ValueKey('caret');
    const edgeOffset = 20.0;
    const overlap = 100.0;
    final clearance = keyboardBottomScrollClearance(
      edgeOffset: edgeOffset,
      keyboardInset: 300,
      keyboardOverlap: overlap,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: viewportKey,
              width: 400,
              height: 300,
              child: ScrollablePositionedList.builder(
                itemScrollController: items,
                scrollOffsetController: offsets,
                itemCount: 31,
                itemBuilder: (_, index) {
                  if (index == 30) {
                    return SizedBox(height: clearance);
                  }
                  return SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        key: index == 29 ? caretKey : null,
                        width: 2,
                        height: 20,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    items.jumpTo(index: 29);
    await tester.pump();

    double? delta() {
      final box = tester.getRect(find.byKey(viewportKey));
      final caret = tester.getRect(find.byKey(caretKey)).shift(-box.topLeft);
      return computeSelectionVisibleScrollDelta(
        localSelection: caret,
        viewportSize: box.size,
        edgeOffset: edgeOffset,
        bottomEdgeOffset: clearance,
      );
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final distance = delta();
      if (distance == null) {
        break;
      }
      offsets.animateScroll(
        offset: distance,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(
      delta(),
      isNull,
      reason: 'The requested gap plus ${overlap}px overlap must be reachable '
          'at the end of the document',
    );
  });

  testWidgets('keyboardViewportOverlap is the covered portion of the viewport',
      (tester) async {
    const viewportKey = ValueKey('viewport');
    const screenSize = Size(800, 600);
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(key: viewportKey, width: 400, height: 300),
        ),
      ),
    );
    final box = tester.renderObject<RenderBox>(find.byKey(viewportKey));
    expect(
      keyboardViewportOverlap(
        viewport: box,
        screenSize: screenSize,
        keyboardInset: 200,
      ),
      200,
    );
    expect(
      keyboardViewportOverlap(
        viewport: box,
        screenSize: screenSize,
        keyboardInset: 0,
      ),
      0,
    );
  });
}
