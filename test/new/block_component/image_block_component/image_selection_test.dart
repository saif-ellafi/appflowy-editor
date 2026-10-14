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
}
