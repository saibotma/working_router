import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

final class LocationTreeEntrySelection {
  final ListLiteral list;
  final CollectionElement element;
  final int index;
  final bool isChildrenAssignmentList;

  const LocationTreeEntrySelection({
    required this.list,
    required this.element,
    required this.index,
    required this.isChildrenAssignmentList,
  });

  static LocationTreeEntrySelection? find({
    required CompilationUnit unit,
    required String source,
    required int selectionOffset,
    required int selectionLength,
  }) {
    return _LocationTreeListEntryFinder(
      source: source,
      selectionOffset: selectionOffset,
      selectionLength: selectionLength,
    ).find(unit);
  }
}

final class _LocationTreeListEntryFinder extends RecursiveAstVisitor<void> {
  final String source;
  final int selectionOffset;
  final int selectionLength;

  LocationTreeEntrySelection? _bestMatch;

  _LocationTreeListEntryFinder({
    required this.source,
    required this.selectionOffset,
    required this.selectionLength,
  });

  LocationTreeEntrySelection? find(CompilationUnit unit) {
    unit.accept(this);
    return _bestMatch;
  }

  @override
  void visitListLiteral(ListLiteral node) {
    final isChildrenAssignmentList = _isChildrenAssignmentList(node);
    if (isChildrenAssignmentList || _isReturnedTreeElementList(node)) {
      for (var i = 0; i < node.elements.length; i++) {
        final element = node.elements[i];
        if (_intersectsSelection(element) && _isSelectionOnEntryHeader(element)) {
          if (_bestMatch == null ||
              element.length < (_bestMatch!.element.end - _bestMatch!.element.offset)) {
            _bestMatch = LocationTreeEntrySelection(
              list: node,
              element: element,
              index: i,
              isChildrenAssignmentList: isChildrenAssignmentList,
            );
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

  bool _isReturnedTreeElementList(ListLiteral node) {
    final parent = node.parent;
    return parent is ReturnStatement && parent.expression == node ||
        parent is ExpressionFunctionBody && parent.expression == node;
  }

  bool _isChildrenAssignmentList(ListLiteral node) {
    final assignment = node.parent;
    if (assignment is! AssignmentExpression || assignment.rightHandSide != node) {
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
