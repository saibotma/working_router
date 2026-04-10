import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';

import 'location_tree_entry_selection.dart';

final class RemoveLocationTreeElementEdit {
  final SourceRange range;
  final String replacement;

  const RemoveLocationTreeElementEdit({
    required this.range,
    required this.replacement,
  });

  static RemoveLocationTreeElementEdit? create({
    required CompilationUnit unit,
    required String source,
    required int selectionOffset,
    required int selectionLength,
  }) {
    final selection = LocationTreeEntrySelection.find(
      unit: unit,
      source: source,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    );
    if (selection == null) {
      return null;
    }

    final childrenAnalysis = _analyzeDirectChildren(selection.element);
    if (!childrenAnalysis.canRewrite) {
      return null;
    }

    return RemoveLocationTreeElementEdit(
      range: _rangeFor(source, selection),
      replacement: _replacementFor(
        source,
        selection,
        directChildren: childrenAnalysis.children,
      ),
    );
  }

  static SourceRange _rangeFor(
    String source,
    LocationTreeEntrySelection selection,
  ) {
    final element = selection.element;
    final elements = selection.list.elements;
    final isLast = selection.index == elements.length - 1;
    if (!isLast) {
      final next = elements[selection.index + 1];
      return SourceRange(element.offset, next.offset - element.offset);
    }

    final start = _lineStart(source, element.offset);
    final end = _lineEndIncludingNewline(
      source,
      _skipTrailingCommaAndSpaces(source, element.end),
    );
    return SourceRange(start, end - start);
  }

  static String _replacementFor(
    String source,
    LocationTreeEntrySelection selection, {
    required List<CollectionElement> directChildren,
  }) {
    if (directChildren.isEmpty) {
      return '';
    }

    final eol = source.contains('\r\n') ? '\r\n' : '\n';
    final indent = _indentAt(source, selection.element.offset);
    final formattedChildren = directChildren
        .map(
          (child) => _reindentChildSource(
            source.substring(child.offset, child.end),
            indent,
          ),
        )
        .toList();

    final isLast = selection.index == selection.list.elements.length - 1;
    if (isLast) {
      return '${formattedChildren.join(',$eol')},$eol';
    }

    final first = formattedChildren.first.trimLeft();
    final rest = formattedChildren.skip(1);
    final buffer = StringBuffer();
    buffer.write('$first,$eol');
    for (final child in rest) {
      buffer.write('$child,$eol');
    }
    buffer.write(indent);
    return buffer.toString();
  }

  static _DirectChildrenAnalysis _analyzeDirectChildren(CollectionElement element) {
    final buildCallback = _findBuildCallback(element);
    if (buildCallback == null) {
      return const _DirectChildrenAnalysis(
        canRewrite: true,
        children: [],
      );
    }

    final finder = _DirectChildrenAssignmentFinder();
    buildCallback.body.accept(finder);

    if (finder.hasUnsafeChildrenAssignment || finder.assignments.length > 1) {
      return const _DirectChildrenAnalysis(
        canRewrite: false,
        children: [],
      );
    }

    if (finder.assignments.isEmpty) {
      return const _DirectChildrenAnalysis(
        canRewrite: true,
        children: [],
      );
    }

    return _DirectChildrenAnalysis(
      canRewrite: true,
      children: finder.assignments.single,
    );
  }

  static FunctionExpression? _findBuildCallback(CollectionElement element) {
    if (element is! Expression) {
      return null;
    }

    final expression = switch (element) {
      ParenthesizedExpression(expression: final inner) => inner,
      _ => element,
    };

    final argumentList = switch (expression) {
      InstanceCreationExpression(argumentList: final arguments) => arguments,
      MethodInvocation(argumentList: final arguments) => arguments,
      _ => null,
    };

    if (argumentList == null) {
      return null;
    }

    for (final argument in argumentList.arguments) {
      if (argument is! NamedExpression) {
        continue;
      }
      if (argument.name.label.name != 'build') {
        continue;
      }
      final callback = argument.expression;
      if (callback is FunctionExpression) {
        return callback;
      }
    }
    return null;
  }

  static int _lineStart(String source, int offset) {
    final rawStart = source.lastIndexOf('\n', offset - 1);
    return rawStart == -1 ? 0 : rawStart + 1;
  }

  static int _skipTrailingCommaAndSpaces(String source, int offset) {
    var current = offset;
    if (current < source.length && source[current] == ',') {
      current++;
    }
    while (current < source.length) {
      final char = source[current];
      if (char == ' ' || char == '\t') {
        current++;
        continue;
      }
      break;
    }
    return current;
  }

  static int _lineEndIncludingNewline(String source, int offset) {
    var current = offset;
    if (current < source.length && source[current] == '\r') {
      current++;
    }
    if (current < source.length && source[current] == '\n') {
      current++;
    }
    return current;
  }

  static String _indentAt(String source, int offset) {
    final lineStart = source.lastIndexOf('\n', offset - 1);
    final start = lineStart == -1 ? 0 : lineStart + 1;
    final rawIndent = source.substring(start, offset);
    return rawIndent.replaceAll(RegExp(r'[^\t ]'), '');
  }

  static String _reindentChildSource(String selectedSource, String childIndent) {
    final lines = selectedSource.split('\n');
    if (lines.length == 1) {
      return '$childIndent${lines.single.trimLeft()}';
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

final class _DirectChildrenAnalysis {
  final bool canRewrite;
  final List<CollectionElement> children;

  const _DirectChildrenAnalysis({
    required this.canRewrite,
    required this.children,
  });
}

final class _DirectChildrenAssignmentFinder extends RecursiveAstVisitor<void> {
  final List<List<CollectionElement>> assignments = [];
  var _controlFlowDepth = 0;
  var hasUnsafeChildrenAssignment = false;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Ignore descendant route build callbacks while inspecting the selected
    // element's own build callback.
  }

  @override
  void visitIfStatement(IfStatement node) {
    _withControlFlow(() => super.visitIfStatement(node));
  }

  @override
  void visitForStatement(ForStatement node) {
    _withControlFlow(() => super.visitForStatement(node));
  }

  @override
  void visitForElement(ForElement node) {
    _withControlFlow(() => super.visitForElement(node));
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _withControlFlow(() => super.visitWhileStatement(node));
  }

  @override
  void visitDoStatement(DoStatement node) {
    _withControlFlow(() => super.visitDoStatement(node));
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _withControlFlow(() => super.visitSwitchStatement(node));
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _withControlFlow(() => super.visitConditionalExpression(node));
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_isChildrenTarget(node.leftHandSide) && node.rightHandSide is ListLiteral) {
      if (_controlFlowDepth > 0) {
        hasUnsafeChildrenAssignment = true;
      }
      assignments.add((node.rightHandSide as ListLiteral).elements);
      return;
    }

    super.visitAssignmentExpression(node);
  }

  void _withControlFlow(void Function() callback) {
    _controlFlowDepth++;
    callback();
    _controlFlowDepth--;
  }

  bool _isChildrenTarget(Expression expression) {
    return switch (expression) {
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
