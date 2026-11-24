import 'package:appflowy_editor/appflowy_editor.dart';

class NumberedListNodeParser extends NodeParser {
  const NumberedListNodeParser();

  @override
  String get id => NumberedListBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final delta = node.delta ?? Delta()
      ..insert('');
    final number = node.attributes[NumberedListBlockKeys.number] ?? '1';
    final children = encoder?.convertNodes(node.children, withIndent: true);
    final deltaMarkdown = DeltaMarkdownEncoder(
      inlineWrappers: encoder?.inlineWrappers ?? const [],
    ).convert(delta);
    String markdown = '$number. $deltaMarkdown\n';
    if (children != null && children.isNotEmpty) {
      markdown += children;
    }

    return markdown;
  }
}
