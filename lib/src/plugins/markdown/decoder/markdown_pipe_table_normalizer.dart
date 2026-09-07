/// Turns the pipe tables people actually paste into GitHub-flavored markdown.
///
/// GFM tables cannot have blank lines between rows, and they need a delimiter
/// row (`| --- | --- |`). Discord, forums, and chat clients often insert both
/// kinds of damage. This rewrite is idempotent and leaves fenced code alone.
class MarkdownPipeTableNormalizer {
  MarkdownPipeTableNormalizer._();

  static final _separatorCell = RegExp(r'^:?-{1,}:?$');
  static final _openFence = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
  static final _closeFence = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*$');
  static final _htmlTableTag = RegExp(r'<table\b', caseSensitive: false);

  /// True when [markdown] contains at least one pipe table (messy or clean).
  static bool containsPipeTable(String markdown) {
    return _tableRuns(markdown).isNotEmpty;
  }

  /// True when every non-blank line belongs to a pipe table.
  ///
  /// Used to decide whether clipboard HTML can be skipped: mixed documents
  /// keep their HTML so surrounding links and formatting are not discarded.
  static bool isPipeTableOnly(String markdown) {
    final lines =
        markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    var sawTable = false;
    var i = 0;
    while (i < lines.length) {
      final fence = _openingFence(lines[i]);
      if (fence != null) {
        return false;
      }
      if (lines[i].trim().isEmpty) {
        i++;
        continue;
      }
      if (!_isTableRow(lines[i])) {
        return false;
      }
      final collected = _collectRun(lines, i);
      if (!_isConvertibleRun(collected.rows)) {
        return false;
      }
      sawTable = true;
      i = collected.end;
    }
    return sawTable;
  }

  /// True when clipboard HTML is a real `<table>`, not pipe-markdown wrapped
  /// in `<p>` / `<div>` / `<pre>`.
  static bool htmlContainsRealTable(String? html) {
    if (html == null || html.isEmpty) {
      return false;
    }
    return _htmlTableTag.hasMatch(html);
  }

  static String normalize(String markdown) {
    final lines =
        markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final out = <String>[];
    var i = 0;

    while (i < lines.length) {
      final fence = _openingFence(lines[i]);
      if (fence != null) {
        out.add(lines[i]);
        i++;
        while (i < lines.length && !_isClosingFence(lines[i], fence)) {
          out.add(lines[i]);
          i++;
        }
        if (i < lines.length) {
          out.add(lines[i]);
          i++;
        }
        continue;
      }

      if (!_isTableRow(lines[i])) {
        out.add(lines[i]);
        i++;
        continue;
      }

      final collected = _collectRun(lines, i);
      final tables = _splitTables(collected.rows);
      if (tables.isEmpty) {
        out.addAll(lines.sublist(collected.start, collected.end));
      } else {
        for (var t = 0; t < tables.length; t++) {
          if (t > 0) {
            out.add('');
          }
          out.addAll(_rewrite(tables[t]));
        }
      }
      i = collected.end;
    }

    return out.join('\n');
  }

  static List<List<String>> _tableRuns(String markdown) {
    final lines =
        markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final runs = <List<String>>[];
    var i = 0;

    while (i < lines.length) {
      final fence = _openingFence(lines[i]);
      if (fence != null) {
        i++;
        while (i < lines.length && !_isClosingFence(lines[i], fence)) {
          i++;
        }
        if (i < lines.length) {
          i++;
        }
        continue;
      }

      if (!_isTableRow(lines[i])) {
        i++;
        continue;
      }

      final collected = _collectRun(lines, i);
      runs.addAll(_splitTables(collected.rows));
      i = collected.end;
    }

    return runs;
  }

  static _CollectedRun _collectRun(List<String> lines, int start) {
    final rows = <String>[];
    var j = start;
    while (j < lines.length) {
      if (_openingFence(lines[j]) != null) {
        break;
      }
      final current = lines[j];
      if (_isTableRow(current)) {
        rows.add(current);
        j++;
        continue;
      }
      if (current.trim().isEmpty) {
        var k = j + 1;
        while (k < lines.length && lines[k].trim().isEmpty) {
          k++;
        }
        if (k < lines.length &&
            _openingFence(lines[k]) == null &&
            _isTableRow(lines[k])) {
          j = k;
          continue;
        }
      }
      break;
    }
    return _CollectedRun(start, j, rows);
  }

