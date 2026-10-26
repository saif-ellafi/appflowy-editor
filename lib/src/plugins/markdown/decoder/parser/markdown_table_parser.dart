import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownTableListParserV2 extends CustomMarkdownParser {
  const MarkdownTableListParserV2();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element) {
      return [];
    }

    if (element.tag != 'table') {
      return [];
    }

    final ec = element.children;
    if (ec == null || ec.isEmpty) {
      return [];
    }

    final th = ec
        .whereType<md.Element>()
        .where((e) => e.tag == 'thead')
        .firstOrNull
        ?.children
        ?.whereType<md.Element>()
        .where((e) => e.tag == 'tr')
        .expand((e) => e.children?.whereType<md.Element>().toList() ?? [])
        .where((e) => e.tag == 'th')
        .toList();

    final td = ec
        .whereType<md.Element>()
        .where((e) => e.tag == 'tbody')
        .firstOrNull
        ?.children
        ?.whereType<md.Element>()
        .where((e) => e.tag == 'tr')
        .expand((e) => e.children?.whereType<md.Element>().toList() ?? [])
        .where((e) => e.tag == 'td')
        .toList();

    // A one-row table has a header and no body.
    if (th == null || th.isEmpty) {
      return [];
    }
    final body = td ?? <md.Element>[];

    final blocks = <List<List<Node>>>[];
    for (var i = 0; i < th.length; i++) {
      final column = <List<Node>>[_blocksInCell(th[i])];
      for (var j = i; j < body.length; j += th.length) {
        column.add(_blocksInCell(body[j]));
      }
      blocks.add(column);
    }

    final tableNode = TableNode.fromList([
      for (final column in blocks)
        [
          for (final cell in column) cell.isEmpty ? paragraphNode() : cell.first,
        ],
    ]);
    for (var col = 0; col < blocks.length; col++) {
      for (var row = 0; row < blocks[col].length; row++) {
        final extra = blocks[col][row].skip(1);
        final cell = tableNode.getCell(col, row);
        for (final node in extra) {
          cell.insert(node);
        }
      }
    }

    return [
      tableNode.node,
    ];
  }
}

/// A cell is inline markdown joined by `<br>`. A heading in a cell comes back
/// as `# title`; that is a heading again, not the characters `#`. Other
/// lines next to each other are one paragraph with line breaks, as typed.
List<Node> _blocksInCell(md.Element cell) {
  final blocks = <Node>[];
  Delta? text;
  void flush() {
    var delta = text;
    if (delta == null) {
      return;
    }
    while (delta!.toPlainText().endsWith('\n')) {
      delta = delta.slice(0, delta.length - 1);
    }
    blocks.add(paragraphNode(delta: delta));
    text = null;
  }

  for (final line in _linesOf(cell.children)) {
    final delta = line.isEmpty ? Delta() : DeltaMarkdownDecoder().convertNodes(line);
    if (delta.isEmpty && text == null) {
      continue;
    }
    final heading = _headingFromLine(delta);
    if (heading != null) {
      flush();
      blocks.add(heading);
      continue;
    }
    text = text == null ? delta : (text! + (Delta()..insert('\n')) + delta);
  }
  flush();

  return blocks.isEmpty ? [paragraphNode()] : blocks;
}

Node? _headingFromLine(Delta delta) {
  final match = RegExp(r'^(#{1,6}) (.+)$').firstMatch(delta.toPlainText());
  if (match == null) {
    return null;
  }
  final level = match.group(1)!.length;
  final prefix = level + 1;
  if (prefix > delta.length) {
    return null;
  }

  return headingNode(level: level, delta: delta.slice(prefix));
}

final _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);

/// Lines between `<br>`s. Markdown keeps a `<br>` as raw text, not as a
/// `br` element.
List<List<md.Node>> _linesOf(List<md.Node>? nodes) {
  final lines = <List<md.Node>>[[]];
  void add(md.Node node) {
    if (node is md.Element && node.tag == 'br') {
      lines.add([]);

      return;
    }
    if (node is md.Text && _lineBreak.hasMatch(node.text)) {
      final parts = node.text.split(_lineBreak);
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) {
          lines.add([]);
        }
        if (parts[i].isNotEmpty) {
          lines.last.add(md.Text(parts[i]));
        }
      }

      return;
    }
    if (node is md.Element && node.tag == 'p') {
      for (final child in node.children ?? const <md.Node>[]) {
        add(child);
      }

      return;
    }
    lines.last.add(node);
  }

  for (final node in nodes ?? const <md.Node>[]) {
    add(node);
  }

  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }

  return lines;
}
