import 'package:appflowy_editor/appflowy_editor.dart';

import 'page_navigation.dart';

/// Page down key event.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent pageDownCommand = CommandShortcutEvent(
  key: 'scroll one page down',
  getDescription: () => AppFlowyEditorL10n.current.cmdScrollPageDown,
  command: 'page down',
  handler: (editorState) => handlePageKey(editorState, up: false, extend: false),
);

final CommandShortcutEvent pageDownSelectCommand = CommandShortcutEvent(
  key: 'select one page down',
  getDescription: () => 'select one page down',
  command: 'shift+page down',
  handler: (editorState) => handlePageKey(editorState, up: false, extend: true),
);
