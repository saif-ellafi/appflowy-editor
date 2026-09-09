import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_interaction.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'table_view.dart';

class TableBlockKeys {
  const TableBlockKeys._();

  static const String type = 'table';

  static const String colDefaultWidth = 'colDefaultWidth';

  static const String rowDefaultHeight = 'rowDefaultHeight';

  static const String colMinimumWidth = 'colMinimumWidth';

  static const String borderWidth = 'borderWidth';

  static const String colsLen = 'colsLen';

  static const String rowsLen = 'rowsLen';

  static const String colsHeight = 'colsHeight';
}

class TableStyle {
  const TableStyle({
    this.colWidth = 160,
    this.rowHeight = 40,
    this.colMinimumWidth = 40,
    this.borderWidth = 2,
    this.addIcon = TableDefaults.addIcon,
    this.handlerIcon = TableDefaults.handlerIcon,
    this.borderColor = TableDefaults.borderColor,
    this.borderHoverColor = TableDefaults.borderHoverColor,
    this.handlerColor = TableDefaults.handlerColor,
    this.handleBackgroundColor = TableDefaults.handleBackgroundColor,
    this.menuBackgroundColor,
    this.menuBorderColor,
    this.menuForegroundColor,
    this.menuBorderRadius,
    this.touchLayout = false,
  });
  final double colWidth;
  final double rowHeight;
  final double colMinimumWidth;
  final double borderWidth;
  final Widget addIcon;
  final Widget handlerIcon;
  final Color borderColor;
  final Color borderHoverColor;
  final Color handlerColor;
  final Color handleBackgroundColor;
  final Color? menuBackgroundColor;
  final Color? menuBorderColor;
  final Color? menuForegroundColor;
  final BorderRadius? menuBorderRadius;
  final bool touchLayout;
}

class TableDefaults {
  const TableDefaults._();

  static double colWidth = 160.0;

  static double rowHeight = 40.0;

  static double colMinimumWidth = 40.0;

  static double borderWidth = 2.0;

  static const Widget addIcon = Icon(Icons.add, size: 16);

  static const Widget handlerIcon = Icon(Icons.drag_handle, size: 12);

  static const Color borderColor = Colors.grey;

  static const Color borderHoverColor = Colors.blue;

  static const Color handlerColor = Color(0xFF5F6368);

  static const Color handleBackgroundColor = Colors.white;
}

class TableStyleScope extends InheritedWidget {
  const TableStyleScope({
    super.key,
    required this.style,
    required super.child,
  });

  final TableStyle style;

  static TableStyle? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TableStyleScope>()?.style;
  }

  static TableStyle of(BuildContext context) {
    return maybeOf(context) ?? const TableStyle();
  }

  @override
  bool updateShouldNotify(TableStyleScope oldWidget) => style != oldWidget.style;
}

const double tableHandleSize = 20;
/// Visible stadium size (kept subtle on desktop).
const double tableHandleOvalLength = 22;
const double tableHandleOvalThickness = 11;
/// Finger-sized stadium on touch; still smaller than the 44px hit box.
const double tableMobileHandleOvalLength = 32;
const double tableMobileHandleOvalThickness = 16;
/// Touch hit box around the visible oval (Material / HIG ~44).
const double tableMobileHandleHitThickness = 44;
const double tableMobileHandleHitLength = 44;
/// Inset so text does not sit on the cell borders or handle ovals.
const double tableCellPaddingH = 12;
const double tableCellPaddingV = 8;
const double tableBorderChrome = 8;
/// Extra top chrome on touch so the larger horizontal oval is not clipped.
const double tableMobileTopChrome = 20;
/// Vertical cell inset accounted for when measuring row height (top + bottom).
const double tableCellHeightPadding = tableCellPaddingV * 2;

bool tableUsesTouchChrome(BuildContext context) {
  return TableStyleScope.maybeOf(context)?.touchLayout == true ||
      tableIsTouchLayout(context);
}

double tableTopChrome(BuildContext context) {
  return tableUsesTouchChrome(context)
      ? tableMobileTopChrome
      : tableBorderChrome;
}

double tableHandleHitThickness(BuildContext context) {
  return tableUsesTouchChrome(context)
      ? tableMobileHandleHitThickness
      : tableHandleOvalThickness;
}

