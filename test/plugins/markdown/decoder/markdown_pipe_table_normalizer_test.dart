import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarkdownPipeTableNormalizer', () {
    test('collapses blank lines between table rows', () {
      const messy = '''
| **Skills**              | **Attribute** | **Die Type** | **Modifier** |

|-------------------------|---------------|--------------|--------------|

| Athletics                              | Agility       | d4           | +0           |

| Fighting                             | Agility       | d8           | +0           |
''';
      final normalized = MarkdownPipeTableNormalizer.normalize(messy);
      expect(normalized.contains('\n\n|'), isFalse);
      expect(MarkdownPipeTableNormalizer.containsPipeTable(messy), isTrue);
    });

    test('inserts a delimiter row when the paste omitted one', () {
      const missing = '''
| Skills | Attribute |
| Athletics | Agility |
| Fighting | Agility |
''';
      final normalized = MarkdownPipeTableNormalizer.normalize(missing);
      final lines = normalized.trim().split('\n');
      expect(lines.length, 4);
      expect(lines[1], '|---|---|');
    });

    test('leaves fenced code tables alone', () {
      const fenced = '''
```
| a | b |

| c | d |
```
''';
      expect(
        MarkdownPipeTableNormalizer.normalize(fenced).trim(),
        fenced.trim(),
      );
      expect(MarkdownPipeTableNormalizer.containsPipeTable(fenced), isFalse);
    });

    test('is idempotent on clean GFM tables', () {
      const clean = '''
| Month    | Savings |
| -------- | ------- |
| January  | 250     |
''';
      final once = MarkdownPipeTableNormalizer.normalize(clean);
      final twice = MarkdownPipeTableNormalizer.normalize(once);
      expect(twice, once);
    });

    test('does not merge two tables separated by blank lines', () {
      const twoTables = '''
| A | B |
| --- | --- |
| 1 | 2 |

| C | D |
| --- | --- |
| 3 | 4 |
''';
      final document = markdownToDocument(twoTables);
      final tables = document.root.children
          .where((node) => node.type == TableBlockKeys.type)
          .toList();
      expect(tables, hasLength(2));
      expect(tables[0].attributes['rowsLen'], 2);
      expect(tables[1].attributes['rowsLen'], 2);
    });

    test('does not treat a shorter closing fence as a closer', () {
      const fenced = '''
````
| a | b |
```
| c | d |
````
''';
      expect(
        MarkdownPipeTableNormalizer.normalize(fenced).trim(),
        fenced.trim(),
      );
      expect(MarkdownPipeTableNormalizer.containsPipeTable(fenced), isFalse);
    });

    test('info-string fence lines are not closers', () {
      const fenced = '''
```
| a | b |
```dart
| c | d |
```
''';
      expect(
        MarkdownPipeTableNormalizer.containsPipeTable(fenced),
        isFalse,
      );
    });

    test('isPipeTableOnly is false for mixed prose and a table', () {
      const mixed = '''
Skills:

| Skill | Die |
| --- | --- |
| Fighting | d8 |
''';
      expect(MarkdownPipeTableNormalizer.containsPipeTable(mixed), isTrue);
      expect(MarkdownPipeTableNormalizer.isPipeTableOnly(mixed), isFalse);
    });

    test('isPipeTableOnly is true for a Discord-style table paste', () {
      const messy = '''
| Skill | Die |

| --- | --- |

| Fighting | d8 |
''';
      expect(MarkdownPipeTableNormalizer.isPipeTableOnly(messy), isTrue);
    });

    test('htmlContainsRealTable only matches actual table tags', () {
      expect(
        MarkdownPipeTableNormalizer.htmlContainsRealTable(
          '<p>| Skills | Attr |</p>',
        ),
        isFalse,
      );
      expect(
        MarkdownPipeTableNormalizer.htmlContainsRealTable(
          '<table><tr><td>a</td></tr></table>',
        ),
        isTrue,
      );
    });
  });

  group('markdownToDocument pipe tables', () {
    test('parses a clean GFM table', () {
      final document = markdownToDocument('''
| Month    | Savings |
| -------- | ------- |
| January  | 250     |
''');
      expect(document.root.children.first.type, TableBlockKeys.type);
      expect(document.root.children.first.attributes['colsLen'], 2);
      expect(document.root.children.first.attributes['rowsLen'], 2);
    });

    test('parses a Discord-style table with blank lines and bold headers', () {
      const messy = '''
| **Skills**              | **Attribute** | **Die Type** | **Modifier** |

|-------------------------|---------------|--------------|--------------|

| Athletics                              | Agility       | d4           | +0           |

| Common Knowledge        | Smarts        | d4           | +0           |

| Fighting                             | Agility       | d8           | +0           |

| Intimidation                       | Spirit        | d8           | +0           |

| Notice                             | Smarts        | d4           | +0           |

| Persuasion                        | Spirit        | d6           | +0           |

| Riding                             | Agility       | d4           | +0           |

| Stealth                             | Agility       | d4           | +0           |

| Survival                          | Smarts        | d4           | +0           |

| Unskilled Attempt              | -             | d4           | -2           |
''';
      final document = markdownToDocument(messy);
      final table = document.root.children.firstWhere(
        (node) => node.type == TableBlockKeys.type,
      );
      expect(table.attributes['colsLen'], 4);
      expect(table.attributes['rowsLen'], 11);

      String cellText(int col, int row) {
        final cell = table.children.firstWhere(
          (node) =>
              node.attributes['colPosition'] == col &&
              node.attributes['rowPosition'] == row,
        );
        return cell.children.first.delta?.toPlainText() ?? '';
      }

      expect(cellText(0, 0), 'Skills');
      expect(cellText(1, 0), 'Attribute');
      expect(cellText(0, 1), 'Athletics');
      expect(cellText(2, 3), 'd8');
      expect(cellText(3, 10), '-2');
    });
  });
}
