import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/delta_input_on_insert_impl.dart';
import 'package:appflowy_editor/src/render/selection/cursor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A 1×1 PNG, drawn from memory so no file or network is needed.
const _picture =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppFlowyEditorLocalizations.load(const Locale('en'));
  });

  Future<EditorState> pumpEditor(
    WidgetTester tester, {
    bool showSelection = true,
    List<Node>? before,
    List<Node>? after,
  }) async {
    final editorState = EditorState(
      document: Document.blank()
        ..insert([0], [
          ...before ?? [paragraphNode(text: 'Above')],
          imageNode(url: _picture, width: 100, height: 100),
          ...after ?? [paragraphNode(text: 'Below')],
        ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFlowyEditor(
            editorState: editorState,
            blockComponentBuilders: {
              ...standardBlockComponentBuilderMap,
              ImageBlockKeys.type:
                  ImageBlockComponentBuilder(showSelection: showSelection),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return editorState;
  }

  // The picture is 100×100 and centred; its bytes aren't decoded in tests,
  // so its place comes from the block around it.
  Rect pictureRect(WidgetTester tester) => Rect.fromCenter(
        center: tester.getCenter(find.byType(ResizableImage)),
        width: 100,
        height: 100,
      );

  int imageIndex(EditorState editorState) => editorState.document.root.children
      .indexWhere((node) => node.type == ImageBlockKeys.type);

  Future<void> tapAt(WidgetTester tester, Offset offset) async {
    // Apart from the previous tap, or the two make a double tap.
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(offset);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  // The outline drawn around a selected picture.
  bool selectionPainted(WidgetTester tester) => find
      .byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null,
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('a click on the picture selects it and shows it', (tester) async {
    final editorState = await pumpEditor(tester);
    expect(selectionPainted(tester), isFalse);

    await tapAt(tester, pictureRect(tester).center);

    expect(
      editorState.selection,
      Selection(start: Position(path: [1]), end: Position(path: [1], offset: 1)),
    );
    expect(selectionPainted(tester), isTrue);

    await press(tester, LogicalKeyboardKey.backspace);
    expect(imageIndex(editorState), -1);
  });

  // The resize handles, drawn on both sides of the picture.
  int handlesPainted(WidgetTester tester) => find
      .byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints == const BoxConstraints.tightFor(width: 5, height: 40),
      )
      .evaluate()
      .length;

  testWidgets('a selected picture shows its resize handles without a hover',
      (tester) async {
    await pumpEditor(tester);
    final rect = pictureRect(tester);
    expect(handlesPainted(tester), 0);

    await tapAt(tester, rect.center);
    expect(handlesPainted(tester), 2);

    // A caret beside it isn't selecting it.
    await tapAt(tester, rect.centerLeft - const Offset(40, 0));
    expect(handlesPainted(tester), 0);
  });

  testWidgets('the outline follows the picture while it is resized',
      (tester) async {
    final editorState = await pumpEditor(tester);
    final rect = pictureRect(tester);
    await tapAt(tester, rect.center);

    // The outline, not the handles (bordered too).
    Rect outline() => tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border != null &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(4),
          ),
        );
    expect(outline().width, 104);

    // The right handle, dragged 40px in; past the drag's start threshold the
    // rest counts, twice over for a centred picture.
    final drag = await tester.startGesture(rect.centerRight - const Offset(7.5, 0));
    for (var i = 0; i < 8; i++) {
      await drag.moveBy(const Offset(-5, 0));
      await tester.pump();
    }
    expect(outline().width, lessThan(104));
    expect(outline().center.dx, closeTo(rect.center.dx, 0.5));
    final during = outline().width;

    await drag.up();
    await tester.pumpAndSettle();
    final width = editorState.getNodeAtPath([1])!.attributes[ImageBlockKeys.width] as double;
    expect(width, lessThan(100));
    expect(during, closeTo(width + 4, 0.01));
    // Still selected, outlined at its new size.
    expect(outline().width, closeTo(width + 4, 0.01));
    expect(
      editorState.selection,
      Selection(start: Position(path: [1]), end: Position(path: [1], offset: 1)),
    );
  });

  testWidgets('without the option, the handles wait for a hover',
      (tester) async {
    await pumpEditor(tester, showSelection: false);
    await tapAt(tester, pictureRect(tester).center);
    expect(handlesPainted(tester), 0);
  });

  testWidgets('with the option, the mobile drag handles leave its edges free',
      (tester) async {
    await pumpEditor(tester);
    expect(
      tester
          .state<ImageBlockComponentWidgetState>(
            find.byType(ImageBlockComponentWidget),
          )
          .showsMobileSelectionHandles,
      isFalse,
    );
  });

  testWidgets('without the option, the mobile drag handles stay',
      (tester) async {
    await pumpEditor(tester, showSelection: false);
    expect(
      tester
          .state<ImageBlockComponentWidgetState>(
            find.byType(ImageBlockComponentWidget),
          )
          .showsMobileSelectionHandles,
      isTrue,
    );
  });

  testWidgets('a wider handle area stays inside the picture', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ResizableImage(
            src: _picture,
            width: 100,
            height: 100,
            alignment: Alignment.center,
            editable: true,
            showHandles: true,
            handleHitWidth: 24,
            onResize: (_) {},
          ),
        ),
      ),
    );
    final areas = tester
        .widgetList<Positioned>(
          find.descendant(
            of: find.byType(ResizableImage),
            matching: find.byType(Positioned),
          ),
        )
        .toList();
    expect(areas.map((p) => p.width), [24, 24]);
    expect(areas.first.left, 0);
    expect(areas.last.right, 0);
    expect(handlesPainted(tester), 2);
  });

  testWidgets('a click beside the picture places a caret on that side',
      (tester) async {
    final editorState = await pumpEditor(tester);
    final rect = pictureRect(tester);

    await tapAt(tester, rect.centerLeft - const Offset(40, 0));
    expect(editorState.selection, Selection.collapsed(Position(path: [1])));
    expect(find.byType(Cursor), findsOneWidget);
    expect(selectionPainted(tester), isFalse);
    // The caret sits just left of the picture.
    expect(tester.getRect(find.byType(Cursor)).right, lessThanOrEqualTo(rect.left));

    await tapAt(tester, rect.centerRight + const Offset(40, 0));
    expect(
      editorState.selection,
      Selection.collapsed(Position(path: [1], offset: 1)),
    );
    expect(tester.getRect(find.byType(Cursor)).left, greaterThanOrEqualTo(rect.right));
  });

  testWidgets('without the option, a click selects the picture as before',
      (tester) async {
    final editorState = await pumpEditor(tester, showSelection: false);
    final rect = pictureRect(tester);

    await tapAt(tester, rect.centerLeft - const Offset(40, 0));
    expect(
      editorState.selection,
      Selection(start: Position(path: [1]), end: Position(path: [1], offset: 1)),
    );
    expect(selectionPainted(tester), isFalse);
  });

  Future<void> type(EditorState editorState, String text) => onInsert(
        TextEditingDeltaInsertion(
          oldText: '',
          textInserted: text,
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        ),
        editorState,
        const [],
      );

  testWidgets('typing beside the picture starts a paragraph on that side',
      (tester) async {
    final editorState = await pumpEditor(tester);

    editorState.selection = Selection.collapsed(Position(path: [1]));
    await type(editorState, 'Caption above');
    await tester.pumpAndSettle();
    expect(editorState.getNodeAtPath([1])!.delta!.toPlainText(), 'Caption above');
    expect(imageIndex(editorState), 2);
    expect(editorState.selection, Selection.collapsed(Position(path: [1], offset: 13)));

    editorState.selection = Selection.collapsed(Position(path: [2], offset: 1));
    await type(editorState, 'x');
    await tester.pumpAndSettle();
    expect(editorState.getNodeAtPath([3])!.delta!.toPlainText(), 'x');
    expect(imageIndex(editorState), 2);
  });

  testWidgets('enter before the picture opens a line above it, after it below',
      (tester) async {
    final editorState = await pumpEditor(tester);

    editorState.selection = Selection.collapsed(Position(path: [1]));
    await editorState.insertNewLine();
    expect(editorState.getNodeAtPath([1])!.delta!.isEmpty, isTrue);
    expect(imageIndex(editorState), 2);
    expect(editorState.selection, Selection.collapsed(Position(path: [2])));

    editorState.selection = Selection.collapsed(Position(path: [2], offset: 1));
    await editorState.insertNewLine();
    expect(editorState.getNodeAtPath([3])!.delta!.isEmpty, isTrue);
    expect(editorState.selection, Selection.collapsed(Position(path: [3])));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('backspace before the picture works on what is above it',
      (tester) async {
    final editorState = await pumpEditor(
      tester,
      before: [paragraphNode(text: 'Above'), paragraphNode()],
    );
    final rect = pictureRect(tester);

    // An empty line above goes away; the picture stays.
    await tapAt(tester, rect.centerLeft - const Offset(40, 0));
    expect(editorState.selection, Selection.collapsed(Position(path: [2])));
    await press(tester, LogicalKeyboardKey.backspace);
    expect(editorState.document.root.children.length, 3);
    expect(imageIndex(editorState), 1);
    expect(editorState.selection, Selection.collapsed(Position(path: [1])));

    // Text above: the caret steps to its end.
    await press(tester, LogicalKeyboardKey.backspace);
    expect(imageIndex(editorState), 1);
    expect(editorState.selection, Selection.collapsed(Position(path: [0], offset: 5)));
  });

  testWidgets('delete after the picture works on what is below it, before it removes it',
      (tester) async {
    final editorState = await pumpEditor(
      tester,
      after: [paragraphNode(), paragraphNode(text: 'Below')],
    );
    final rect = pictureRect(tester);

    await tapAt(tester, rect.centerRight + const Offset(40, 0));
    await press(tester, LogicalKeyboardKey.delete);
    expect(editorState.document.root.children.length, 3);
    expect(editorState.selection, Selection.collapsed(Position(path: [1], offset: 1)));

    await press(tester, LogicalKeyboardKey.delete);
    expect(editorState.selection, Selection.collapsed(Position(path: [2])));

    editorState.selection = Selection.collapsed(Position(path: [1]));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.delete);
    expect(imageIndex(editorState), -1);
    expect(editorState.selection, Selection.collapsed(Position(path: [1])));
  });

  testWidgets('removing the last picture leaves a line for the caret',
      (tester) async {
    final editorState = await pumpEditor(tester, after: []);
    final rect = pictureRect(tester);

    // Backspace after it.
    await tapAt(tester, rect.centerRight + const Offset(40, 0));
    await press(tester, LogicalKeyboardKey.backspace);
    expect(imageIndex(editorState), -1);
    expect(editorState.getNodeAtPath([1])?.delta?.toPlainText(), '');
    expect(editorState.selection, Selection.collapsed(Position(path: [1])));

    // Selected, then removed.
    await editorState.apply(
      editorState.transaction
        ..insertNode([2], imageNode(url: _picture, width: 100, height: 100)),
    );
    await tester.pumpAndSettle();
    await tapAt(tester, pictureRect(tester).center);
    await press(tester, LogicalKeyboardKey.backspace);
    expect(imageIndex(editorState), -1);
    expect(editorState.getNodeAtPath([2])?.delta?.toPlainText(), '');
    expect(editorState.selection, Selection.collapsed(Position(path: [2])));

    // Delete before it.
    await editorState.apply(
      editorState.transaction
        ..insertNode([3], imageNode(url: _picture, width: 100, height: 100)),
    );
    editorState.selection = Selection.collapsed(Position(path: [3]));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.delete);
    expect(imageIndex(editorState), -1);
    expect(
      editorState.document.root.children.map((n) => n.delta?.toPlainText()),
      ['Above', '', '', ''],
    );
    expect(editorState.selection, Selection.collapsed(Position(path: [3])));
  });

  testWidgets('arrows step through both sides of the picture', (tester) async {
    final editorState = await pumpEditor(tester);
    final rect = pictureRect(tester);

    await tapAt(tester, rect.centerRight + const Offset(40, 0));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(editorState.selection, Selection.collapsed(Position(path: [1])));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(editorState.selection, Selection.collapsed(Position(path: [0], offset: 5)));
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(editorState.selection, Selection.collapsed(Position(path: [1])));
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(editorState.selection, Selection.collapsed(Position(path: [1], offset: 1)));
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(editorState.selection, Selection.collapsed(Position(path: [2])));
  });

  group('a selection only touching a picture\'s edge leaves it', () {
    EditorState editor() => EditorState(
          document: Document.blank()
            ..insert([0], [
              paragraphNode(text: 'Above'),
              imageNode(url: _picture, width: 100),
              paragraphNode(text: 'Below'),
            ]),
        );
    List<String> layout(EditorState editorState) => [
          for (final node in editorState.document.root.children)
            node.delta?.toPlainText() ?? node.type,
        ];

    test('ending right before it', () async {
      final editorState = editor();
      await editorState.deleteSelection(
        Selection(start: Position(path: [0], offset: 2), end: Position(path: [1])),
      );
      expect(layout(editorState), ['Ab', ImageBlockKeys.type, 'Below']);
    });

    test('starting right after it', () async {
      final editorState = editor();
      await editorState.deleteSelection(
        Selection(start: Position(path: [1], offset: 1), end: Position(path: [2], offset: 3)),
      );
      expect(layout(editorState), ['Above', ImageBlockKeys.type, 'ow']);
    });

    test('touching only its edges selects nothing', () async {
      final editorState = editor();
      expect(
        await editorState.deleteSelection(
          Selection(start: Position(path: [1], offset: 1), end: Position(path: [2])),
        ),
        isFalse,
      );
      expect(layout(editorState), ['Above', ImageBlockKeys.type, 'Below']);
    });

    test('a range across it still takes it', () async {
      final editorState = editor();
      await editorState.deleteSelection(
        Selection(start: Position(path: [0], offset: 2), end: Position(path: [2], offset: 3)),
      );
      expect(layout(editorState), ['Abow']);
    });
  });
}
