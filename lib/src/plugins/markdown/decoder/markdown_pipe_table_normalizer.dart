/// Turns the pipe tables people actually paste into GitHub-flavored markdown.
///
/// GFM tables cannot have blank lines between rows, and they need a delimiter
/// row (`| --- | --- |`). Discord, forums, and chat clients often insert both
/// kinds of damage. This rewrite is idempotent and leaves fenced code alone.
class MarkdownPipeTableNormalizer {
  MarkdownPipeTableNormalizer._();

  static final _separatorCell = RegExp(r'^:?-{1,}:?$');
  static final _fenceLine = RegExp(r'^ {0,3}(`{3,}|~{3,})');
  static final _htmlTableTag = RegExp(r'<table\b', caseSensitive: false);

  /// True when [markdown] contains at least one pipe table (messy or clean).
  static bool containsPipeTable(String markdown) {
    return _tableRuns(markdown).isNotEmpty;
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
    String? fenceChar;

    while (i < lines.length) {
      final line = lines[i];
      final fenceMatch = _fenceLine.firstMatch(line);
      if (fenceChar == null && fenceMatch != null) {
        fenceChar = fenceMatch.group(1)![0];
        out.add(line);
        i++;
        continue;
      }
      if (fenceChar != null) {
        out.add(line);
        if (fenceMatch != null && fenceMatch.group(1)![0] == fenceChar) {
          fenceChar = null;
        }
        i++;
        continue;
      }

      if (!_isTableRow(line)) {
        out.add(line);
        i++;
        continue;
      }

      final runStart = i;
      final rows = <String>[];
      var j = i;
      while (j < lines.length) {
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
          if (k < lines.length && _isTableRow(lines[k])) {
            j = k;
            continue;
          }
        }
        break;
      }

      if (_isConvertibleRun(rows)) {
        out.addAll(_rewrite(rows));
      } else {
        out.addAll(lines.sublist(runStart, j));
      }
      i = j;
    }

    return out.join('\n');
  }

  static List<List<String>> _tableRuns(String markdown) {
    final lines =
        markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final runs = <List<String>>[];
    var i = 0;
    String? fenceChar;

    while (i < lines.length) {
      final line = lines[i];
      final fenceMatch = _fenceLine.firstMatch(line);
      if (fenceChar == null && fenceMatch != null) {
        fenceChar = fenceMatch.group(1)![0];
        i++;
        continue;
      }
      if (fenceChar != null) {
        if (fenceMatch != null && fenceMatch.group(1)![0] == fenceChar) {
          fenceChar = null;
        }
        i++;
        continue;
      }

      if (!_isTableRow(line)) {
        i++;
        continue;
      }

      final rows = <String>[];
      var j = i;
      while (j < lines.length) {
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
          if (k < lines.length && _isTableRow(lines[k])) {
            j = k;
            continue;
          }
        }
        break;
      }
      if (_isConvertibleRun(rows)) {
        runs.add(rows);
      }
      i = j;
    }

    return runs;
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
