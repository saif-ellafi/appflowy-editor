import 'package:appflowy_editor/appflowy_editor.dart';

class TodoListNodeParser extends NodeParser {
  const TodoListNodeParser();

  @override
  String get id => TodoListBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final delta = node.delta ?? Delta()
      ..insert('');
    final checked =
        node.attributes[TodoListBlockKeys.checked] == true ? '- [x]' : '- [ ]';
    final children = encoder?.convertNodes(node.children, withIndent: true);
    final deltaMarkdown = DeltaMarkdownEncoder(
      inlineWrappers: encoder?.inlineWrappers ?? const [],
    ).convert(delta);
    String markdown = '$checked $deltaMarkdown\n';
    if (children != null && children.isNotEmpty) {
      markdown += children;
    }

    return markdown;
  }
}
