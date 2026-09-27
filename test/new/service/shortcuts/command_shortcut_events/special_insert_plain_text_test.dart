import 'package:appflowy_editor/src/editor/editor_component/service/shortcuts/command/special_insert_plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forEachObjectReplacement walks each U+FFFC in a merged insert', () {
    final parts = <String>[];
    final flags = <bool>[];
    forEachObjectReplacement('Hi\uFFFC+\uFFFC!', (segment, {required isObjectReplacement}) {
      parts.add(segment);
      flags.add(isObjectReplacement);
    });
    expect(parts, ['Hi', '\uFFFC', '+', '\uFFFC', '!']);
    expect(flags, [false, true, false, true, false]);
  });

  test('specialInsertPlainText labels widget chips including merged checkboxes', () {
    expect(
      specialInsertPlainText({
        'richWidget': {
          'type': 'checkbox',
          'label': 'Ready',
          'checked': true,
        },
      }),
      '[x] Ready',
    );
    expect(
      specialInsertPlainText({
        'richWidget': {
          'type': 'counter',
          'label': 'HP',
          'value': 11,
        },
      }),
      'HP: 11',
    );
  });
}
