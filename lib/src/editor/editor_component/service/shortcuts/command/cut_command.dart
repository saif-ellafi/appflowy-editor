import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/shortcuts/command/special_insert_plain_text.dart';
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
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) {
    return KeyEventResult.ignored;
  }

  final nodes = editorState.getSelectedNodes(selection: selection);
  final document = Document.blank()..insert([0], nodes);
  _replaceEntityLinksWithNames(document);
  final text = document.root.children
      .map((n) => n.delta?.toPlainText() ?? '')
      .where((s) => s.isNotEmpty)
      .join('\n\n');

  () async {
    await AppFlowyClipboard.setData(
      text: text.isEmpty ? null : text,
    );
  }();

  // Delete the selected content after copying
  editorState.deleteSelection(selection);

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
      if (op is TextInsert && op.text.contains('\uFFFC')) {
        final replacement = specialInsertPlainText(op.attributes);
        if (replacement != null) {
          forEachObjectReplacement(op.text, (segment, {required isObjectReplacement}) {
            if (isObjectReplacement) {
              newOps.add(TextInsert(replacement));
            } else {
              newOps.add(TextInsert(segment, attributes: op.attributes));
            }
          });
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
