import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import 'location_tree_entry_selection.dart';

typedef WrapTemplate =
    String Function({
      required String selectedSource,
      required String indent,
      required String builderIndent,
      required String bodyIndent,
      required String entryIndent,
      required String eol,
    });

final class WrapLocationTreeElementEdit {
  final SourceRange range;
  final String replacement;

  const WrapLocationTreeElementEdit({
    required this.range,
    required this.replacement,
  });

  static WrapLocationTreeElementEdit? create({
    required CompilationUnit unit,
    required String source,
    required int selectionOffset,
    required int selectionLength,
    required String eol,
    required WrapTemplate template,
  }) {
    final selectedElement = LocationTreeEntrySelection.find(
      unit: unit,
      source: source,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    );
    if (selectedElement == null) {
      return null;
    }

    final element = selectedElement.element;
    final indent = _indentAt(source, element.offset);
    final builderIndent = '$indent  ';
    final bodyIndent = '$indent    ';
    final entryIndent = '$indent      ';
    final selectedSource = _reindentSelectedSource(
      source.substring(element.offset, element.end),
      entryIndent,
    );

    return WrapLocationTreeElementEdit(
      range: SourceRange(
        element.offset,
        element.end - element.offset,
      ),
      replacement: template(
        selectedSource: selectedSource,
        indent: indent,
        builderIndent: builderIndent,
        bodyIndent: bodyIndent,
        entryIndent: entryIndent,
        eol: eol,
      ),
    );
  }

  static String _indentAt(String source, int offset) {
    final lineStart = source.lastIndexOf('\n', offset - 1);
    final start = lineStart == -1 ? 0 : lineStart + 1;
    final rawIndent = source.substring(start, offset);
    return rawIndent.replaceAll(RegExp(r'[^\t ]'), '');
  }

  static String _reindentSelectedSource(String selectedSource, String childIndent) {
    final lines = selectedSource.split('\n');
    if (lines.length == 1) {
      return '$childIndent${lines.single}';
    }

    final nonBlankTail = lines.skip(1).where((line) => line.trim().isNotEmpty);
    final commonIndent = nonBlankTail.isEmpty
        ? ''
        : ' ' *
              nonBlankTail
                  .map((line) => line.length - line.trimLeft().length)
                  .reduce((a, b) => a < b ? a : b);

    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) {
        buffer.writeln();
      }

      final line = lines[i];
      if (line.trim().isEmpty) {
        buffer.write(line);
        continue;
      }

      final trimmed = i == 0
          ? line.trimLeft()
          : commonIndent.isNotEmpty && line.startsWith(commonIndent)
          ? line.substring(commonIndent.length)
          : line.trimLeft();
      buffer.write('$childIndent$trimmed');
    }
    return buffer.toString();
  }
}