double tableHandleHitLength(BuildContext context) {
  return tableUsesTouchChrome(context)
      ? tableMobileHandleHitLength
      : tableHandleOvalLength;
}

enum TableDirection { row, col }

typedef TableBlockComponentMenuBuilder = Widget Function(
  Node,
  EditorState,
  int,
  TableDirection,
  VoidCallback?,
  VoidCallback?,
);

class TableBlockComponentBuilder extends BlockComponentBuilder {
  TableBlockComponentBuilder({
    super.configuration,
    this.tableStyle = const TableStyle(),
    this.menuBuilder,
  });

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableStyle tableStyle;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    TableDefaults.colWidth = tableStyle.colWidth;
    TableDefaults.rowHeight = tableStyle.rowHeight;
    TableDefaults.colMinimumWidth = tableStyle.colMinimumWidth;
    TableDefaults.borderWidth = tableStyle.borderWidth;

    return TableBlockComponentWidget(
      key: node.key,
      tableNode: TableNode(node: node),
      node: node,
      configuration: configuration,
      menuBuilder: menuBuilder,
      tableStyle: tableStyle,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  @override
  BlockComponentValidate get validate => (node) {
        // check the node is valid
        if (node.attributes.isEmpty) {
          AppFlowyEditorLog.editor
              .debug('TableBlockComponentBuilder: node is empty');

          return false;
        }

        // check the node has rowPosition and colPosition
        if (!node.attributes.containsKey(TableBlockKeys.colsLen) ||
            !node.attributes.containsKey(TableBlockKeys.rowsLen)) {
          AppFlowyEditorLog.editor.debug(
            'TableBlockComponentBuilder: node has no colsLen or rowsLen',
          );

          return false;
        }

        final colsLen = node.attributes[TableBlockKeys.colsLen];
        final rowsLen = node.attributes[TableBlockKeys.rowsLen];

        // check its children
        final children = node.children;
        if (children.isEmpty) {
          AppFlowyEditorLog.editor
              .debug('TableBlockComponentBuilder: children is empty');

          return false;
        }

        if (children.length != colsLen * rowsLen) {
          AppFlowyEditorLog.editor.debug(
            'TableBlockComponentBuilder: children length(${children.length}) is not equal to colsLen * rowsLen($colsLen * $rowsLen)',
          );

          return false;
        }

        // all children should contain rowPosition and colPosition
        for (var i = 0; i < colsLen; i++) {
          for (var j = 0; j < rowsLen; j++) {
            final child = children.where(
              (n) =>
                  n.attributes[TableCellBlockKeys.colPosition] == i &&
                  n.attributes[TableCellBlockKeys.rowPosition] == j,
            );
            if (child.isEmpty) {
              AppFlowyEditorLog.editor.debug(
                'TableBlockComponentBuilder: child($i, $j) is empty',
              );

              return false;
            }

            // should only contains one child
            if (child.length != 1) {
              AppFlowyEditorLog.editor.debug(
                'TableBlockComponentBuilder: child($i, $j) is not unique',
              );

              return false;
            }
          }
        }

        return true;
      };
}

class TableBlockComponentWidget extends BlockComponentStatefulWidget {
  const TableBlockComponentWidget({
    super.key,
    required this.tableNode,
    required super.node,
    this.tableStyle = const TableStyle(),
    this.menuBuilder,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  final TableNode tableNode;

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableStyle tableStyle;

  @override
  State<TableBlockComponentWidget> createState() =>
      _TableBlockComponentWidgetState();
}

class _TableBlockComponentWidgetState extends State<TableBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  static const _scrollbarThickness = 4.0;
  static const _desktopScrollbarGutter = 6.0;

  late final editorState = Provider.of<EditorState>(context, listen: false);
  final _scrollController = ScrollController();
  final _interactionController = TableInteractionController();
  bool _selectionListening = false;
  MouseCursor _scrollbarHoverCursor = MouseCursor.defer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_selectionListening) {
      editorState.selectionNotifier.addListener(_syncTableActive);
      _selectionListening = true;
      _syncTableActive();
    }
  }

