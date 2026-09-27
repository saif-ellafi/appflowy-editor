/// Human-readable replacement for U+FFFC special inserts (entity/table/roll/pdf/widget).
String? specialInsertPlainText(Map? attributes) {
  if (attributes == null) return null;

  final entityLink = attributes['entityLink'];
  if (entityLink is Map) {
    final name = entityLink['name'] ?? '';
    final tab = entityLink['tab'];
    if (tab is String && tab.isNotEmpty) {
      return '$name › $tab';
    }
    return '$name';
  }

  final tableLink = attributes['tableLink'];
  if (tableLink is Map) {
    final tableName = tableLink['tableName'] ?? '';
    final result = tableLink['result'] ?? '';
    return '[$tableName: $result]';
  }

  final rollLink = attributes['rollLink'];
  if (rollLink is Map) {
    final formula = rollLink['formula'] ?? '';
    final result = rollLink['result'] ?? '';
    final label = (rollLink['label']?.toString() ?? '').trim();
    if (label.isNotEmpty) return '$label [$formula: $result]';
    return '[$formula: $result]';
  }

  final pdfLink = attributes['pdfLink'];
  if (pdfLink is Map) {
    final pageLabel = pdfLink['pageLabel'];
    final page = pdfLink['page'];
    if (pageLabel is String && pageLabel.isNotEmpty) return pageLabel;
    return 'Page ${page ?? '?'}';
  }

  final richWidget = attributes['richWidget'];
  if (richWidget is Map) {
    return _richWidgetPlainText(richWidget);
  }

  return null;
}

/// Walks [text] so each U+FFFC can be replaced independently of surrounding
/// characters. Consecutive identical chips are often merged into one insert.
void forEachObjectReplacement(
  String text,
  void Function(String segment, {required bool isObjectReplacement}) emit,
) {
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) != 0xFFFC) continue;
    if (i > start) {
      emit(text.substring(start, i), isObjectReplacement: false);
    }
    emit('\uFFFC', isObjectReplacement: true);
    start = i + 1;
  }
  if (start < text.length) {
    emit(text.substring(start), isObjectReplacement: false);
  }
}

String? _richWidgetPlainText(Map data) {
  final type = data['type']?.toString();
  final label = (data['label'] as String?)?.trim() ?? '';
  switch (type) {
    case 'counter':
      final value = data['value'] ?? 0;
      return label.isNotEmpty ? '$label: $value' : '$value';
    case 'checkbox':
      final checked = data['checked'] == true;
      final mark = checked ? '[x]' : '[ ]';
      return label.isNotEmpty ? '$mark $label' : mark;
    case 'progress':
      final text = '${data['progress'] ?? 0}/${data['steps'] ?? 0}';
      return label.isNotEmpty ? '$label: $text' : text;
    case 'clock':
      final text = '${data['progress'] ?? 0}/${data['steps'] ?? 0}';
      return label.isNotEmpty ? '$label: $text' : 'Clock: $text';
    case 'logAction':
      final content = data['content']?.toString() ?? '';
      if (label.isNotEmpty) return '[Log: $label]';
      return content.isNotEmpty ? '[Log: $content]' : '[Log]';
    default:
      return null;
  }
}
