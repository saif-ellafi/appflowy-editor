import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import 'page_navigation.dart';

/// Page up key event.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent pageUpCommand = CommandShortcutEvent(
  key: 'scroll one page up',
  getDescription: () => AppFlowyEditorL10n.current.cmdScrollPageUp,
  command: 'page up',
  handler: (editorState) => handlePageKey(editorState, up: true, extend: false),
);

final CommandShortcutEvent pageUpSelectCommand = CommandShortcutEvent(
  key: 'select one page up',
  getDescription: () => 'select one page up',
  command: 'shift+page up',
  handler: (editorState) => handlePageKey(editorState, up: true, extend: true),
);