  @override
  void dispose() {
    if (_selectionListening) {
      editorState.selectionNotifier.removeListener(_syncTableActive);
    }
    _interactionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncTableActive() {
    final selection = editorState.selection;
    if (selection == null) {
      _interactionController.setCaret(inTable: false);
      return;
    }
    final selected = editorState.getNodeAtPath(selection.start.path);
    final inThisTable =
        selected?.findParent((n) => n.id == node.id) != null;
    if (!inThisTable) {
      _interactionController.setCaret(inTable: false);
      return;
    }
    final cell =
        selected?.findParent((n) => n.type == TableCellBlockKeys.type);
    _interactionController.setCaret(
      inTable: true,
      col: cell?.attributes[TableCellBlockKeys.colPosition] as int?,
      row: cell?.attributes[TableCellBlockKeys.rowPosition] as int?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollbarGutter =
        tableUsesTouchChrome(context) ? 0.0 : _desktopScrollbarGutter;
    Widget child = TableStyleScope(
      style: widget.tableStyle,
      child: TableInteractionScope(
        controller: _interactionController,
        child: Theme(
          data: Theme.of(context).copyWith(
            scrollbarTheme: ScrollbarTheme.of(context).copyWith(
              thickness: const WidgetStatePropertyAll(_scrollbarThickness),
              trackVisibility: const WidgetStatePropertyAll(false),
              trackColor: const WidgetStatePropertyAll(Colors.transparent),
              trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
          child: MouseRegion(
            cursor: _scrollbarHoverCursor,
            onHover: (event) {
              final next = event.localPosition.dy <=
                      tableTopChrome(context) + scrollbarGutter
                  ? SystemMouseCursors.click
                  : MouseCursor.defer;
              if (next != _scrollbarHoverCursor) {
                setState(() => _scrollbarHoverCursor = next);
              }
            },
            onExit: (_) {
              if (_scrollbarHoverCursor != MouseCursor.defer) {
                setState(() => _scrollbarHoverCursor = MouseCursor.defer);
              }
            },
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: false,
              interactive: false,
              thickness: _scrollbarThickness,
              scrollbarOrientation: ScrollbarOrientation.top,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: scrollbarGutter,
                  bottom: 4,
                ),
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: TableView(
                  tableNode: widget.tableNode,
                  editorState: editorState,
                  menuBuilder: widget.menuBuilder,
                  tableStyle: widget.tableStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    child = Padding(
      key: tableKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
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

    child = Padding(
      padding: margin,
      child: child,
    );

    return child;
  }

  final tableKey = GlobalKey();

  RenderBox get _renderBox => context.findRenderObject() as RenderBox;

  @override
  Position start() => Position(path: widget.node.path);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = context.findRenderObject();
    final tableBox = tableKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && tableBox is RenderBox) {
      return [
        (shiftWithBaseOffset
                ? tableBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            tableBox.size,
      ];
    }

    return [Offset.zero & _renderBox.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  }) =>
      _renderBox.localToGlobal(offset);

  @override
  Rect getBlockRect({
    bool shiftWithBaseOffset = false,
  }) {
    return getRectsInSelection(Selection.invalid()).first;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final size = _renderBox.size;

    return Rect.fromLTWH(-size.width / 2.0, 0, size.width, size.height);
  }
}

SelectionMenuItem tableMenuItem = SelectionMenuItem(
  getName: () => AppFlowyEditorL10n.current.table,
  icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
    icon: Icons.table_view,
    isSelected: isSelected,
    style: style,
  ),
  keywords: ['table'],
  handler: (editorState, _, __) async {
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }

    final currentNode = editorState.getNodeAtPath(selection.end.path);
    if (currentNode == null) {
      return;
    }

    final tableNode = TableNode.fromList([
      ['', ''],
      ['', ''],
    ]);

    final transaction = editorState.transaction;
    final delta = currentNode.delta;
    if (delta != null && delta.isEmpty) {
      transaction
        ..insertNode(selection.end.path, tableNode.node)
        ..deleteNode(currentNode);
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: selection.end.path + [0, 0],
        ),
      );
    } else {
      transaction.insertNode(selection.end.path.next, tableNode.node);
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: selection.end.path.next + [0, 0],
        ),
      );
    }

    await editorState.apply(transaction);
  },
);
