import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/block_component/table_block_component/util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableCellBlockKeys {
  const TableCellBlockKeys._();

  static const String type = 'table/cell';

  static const String rowPosition = 'rowPosition';

  static const String colPosition = 'colPosition';

  static const String height = 'height';

  static const String width = 'width';

  static const String rowBackgroundColor = 'rowBackgroundColor';

  static const String colBackgroundColor = 'colBackgroundColor';
}

typedef TableBlockCellComponentColorBuilder = Color? Function(
  BuildContext context,
  Node node,
);

Node tableCellNode(String text, int rowPosition, int colPosition) {
  return Node(
    type: TableCellBlockKeys.type,
    attributes: {
      TableCellBlockKeys.rowPosition: rowPosition,
      TableCellBlockKeys.colPosition: colPosition,
    },
    children: [
      paragraphNode(text: text),
    ],
  );
}

class TableCellBlockComponentBuilder extends BlockComponentBuilder {
  TableCellBlockComponentBuilder({
    super.configuration,
    this.menuBuilder,
    this.colorBuilder,
  });

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableBlockCellComponentColorBuilder? colorBuilder;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;

    return TableCelBlockWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      menuBuilder: menuBuilder,
      colorBuilder: colorBuilder,
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
  BlockComponentValidate get validate => (node) =>
      node.attributes.isNotEmpty &&
      node.attributes.containsKey(TableCellBlockKeys.rowPosition) &&
      node.attributes.containsKey(TableCellBlockKeys.colPosition);
}

class TableCelBlockWidget extends BlockComponentStatefulWidget {
  const TableCelBlockWidget({
    super.key,
    required super.node,
    this.menuBuilder,
    this.colorBuilder,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  final TableBlockComponentMenuBuilder? menuBuilder;
  final TableBlockCellComponentColorBuilder? colorBuilder;

  @override
  State<TableCelBlockWidget> createState() => _TableCeBlockWidgetState();
}

class _TableCeBlockWidgetState extends State<TableCelBlockWidget> {
  late final editorState = Provider.of<EditorState>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final col =
        widget.node.attributes[TableCellBlockKeys.colPosition] as int? ?? 0;
    final row =
        widget.node.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
    final leftPadding = col == 0
        ? tableCellPaddingH + tableCellFirstColExtraPadding
        : tableCellPaddingH;
    // Mirror first-column oval clearance on the first row / top oval.
    final topPadding = row == 0
        ? tableCellPaddingV + tableCellFirstColExtraPadding
        : tableCellPaddingV;
    return Container(
      constraints: BoxConstraints(
        minHeight: context.select((Node n) => n.cellHeight),
      ),
      color: context.select(
        (Node n) =>
            widget.colorBuilder?.call(context, n) ??
            (n.attributes[TableCellBlockKeys.colBackgroundColor] as String?)
                ?.tryToColor() ??
            (n.attributes[TableCellBlockKeys.rowBackgroundColor] as String?)
                ?.tryToColor(),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          leftPadding,
          topPadding,
          tableCellPaddingH,
          tableCellPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in widget.node.children)
              editorState.renderer.build(context, child),
          ],
        ),
      ),
    );
  }
}
