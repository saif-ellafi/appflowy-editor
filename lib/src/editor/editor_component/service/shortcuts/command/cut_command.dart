import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// cut.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent cutCommand = CommandShortcutEvent(
  key: 'cut the selected content',
  getDescription: () => AppFlowyEditorL10n.current.cmdCutSelection,
  command: 'ctrl+shift+x',
  macOSCommand: 'cmd+shift+x',
  handler: _cutCommandHandler,
);

CommandShortcutEventHandler _cutCommandHandler = (editorState) {
  if (editorState.selection == null) {
    return KeyEventResult.ignored;
  }
  // plain text.
  handleCut(editorState);

  return KeyEventResult.handled;
};

final CommandShortcutEvent cutMdCommand = CommandShortcutEvent(
  key: 'cut the selected content as markdown',
  getDescription: () => AppFlowyEditorL10n.current.cmdCutSelection,
  command: 'ctrl+x',
  macOSCommand: 'cmd+x',
  handler: _cutMdCommandHandler,
);

CommandShortcutEventHandler _cutMdCommandHandler = (editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) {
    return KeyEventResult.ignored;
  }

  final nodes = editorState.getSelectedNodes(
    selection: selection,
  );
  final document = Document.blank()..insert([0], nodes);
  
  // Replace entity links with their names before markdown conversion
  _replaceEntityLinksWithNames(document);
  
  final md = documentToMarkdown(document, lineBreak: '\n').trim();

  () async {
    await AppFlowyClipboard.setData(
      text: md.isEmpty ? null : md,
    );
  }();

  // Delete the selected content after copying
  editorState.deleteSelection(selection);

  return KeyEventResult.handled;
};

void _replaceEntityLinksWithNames(Document document) {
  for (final node in document.root.children) {
    _processNode(node);
  }
}

void _processNode(Node node) {
  final delta = node.delta;
  if (delta != null) {
    final newOps = <TextOperation>[];
    for (final op in delta) {
      if (op is TextInsert && op.text == '\uFFFC') {
        // Handle entity links
        final entityLink = op.attributes?['entityLink'];
        if (entityLink is Map) {
          final name = entityLink['name'] ?? '';
          newOps.add(TextInsert(name));
          continue;
        }
        
        // Handle table links
        final tableLink = op.attributes?['tableLink'];
        if (tableLink is Map) {
          final tableName = tableLink['tableName'] ?? '';
          final result = tableLink['result'] ?? '';
          newOps.add(TextInsert('[$tableName: $result]'));
          continue;
        }
        
        // Handle dice roll links
        final rollLink = op.attributes?['rollLink'];
        if (rollLink is Map) {
          final formula = rollLink['formula'] ?? '';
          final result = rollLink['result'] ?? '';
          newOps.add(TextInsert('[$formula: $result]'));
          continue;
        }
      }
      newOps.add(op);
    }
    
    node.updateAttributes({
      'delta': Delta(operations: newOps).toJson(),
    });
  }
  
  // Recurse children
  for (final child in node.children) {
    _processNode(child);
  }
}