  static _Fence? _openingFence(String line) {
    final match = _openFence.firstMatch(line);
    if (match == null) {
      return null;
    }
    final marker = match.group(1)!;
    return _Fence(marker[0], marker.length);
  }

  static bool _isClosingFence(String line, _Fence open) {
    final match = _closeFence.firstMatch(line);
    if (match == null) {
      return false;
    }
    final marker = match.group(1)!;
    return marker[0] == open.marker && marker.length >= open.length;
  }

  static bool _isTableRow(String line) {
    if (line.startsWith('    ') || line.startsWith('\t')) {
      return false;
    }
    final trimmed = line.trim();
    if (trimmed.length < 3 || !trimmed.startsWith('|')) {
      return false;
    }
    return trimmed.contains('|', 1);
  }

  static bool _isSeparatorRow(String line) {
    final cells = _splitCells(line);
    if (cells.length < 2) {
      return false;
    }
    return cells.every((cell) => _separatorCell.hasMatch(cell.trim()));
  }

  static List<String> _splitCells(String line) {
    var body = line.trim();
    if (body.startsWith('|')) {
      body = body.substring(1);
    }
    if (body.endsWith('|')) {
      body = body.substring(0, body.length - 1);
    }
    return body.split('|');
  }

  static int _columnCount(String line) => _splitCells(line).length;

  static bool _isConvertibleRun(List<String> rows) {
    if (rows.length < 2) {
      return false;
    }
    if (_isSeparatorRow(rows.first)) {
      return false;
    }
    var maxCols = 0;
    var dataRows = 0;
    for (final row in rows) {
      final cols = _columnCount(row);
      if (cols > maxCols) {
        maxCols = cols;
      }
      if (!_isSeparatorRow(row)) {
        dataRows++;
      }
    }
    return maxCols >= 2 && dataRows >= 2;
  }

  /// One delimiter starts a table; a later delimiter starts the next table,
  /// using the preceding data row as that table's header.
  static List<List<String>> _splitTables(List<String> rows) {
    if (rows.isEmpty) {
      return const [];
    }
    final tables = <List<String>>[];
    var current = <String>[];
    var seenDelimiter = false;
    for (final row in rows) {
      if (_isSeparatorRow(row)) {
        if (!seenDelimiter) {
          current.add(row);
          seenDelimiter = true;
          continue;
        }
        if (current.isNotEmpty && !_isSeparatorRow(current.last)) {
          final header = current.removeLast();
          if (_isConvertibleRun(current)) {
            tables.add(current);
          }
          current = [header, row];
          seenDelimiter = true;
        }
        continue;
      }
      current.add(row);
    }
    if (_isConvertibleRun(current)) {
      tables.add(current);
    }
    return tables;
  }

  static List<String> _rewrite(List<String> rows) {
    final separatorIndex = rows.indexWhere(_isSeparatorRow);
    var cols = 0;
    if (separatorIndex >= 0) {
      cols = _columnCount(rows[separatorIndex]);
    }
    for (final row in rows) {
      if (_isSeparatorRow(row)) {
        continue;
      }
      final count = _columnCount(row);
      if (count > cols) {
        cols = count;
      }
    }

    final dataRows = <String>[
      for (final row in rows)
        if (!_isSeparatorRow(row)) _padRow(row, cols),
    ];
    final separator = separatorIndex >= 0
        ? _padSeparator(rows[separatorIndex], cols)
        : _makeSeparator(cols);

    return [
      dataRows.first,
      separator,
      ...dataRows.skip(1),
    ];
  }

  static String _padRow(String line, int cols) {
    final cells = _splitCells(line);
    while (cells.length < cols) {
      cells.add(' ');
    }
    if (cells.length > cols) {
      cells.removeRange(cols, cells.length);
    }
    return '|${cells.join('|')}|';
  }

  static String _padSeparator(String line, int cols) {
    final cells = _splitCells(line);
    while (cells.length < cols) {
      cells.add('---');
    }
    if (cells.length > cols) {
      cells.removeRange(cols, cells.length);
    }
    return '|${cells.map((c) => c.trim().isEmpty ? '---' : c).join('|')}|';
  }

  static String _makeSeparator(int cols) {
    return '|${List.filled(cols, '---').join('|')}|';
  }
}

class _Fence {
  const _Fence(this.marker, this.length);
  final String marker;
  final int length;
}

class _CollectedRun {
  const _CollectedRun(this.start, this.end, this.rows);
  final int start;
  final int end;
  final List<String> rows;
}
