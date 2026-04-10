import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';

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
    final selectedElement = _LocationTreeListEntryFinder(
      source: source,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    ).find(unit);
    if (selectedElement == null) {
      return null;
    }

    final indent = _indentAt(source, selectedElement.offset);
    final builderIndent = '$indent  ';
    final bodyIndent = '$indent    ';
    final entryIndent = '$indent      ';
    final selectedSource = _reindentSelectedSource(
      source.substring(selectedElement.offset, selectedElement.end),
      entryIndent,
    );

    return WrapLocationTreeElementEdit(
      range: SourceRange(
        selectedElement.offset,
        selectedElement.end - selectedElement.offset,
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

final class _LocationTreeListEntryFinder extends RecursiveAstVisitor<void> {
  final String source;
  final int selectionOffset;
  final int selectionLength;

  CollectionElement? _bestMatch;

  _LocationTreeListEntryFinder({
    required this.source,
    required this.selectionOffset,
    required this.selectionLength,
  });

  CollectionElement? find(CompilationUnit unit) {
    unit.accept(this);
    return _bestMatch;
  }

  @override
  void visitListLiteral(ListLiteral node) {
    if (_isTreeElementList(node)) {
      for (final element in node.elements) {
        if (_intersectsSelection(element) && _isSelectionOnEntryHeader(element)) {
          if (_bestMatch == null ||
              element.length < (_bestMatch!.end - _bestMatch!.offset)) {
            _bestMatch = element;
          }
        }
      }
    }
    super.visitListLiteral(node);
  }

  bool _intersectsSelection(CollectionElement element) {
    final selectionEnd = selectionOffset + selectionLength;
    if (selectionLength == 0) {
      return selectionOffset >= element.offset && selectionOffset <= element.end;
    }
    return selectionOffset < element.end && selectionEnd > element.offset;
  }

  bool _isSelectionOnEntryHeader(CollectionElement element) {
    final headerEnd = _headerEndOffset(element);
    final selectionEnd = selectionOffset + selectionLength;
    if (selectionLength == 0) {
      return selectionOffset >= element.offset && selectionOffset <= headerEnd;
    }
    return selectionOffset < headerEnd && selectionEnd > element.offset;
  }

  int _headerEndOffset(CollectionElement element) {
    final rawEnd = source.indexOf('\n', element.offset);
    final lineEnd = rawEnd == -1 ? source.length : rawEnd;
    return lineEnd < element.end ? lineEnd : element.end;
  }

  bool _isTreeElementList(ListLiteral node) {
    if (_isChildrenAssignmentList(node)) {
      return true;
    }

    final parent = node.parent;
    return parent is ReturnStatement && parent.expression == node ||
        parent is ExpressionFunctionBody && parent.expression == node;
  }

  bool _isChildrenAssignmentList(ListLiteral node) {
    final assignment = node.parent;
    if (assignment is! AssignmentExpression ||
        assignment.rightHandSide != node) {
      return false;
    }

    final leftHandSide = assignment.leftHandSide;
    return switch (leftHandSide) {
      PropertyAccess(propertyName: final propertyName)
          when propertyName.name == 'children' =>
        true,
      PrefixedIdentifier(identifier: final identifier)
          when identifier.name == 'children' =>
        true,
      _ => false,
    };
  }
}
