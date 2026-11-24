import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';

/// Wraps one styled run's [markdown] for attributes the encoder does not
/// know. Returns [markdown] unchanged when [attributes] are not its own.
typedef MarkdownInlineWrapper = String Function(
  String markdown,
  Attributes attributes,
);

/// A [Delta] encoder that encodes a [Delta] to Markdown.
///
/// Only support inline styles, like bold, italic, underline, strike, code.
/// [inlineWrappers] add syntax for other attributes, outside the built-in one.
class DeltaMarkdownEncoder extends Converter<Delta, String> {
  DeltaMarkdownEncoder({this.inlineWrappers = const []});

  final List<MarkdownInlineWrapper> inlineWrappers;

  @override
  String convert(Delta input) {
    final buffer = StringBuffer();
    final iterator = input.iterator;
    while (iterator.moveNext()) {
      final op = iterator.current;
      if (op is TextInsert) {
        final attributes = op.attributes;
        if (attributes != null) {
          final formula = attributes[BuiltInAttributeKey.formula] ?? '';
          var run = _prefixSyntax(attributes) +
              (formula.isNotEmpty ? formula : op.text) +
              _suffixSyntax(attributes);
          for (final wrap in inlineWrappers) {
            run = wrap(run, attributes);
          }
          buffer.write(run);
        } else {
          buffer.write(op.text);
        }
      }
    }

    return buffer.toString();
  }

  String _prefixSyntax(Attributes attributes) {
    var syntax = '';

    if (attributes[BuiltInAttributeKey.bold] == true &&
        attributes[BuiltInAttributeKey.italic] == true) {
      syntax += '***';
    } else if (attributes[BuiltInAttributeKey.bold] == true) {
      syntax += '**';
    } else if (attributes[BuiltInAttributeKey.italic] == true) {
      syntax += '_';
    }

    if (attributes[BuiltInAttributeKey.strikethrough] == true) {
      syntax += '~~';
    }
    if (attributes[BuiltInAttributeKey.underline] == true) {
      syntax += '<u>';
    }
    if (attributes[BuiltInAttributeKey.code] == true) {
      syntax += '`';
    }

    if (attributes[BuiltInAttributeKey.href] != null) {
      syntax += '[';
    }

    if (attributes[BuiltInAttributeKey.formula] != null) {
      syntax += r'$';
    }

    return syntax;
  }

  String _suffixSyntax(Attributes attributes) {
    var syntax = '';

    if (attributes[BuiltInAttributeKey.href] != null) {
      syntax += '](${attributes[BuiltInAttributeKey.href]})';
    }

    if (attributes[BuiltInAttributeKey.code] == true) {
      syntax += '`';
    }

    if (attributes[BuiltInAttributeKey.underline] == true) {
      syntax += '</u>';
    }

    if (attributes[BuiltInAttributeKey.strikethrough] == true) {
      syntax += '~~';
    }

    if (attributes[BuiltInAttributeKey.bold] == true &&
        attributes[BuiltInAttributeKey.italic] == true) {
      syntax += '***';
    } else if (attributes[BuiltInAttributeKey.bold] == true) {
      syntax += '**';
    } else if (attributes[BuiltInAttributeKey.italic] == true) {
      syntax += '_';
    }

    if (attributes[BuiltInAttributeKey.formula] != null) {
      syntax += r'$';
    }

    return syntax;
  }
}
