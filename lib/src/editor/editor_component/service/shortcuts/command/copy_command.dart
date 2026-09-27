import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/shortcuts/command/special_insert_plain_text.dart';
import 'package:flutter/material.dart';

/// Copy.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent copyCommand = CommandShortcutEvent(
  key: 'copy the selected content',
  getDescription: () => AppFlowyEditorL10n.current.cmdCopySelection,
  command: 'ctrl+shift+c',
  macOSCommand: 'cmd+shift+c',
  handler: _copyCommandHandler,
);

CommandShortcutEventHandler _copyCommandHandler = (editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) {
    return KeyEventResult.ignored;
  }

  final nodes = editorState.getSelectedNodes(selection: selection);
  final document = Document.blank()..insert([0], nodes);
  // Plain copy: human-readable labels (not PUM tokens).
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

  return KeyEventResult.handled;
};

final CommandShortcutEvent copyMdCommand = CommandShortcutEvent(
  key: 'copy the selected content',
  getDescription: () => AppFlowyEditorL10n.current.cmdCopySelection,
  command: 'ctrl+c',
  macOSCommand: 'cmd+c',
  handler: _copyMdCommandHandler,
);

CommandShortcutEventHandler _copyMdCommandHandler = (editorState) {
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
