import 'dart:async';
import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';
import 'package:working_router/src/route_generation/route_nodes.dart';

class RouteHelpersGenerator extends GeneratorForAnnotation<RouteNodes> {
  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final declarationElement = _declarationElement(element);
    final typeSource = _idTypeSource(declarationElement);
    final extractor = _StaticRouteTreeExtractor(
      buildStep: buildStep,
      rootElement: declarationElement,
    );
    final roots = await extractor.extract(declarationElement);
    final methods = _collectRouteMethods(roots, declarationElement);
    final queryParameterMixins = await _collectQueryParameterMixins(
      roots,
      buildStep,
    );
    if (methods.isEmpty && queryParameterMixins.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();

    for (final mixin in queryParameterMixins) {
      buffer.writeln(mixin.render());
    }

    if (methods.isNotEmpty) {
      for (final method in methods) {
        buffer.writeln(method.renderTargetClass());
      }

      final extensionName =
          '${_toUpperCamelCase(declarationElement.displayName)}GeneratedRoutes';
      buffer.writeln(
        'extension $extensionName on WorkingRouterSailor<$typeSource> {',
      );

      for (final method in methods) {
        buffer.writeln(method.renderMethod());
      }

      buffer.writeln('}');
    }
    return buffer.toString();
  }

  String _idTypeSource(Element element) {
    final type = switch (element) {
      ExecutableElement() => element.returnType,
      PropertyInducingElement() => element.type,
      _ => throw InvalidGenerationSourceError(
        '@RouteNodes can only be applied to top-level location '
        'builders, getters, or variables.',
        element: element,
      ),
    };

    _validateDeclarationTarget(element);

    if (type is! InterfaceType) {
      throw InvalidGenerationSourceError(
        'The annotated declaration must have type RouteNode<ID> or '
        'Iterable<RouteNode<ID>>.',
        element: element,
      );
    }

    final routeNodeType = _routeNodeType(type);
    if (routeNodeType == null || routeNodeType.typeArguments.length != 1) {
      throw InvalidGenerationSourceError(
        'The annotated declaration must have type RouteNode<ID> or '
        'Iterable<RouteNode<ID>>.',
        element: element,
      );
    }

    return routeNodeType.typeArguments.single.getDisplayString();
  }

  void _validateDeclarationTarget(Element element) {
    final isTopLevel = element.enclosingElement is LibraryElement;

    final isSupported = switch (element) {
      TopLevelFunctionElement() => true,
      GetterElement() => isTopLevel,
      PropertyInducingElement() => isTopLevel,
      _ => false,
    };

    if (!isSupported) {
      throw InvalidGenerationSourceError(
        '@RouteNodes must target a top-level declaration. '
        'Static helper members inside the route tree are supported, but '
        'the annotated entrypoint itself must be top-level so source_gen '
        'can discover it.',
        element: element,
      );
    }
  }

  Element _declarationElement(Element element) {
    if (element is PropertyAccessorElement && element.isSynthetic) {
      return element.variable;
    }
    return element;
  }

  List<_GeneratedRouteMethod> _collectRouteMethods(
    Iterable<_RouteNode> roots,
    Element element,
  ) {
    final methods = <_GeneratedRouteMethod>[];
    final usedMethodsByName = <String, _GeneratedRouteMethod>{};

    void visit(_RouteNode node, List<_RouteNode> chain) {
      final nextChain = [...chain, node];
      if (node.idExpression != null) {
        final method = _buildMethod(nextChain, node.idExpression!, element);
        final previousMethod = usedMethodsByName[method.name];
        if (previousMethod != null && !previousMethod.isEquivalent(method)) {
          throw InvalidGenerationSourceError(
            'Duplicate generated method name `${method.name}`.',
            element: element,
          );
        }
        if (previousMethod == null) {
          usedMethodsByName[method.name] = method;
          methods.add(method);
        }
      }

      if (chain.isNotEmpty && node.isLocation) {
        final childMethod = _buildChildMethod(node, element);
        final previousMethod = usedMethodsByName[childMethod.name];
        if (previousMethod != null &&
            !previousMethod.isEquivalent(childMethod)) {
          throw InvalidGenerationSourceError(
            'Duplicate generated method name `${childMethod.name}`.',
            element: element,
          );
        }
        if (previousMethod == null) {
          usedMethodsByName[childMethod.name] = childMethod;
          methods.add(childMethod);
        }
      }

      for (final child in node.children) {
        visit(child, nextChain);
      }
    }

    for (final root in roots) {
      visit(root, const []);
    }
    return methods;
  }

  _GeneratedRouteMethod _buildMethod(
    List<_RouteNode> chain,
    String idExpression,
    Element element,
  ) {
    final methodName =
        'routeTo${_toUpperCamelCase(idExpression.split('.').last)}';
    final targetClassName =
        '${_toUpperCamelCase(idExpression.split('.').last)}RouteTarget';
    final (pathParameters, queryParameters) = _collectParameters(
      chain,
      element: element,
      errorContext: idExpression,
    );
    final pathWrites = _collectPathWrites(
      chain,
      pathParameters,
      element: element,
      errorContext: idExpression,
    );

    return _GeneratedRouteMethod.toId(
      idTypeSource: _idTypeSource(element),
      name: methodName,
      targetClassName: targetClassName,
      idExpression: idExpression,
      pathWrites: pathWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  _GeneratedRouteMethod _buildChildMethod(_RouteNode node, Element element) {
    final methodName =
        'routeToChild${_toUpperCamelCase(_childMethodBaseName(node.locationTypeSource))}';
    final targetClassName =
        'Child${_toUpperCamelCase(_childMethodBaseName(node.locationTypeSource))}RouteTarget';
    final (pathParameters, queryParameters) = _collectParameters(
      [node],
      element: element,
      errorContext: node.locationTypeSource,
    );
    final pathWrites = _collectPathWrites(
      [node],
      pathParameters,
      element: element,
      errorContext: node.locationTypeSource,
    );

    return _GeneratedRouteMethod.toChild(
      idTypeSource: _idTypeSource(element),
      name: methodName,
      targetClassName: targetClassName,
      childLocationTypeSource: node.locationTypeSource,
      pathWrites: pathWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  (Map<String, _GeneratedRouteParameter>, Map<String, _GeneratedRouteParameter>)
  _collectParameters(
    Iterable<_RouteNode> nodes, {
    required Element element,
    required String errorContext,
  }) {
    final pathParameters = <String, _GeneratedRouteParameter>{};
    final queryParameters = <String, _GeneratedRouteParameter>{};
    final usedParameterNames = <String, String>{};

    void registerParameter(
      _GeneratedRouteParameter parameter,
      Map<String, _GeneratedRouteParameter> target,
      String kind,
    ) {
      final originalName = parameter.routeKey;
      if (target.containsKey(originalName)) {
        if (identical(target, pathParameters)) {
          throw InvalidGenerationSourceError(
            'The generated helper for `$errorContext` needs two path '
            'parameters named `$originalName`. Rename one of those path '
            'parameter fields.',
            element: element,
          );
        }
        final existing = target[originalName]!;
        if (existing.dartTypeSource != parameter.dartTypeSource ||
            existing.optional != parameter.optional ||
            existing.codecExpressionSource != parameter.codecExpressionSource) {
          throw InvalidGenerationSourceError(
            'The generated helper for `$errorContext` needs conflicting $kind '
            'parameter metadata for `$originalName`.',
            element: element,
          );
        }
        return;
      }

      final parameterName = _toParameterIdentifier(originalName);
      final previousOriginalName = usedParameterNames[parameterName];
      if (previousOriginalName != null &&
          previousOriginalName != originalName) {
        throw InvalidGenerationSourceError(
          'The generated helper for `$errorContext` needs two $kind '
          'parameters that both map to `$parameterName` '
          '($previousOriginalName and $originalName).',
          element: element,
        );
      }

      if (pathParameters.containsKey(originalName) &&
          !identical(target, pathParameters)) {
        throw InvalidGenerationSourceError(
          'The generated helper for `$errorContext` uses `$originalName` as '
          'both a path parameter and a query parameter.',
          element: element,
        );
      }

      usedParameterNames[parameterName] = originalName;
      target[originalName] = parameter.copyWith(parameterName: parameterName);
    }

    for (final node in nodes) {
      for (final segment in node.pathSegments) {
        if (segment case _RoutePathParameterSegmentMetadata()) {
          registerParameter(
            _GeneratedRouteParameter(
              routeKey: segment.key,
              parameterName: '',
              dartTypeSource: segment.dartTypeSource,
              codecExpressionSource: segment.codecExpressionSource,
              optional: false,
            ),
            pathParameters,
            'path',
          );
        }
      }

      for (final queryParameter in node.queryParameters.values) {
        registerParameter(
          _GeneratedRouteParameter(
            routeKey: queryParameter.key,
            parameterName: '',
            dartTypeSource: queryParameter.dartTypeSource,
            codecExpressionSource: queryParameter.codecExpressionSource,
            optional: queryParameter.optional,
          ),
          queryParameters,
          'query',
        );
      }
    }

    return (pathParameters, queryParameters);
  }

  List<_GeneratedPathWrite> _collectPathWrites(
    Iterable<_RouteNode> nodes,
    Map<String, _GeneratedRouteParameter> pathParameters, {
    required Element element,
    required String errorContext,
  }) {
    final writes = <_GeneratedPathWrite>[];
    final locationOccurrences = <String, int>{};

    for (final node in nodes) {
      final occurrenceIndex = locationOccurrences[node.locationTypeSource] ?? 0;
      for (final segment
          in node.pathSegments
              .whereType<_RoutePathParameterSegmentMetadata>()) {
        final memberName = segment.memberName;
        if (memberName == null) {
          throw InvalidGenerationSourceError(
            'The generated helper for `$errorContext` needs path parameters to '
            'be declared as fields like `final foo = pathParam(...)`.',
            element: element,
          );
        }

        final generatedParameter = pathParameters[segment.key];
        if (generatedParameter == null) {
          continue;
        }

        writes.add(
          _GeneratedPathWrite(
            locationTypeSource: node.locationTypeSource,
            occurrenceIndex: occurrenceIndex,
            memberName: memberName,
            parameterName: generatedParameter.parameterName,
          ),
        );
      }
      locationOccurrences[node.locationTypeSource] = occurrenceIndex + 1;
    }

    return writes;
  }

  InterfaceType? _routeNodeSupertype(InterfaceType type) {
    InterfaceType? current = type;
    while (current != null) {
      if (current.element.name == 'RouteNode') {
        return current;
      }
      current = current.superclass;
    }
    return null;
  }

  InterfaceType? _routeNodeType(DartType type) {
    if (type is! InterfaceType) {
      return null;
    }

    final directRouteNode = _routeNodeSupertype(type);
    if (directRouteNode != null) {
      return directRouteNode;
    }

    if (type.typeArguments.length == 1) {
      return _routeNodeType(type.typeArguments.single);
    }

    return null;
  }

  InterfaceType? _locationSupertype(InterfaceType type) {
    InterfaceType? current = type;
    while (current != null) {
      if (current.element.name == 'Location') {
        return current;
      }
      current = current.superclass;
    }
    return null;
  }

  Future<List<_GeneratedLocationMixin>> _collectQueryParameterMixins(
    Iterable<_RouteNode> roots,
    BuildStep buildStep,
  ) async {
    final mixins = <_GeneratedLocationMixin>[];
    final seenClassNames = <String>{};

    Future<void> visit(_RouteNode node) async {
      if (node.isLocation && seenClassNames.add(node.locationTypeSource)) {
        final inferredQueryParameters = node.queryParameters.values
            .where((parameter) => parameter.memberName != null)
            .toList(growable: false);
        if (inferredQueryParameters.isNotEmpty) {
          final shouldGenerateMixin = await _shouldGenerateMixin(
            node.locationClassElement,
            buildStep,
            requiresQueryMetadata: inferredQueryParameters.isNotEmpty,
          );
          if (shouldGenerateMixin) {
            mixins.add(
              _GeneratedLocationMixin(
                mixinName: _generatedLocationMixinName(
                  node.locationClassElement.displayName,
                ),
                locationBaseTypeSource: _locationSupertype(
                  node.locationClassElement.thisType,
                )!.getDisplayString(),
                queryParameters: inferredQueryParameters,
              ),
            );
          }
        }
      }

      for (final child in node.children) {
        await visit(child);
      }
    }

    for (final root in roots) {
      await visit(root);
    }
    return mixins;
  }

  Future<bool> _shouldGenerateMixin(
    InterfaceElement classElement,
    BuildStep buildStep, {
    required bool requiresQueryMetadata,
  }) async {
    final node = await buildStep.resolver.astNodeFor(
      classElement.firstFragment,
      resolve: true,
    );
    if (node is! ClassDeclaration) {
      return false;
    }

    final mixinName = _generatedLocationMixinName(classElement.displayName);
    final usedMixinNames =
        node.withClause?.mixinTypes
            .map((mixinType) => mixinType.name.lexeme)
            .toSet() ??
        const <String>{};
    if (usedMixinNames.contains(mixinName)) {
      return true;
    }

    final declaresQueryParameters = _declaresMember(node, 'queryParameters');
    final stillNeedsMixin = requiresQueryMetadata && !declaresQueryParameters;
    if (!stillNeedsMixin) {
      return false;
    }

    throw InvalidGenerationSourceError(
      '`${classElement.displayName}` declares generated QueryParam fields but '
      'does not '
      'mix in `$mixinName`. Add `with $mixinName` to `${classElement.displayName}` '
      'so the generated route metadata is used at runtime.',
      element: classElement,
    );
  }

  bool _declaresMember(ClassDeclaration node, String memberName) {
    return node.members.any((member) {
      return switch (member) {
        MethodDeclaration(name: final name) => name.lexeme == memberName,
        FieldDeclaration(fields: final fields) => fields.variables.any(
          (variable) => variable.name.lexeme == memberName,
        ),
        _ => false,
      };
    });
  }
}

class _StaticRouteTreeExtractor {
  final BuildStep buildStep;
  final Element rootElement;

  _StaticRouteTreeExtractor({
    required this.buildStep,
    required this.rootElement,
  });

  Future<List<_RouteNode>> extract(Element element) async {
    final expression = await _declarationExpression(element);
    return _routeNodesFromTreeExpression(expression);
  }

  Future<List<_RouteNode>> _routeNodesFromTreeExpression(
    Expression expression, {
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);

    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _routeNodesFromTreeExpression(
          boundExpression,
          evaluationContext: evaluationContext,
        );
      }
    }

    final helperInvocation = await _helperInvocation(
      normalizedExpression,
      evaluationContext: evaluationContext,
    );
    if (helperInvocation != null) {
      return _routeNodesFromTreeExpression(
        helperInvocation.expression,
        evaluationContext: helperInvocation.context,
      );
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final targetExpression = await _declarationExpression(referencedElement);
      return _routeNodesFromTreeExpression(targetExpression);
    }

    if (normalizedExpression is ListLiteral) {
      return _locationsFromListExpression(
        normalizedExpression,
        evaluationContext: evaluationContext,
      );
    }

    return [
      await _locationFromExpression(
        normalizedExpression,
        evaluationContext: evaluationContext,
      ),
    ];
  }

  Future<Expression> _declarationExpression(Element element) async {
    final declarationElement = _normalizeDeclarationElement(element);
    final node = await buildStep.resolver.astNodeFor(
      _fragmentFor(declarationElement),
      resolve: true,
    );

    if (node is FunctionDeclaration) {
      return _bodyExpression(node.functionExpression.body, declarationElement);
    }
    if (node is FunctionDeclarationStatement) {
      return _bodyExpression(
        node.functionDeclaration.functionExpression.body,
        declarationElement,
      );
    }
    if (node is MethodDeclaration) {
      return _bodyExpression(node.body, declarationElement);
    }
    if (node is VariableDeclaration) {
      final initializer = node.initializer;
      if (initializer == null) {
        throw InvalidGenerationSourceError(
          'The annotated location tree variable must have an initializer.',
          element: declarationElement,
        );
      }
      return initializer;
    }
    if (node is VariableDeclarationList) {
      final variable = node.variables.firstWhereOrNull(
        (candidate) => candidate.name.lexeme == declarationElement.displayName,
      );
      final initializer = variable?.initializer;
      if (initializer == null) {
        throw InvalidGenerationSourceError(
          'The annotated location tree variable must have an initializer.',
          element: declarationElement,
        );
      }
      return initializer;
    }
    if (node is FieldDeclaration) {
      final variable = node.fields.variables.firstWhereOrNull(
        (candidate) => candidate.name.lexeme == declarationElement.displayName,
      );
      final initializer = variable?.initializer;
      if (initializer == null) {
        throw InvalidGenerationSourceError(
          'The annotated location tree variable must have an initializer.',
          element: declarationElement,
        );
      }
      return initializer;
    }
    if (node is TopLevelVariableDeclaration) {
      final variable = node.variables.variables.firstWhereOrNull(
        (candidate) => candidate.name.lexeme == declarationElement.displayName,
      );
      final initializer = variable?.initializer;
      if (initializer == null) {
        throw InvalidGenerationSourceError(
          'The annotated location tree variable must have an initializer.',
          element: declarationElement,
        );
      }
      return initializer;
    }

    throw InvalidGenerationSourceError(
      'Unable to read the annotated location tree source.',
      element: declarationElement,
    );
  }

  Expression _bodyExpression(FunctionBody body, Element element) {
    if (body is ExpressionFunctionBody) {
      return body.expression;
    }
    if (body is BlockFunctionBody) {
      final returnExpression = body.block.statements
          .whereType<ReturnStatement>()
          .map((statement) => statement.expression)
          .nonNulls
          .firstOrNull;
      if (returnExpression != null) {
        return returnExpression;
      }
    }

    throw InvalidGenerationSourceError(
      'Only simple declarations that return a static expression are supported.',
      element: element,
    );
  }

  Future<_RouteNode> _locationFromExpression(
    Expression expression, {
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);

    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _locationFromExpression(
          boundExpression,
          evaluationContext: evaluationContext,
        );
      }
    }

    if (normalizedExpression is InstanceCreationExpression) {
      return _locationFromCreation(
        normalizedExpression,
        evaluationContext: evaluationContext,
      );
    }

    final helperInvocation = await _helperInvocation(
      normalizedExpression,
      evaluationContext: evaluationContext,
    );
    if (helperInvocation != null) {
      return _locationFromExpression(
        helperInvocation.expression,
        evaluationContext: helperInvocation.context,
      );
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final targetExpression = await _declarationExpression(referencedElement);
      return _locationFromExpression(targetExpression);
    }

    throw InvalidGenerationSourceError(
      'Unsupported route tree expression `${normalizedExpression.toSource()}`. '
      'Use static constructor trees, helper getters, helper variables, or '
      'zero-argument helper functions.',
      element: rootElement,
    );
  }

  Future<_RouteNode> _locationFromCreation(
    InstanceCreationExpression expression, {
    _ExpressionContext? evaluationContext,
  }) async {
    final constructor = expression.constructorName.element;
    final classElement = constructor?.enclosingElement;
    if (constructor == null || classElement is! InterfaceElement) {
      throw InvalidGenerationSourceError(
        'Unable to resolve `${expression.toSource()}`.',
        element: rootElement,
      );
    }

    if (!_isRouteNodeClass(classElement)) {
      throw InvalidGenerationSourceError(
        '`${expression.toSource()}` does not create a RouteNode.',
        element: rootElement,
      );
    }

    final context = await _InstanceStringContext.fromCreation(
      buildStep: buildStep,
      creation: expression,
      rootElement: rootElement,
      parentContext: evaluationContext,
    );
    final isLocation = _isLocationClass(classElement);
    final pathSegments = isLocation
        ? await _resolvePathSegments(context)
        : const <_PathSegmentMetadata>[];
    final queryParameters = isLocation
        ? await _resolveQueryParameters(
            classElement,
            evaluationContext: context,
          )
        : const <String, _RouteQueryParameterMetadata>{};
    final childrenExpression = await context.locationChildrenExpression();
    final children = childrenExpression == null
        ? const <_RouteNode>[]
        : await _locationsFromListExpression(
            childrenExpression,
            evaluationContext: context,
          );

    return _RouteNode(
      idExpression: isLocation
          ? await _resolveIdExpression(
              _namedArgumentExpression(
                expression.argumentList.arguments,
                'id',
              ),
              evaluationContext: evaluationContext,
            )
          : null,
      isLocation: isLocation,
      locationClassElement: classElement,
      locationTypeSource: classElement.displayName,
      pathSegments: pathSegments,
      queryParameters: queryParameters,
      children: children,
    );
  }

  Future<List<_RouteNode>> _locationsFromListExpression(
    Expression expression, {
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);

    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _locationsFromListExpression(
          boundExpression,
          evaluationContext: evaluationContext,
        );
      }
    }

    final helperInvocation = await _helperInvocation(
      normalizedExpression,
      evaluationContext: evaluationContext,
    );
    if (helperInvocation != null) {
      return _locationsFromListExpression(
        helperInvocation.expression,
        evaluationContext: helperInvocation.context,
      );
    }

    if (normalizedExpression is ListLiteral) {
      final result = <_RouteNode>[];
      for (final element in normalizedExpression.elements) {
        result.addAll(
          await _locationsFromCollectionElement(
            element,
            evaluationContext: evaluationContext,
          ),
        );
      }
      return result;
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final targetExpression = await _declarationExpression(referencedElement);
      return _locationsFromListExpression(targetExpression);
    }

    throw InvalidGenerationSourceError(
      'Unsupported children expression `${normalizedExpression.toSource()}`. '
      'Use list literals, collection ifs, spreads, helper getters, helper '
      'variables, or zero-argument helper functions.',
      element: rootElement,
    );
  }

  Future<List<_RouteNode>> _locationsFromCollectionElement(
    CollectionElement element, {
    _ExpressionContext? evaluationContext,
  }) async {
    switch (element) {
      case Expression():
        return [
          await _locationFromExpression(
            element,
            evaluationContext: evaluationContext,
          ),
        ];
      case SpreadElement():
        return _locationsFromListExpression(
          element.expression,
          evaluationContext: evaluationContext,
        );
      case IfElement():
        final result = <_RouteNode>[];
        result.addAll(
          await _locationsFromCollectionElement(
            element.thenElement,
            evaluationContext: evaluationContext,
          ),
        );
        final elseElement = element.elseElement;
        if (elseElement != null) {
          result.addAll(
            await _locationsFromCollectionElement(
              elseElement,
              evaluationContext: evaluationContext,
            ),
          );
        }
        return result;
      default:
        throw InvalidGenerationSourceError(
          'Unsupported list element `${element.toSource()}` in the location '
          'tree.',
          element: rootElement,
        );
    }
  }

  Future<String?> _resolveIdExpression(
    Expression? expression, {
    _ExpressionContext? evaluationContext,
  }) async {
    if (expression == null) {
      return null;
    }

    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is NullLiteral) {
      return null;
    }
    if (normalizedExpression is ConditionalExpression) {
      if (evaluationContext == null) {
        throw InvalidGenerationSourceError(
          'Conditional id expressions are only supported when they can be '
          'resolved from constructor arguments of the enclosing location.',
          element: rootElement,
        );
      }
      final resolvedExpression = await evaluationContext.resolveIdExpression(
        normalizedExpression,
      );
      return resolvedExpression?.toSource();
    }

    return normalizedExpression.toSource();
  }

  Future<_ResolvedHelperInvocation?> _helperInvocation(
    Expression expression, {
    required _ExpressionContext? evaluationContext,
  }) async {
    if (expression is! MethodInvocation &&
        expression is! FunctionExpressionInvocation) {
      return null;
    }

    final executable = _invokedExecutableElement(expression);
    if (executable == null) {
      return null;
    }

    _validateInvokedHelperElement(executable);
    final helperContext = await _FunctionExpressionContext.fromInvocation(
      buildStep: buildStep,
      rootElement: rootElement,
      executable: executable,
      arguments: _invocationArguments(expression),
      parentContext: evaluationContext,
    );
    final targetExpression = await _declarationExpression(executable);
    return _ResolvedHelperInvocation(
      expression: targetExpression,
      context: helperContext,
    );
  }

  Future<List<_PathSegmentMetadata>> _resolvePathSegments(
    _InstanceStringContext context,
  ) async {
    final classElement = context.classElement;
    final getter = classElement.lookUpGetter(
      name: 'path',
      library: classElement.library,
    );
    if (getter == null) {
      throw InvalidGenerationSourceError(
        '`${classElement.name}` does not define a path getter.',
        element: classElement,
      );
    }

    final node = await buildStep.resolver.astNodeFor(
      getter.firstFragment,
      resolve: true,
    );
    if (node is! MethodDeclaration && node is! FunctionDeclaration) {
      throw InvalidGenerationSourceError(
        'Unsupported path declaration in `${classElement.name}`.',
        element: getter,
      );
    }

    final body = switch (node) {
      MethodDeclaration() => node.body,
      FunctionDeclaration() => node.functionExpression.body,
      _ => throw StateError('Unreachable'),
    };
    final expression = _bodyExpression(body, getter);
    return _pathSegmentListLiteral(
      expression,
      getter,
      evaluationContext: context,
    );
  }

  Future<Map<String, _RouteQueryParameterMetadata>> _resolveQueryParameters(
    InterfaceElement classElement, {
    _ExpressionContext? evaluationContext,
  }) async {
    final getter = classElement.lookUpGetter(
      name: 'queryParameters',
      library: classElement.library,
    );
    if (getter != null && getter.enclosingElement.displayName != 'Location') {
      final node = await buildStep.resolver.astNodeFor(
        getter.firstFragment,
        resolve: true,
      );
      if (node is! MethodDeclaration && node is! FunctionDeclaration) {
        throw InvalidGenerationSourceError(
          'Unsupported queryParameters declaration in `${classElement.name}`.',
          element: getter,
        );
      }

      final body = switch (node) {
        MethodDeclaration() => node.body,
        FunctionDeclaration() => node.functionExpression.body,
        _ => throw StateError('Unreachable'),
      };
      final expression = _bodyExpression(body, getter);
      return _queryParameterMapLiteral(
        expression,
        getter,
        evaluationContext: evaluationContext,
      );
    }

    return _queryParametersFromDeclaredFields(classElement);
  }

  Future<Map<String, _RouteQueryParameterMetadata>>
  _queryParametersFromDeclaredFields(
    InterfaceElement classElement,
  ) async {
    final node = await buildStep.resolver.astNodeFor(
      classElement.firstFragment,
      resolve: true,
    );
    if (node is! ClassDeclaration) {
      return <String, _RouteQueryParameterMetadata>{};
    }

    final result = <String, _RouteQueryParameterMetadata>{};
    for (final member in node.members.whereType<FieldDeclaration>()) {
      if (member.isStatic) {
        continue;
      }

      for (final variable in member.fields.variables) {
        final fieldElement = variable.declaredFragment?.element;
        if (fieldElement == null || !_isQueryParamType(fieldElement.type)) {
          continue;
        }

        final initializer = variable.initializer;
        if (initializer == null) {
          throw InvalidGenerationSourceError(
            'QueryParam field `${variable.name.lexeme}` in `${classElement.name}` '
            'needs an initializer.',
            element: fieldElement,
          );
        }

        final metadata = await _queryParameterMetadata(
          initializer,
          key: variable.name.lexeme,
          element: fieldElement,
        );
        _registerQueryParameterMetadata(
          metadata.copyWith(memberName: variable.name.lexeme),
          result,
          element: fieldElement,
        );
      }
    }

    return result;
  }

  Future<List<_PathSegmentMetadata>> _pathSegmentListLiteral(
    Expression expression,
    Element element, {
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _pathSegmentListLiteral(
          boundExpression,
          element,
          evaluationContext: evaluationContext,
        );
      }
    }

    if (normalizedExpression is ListLiteral) {
      final result = <_PathSegmentMetadata>[];
      for (final item in normalizedExpression.elements) {
        if (item is! Expression) {
          throw InvalidGenerationSourceError(
            'Only literal route path segment lists are supported for path.',
            element: element,
          );
        }
        result.add(
          await _pathSegmentMetadata(
            item,
            element,
            evaluationContext: evaluationContext,
          ),
        );
      }
      return result;
    }

    final helperInvocation = await _helperInvocation(
      normalizedExpression,
      evaluationContext: evaluationContext,
    );
    if (helperInvocation != null) {
      return _pathSegmentListLiteral(
        helperInvocation.expression,
        element,
        evaluationContext: helperInvocation.context,
      );
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final targetExpression = await _declarationExpression(referencedElement);
      return _pathSegmentListLiteral(
        targetExpression,
        referencedElement,
        evaluationContext: evaluationContext,
      );
    }

    throw InvalidGenerationSourceError(
      'Only literal route path segment lists are supported for path.',
      element: element,
    );
  }

  Future<_PathSegmentMetadata> _pathSegmentMetadata(
    Expression expression,
    Element element, {
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    final fieldElement = _fieldElementForExpression(normalizedExpression);
    if (fieldElement != null && _isPathParamType(fieldElement.type)) {
      return _pathParameterMetadataFromField(
        fieldElement,
        element: element,
        evaluationContext: evaluationContext,
      );
    }

    if (normalizedExpression is MethodInvocation &&
        normalizedExpression.methodName.name == 'pathParam') {
      throw InvalidGenerationSourceError(
        'Inline pathParam(...) calls in path are not supported. Declare a '
        'field like `final foo = pathParam(...)` and use that field in path.',
        element: element,
      );
    }

    if (normalizedExpression is! InstanceCreationExpression) {
      final referencedElement = _expressionElement(normalizedExpression);
      if (referencedElement != null) {
        final targetExpression = await _declarationExpression(
          referencedElement,
        );
        return _pathSegmentMetadata(
          targetExpression,
          referencedElement,
          evaluationContext: evaluationContext,
        );
      }
      throw InvalidGenerationSourceError(
        'Only route path segment constructor calls are supported in path.',
        element: element,
      );
    }

    final constructorTypeName = normalizedExpression.constructorName.type
        .toSource()
        .split('<')
        .first;
    final constructorName = normalizedExpression.constructorName.name?.name;
    final isLiteralPathSegment =
        constructorTypeName == 'LiteralPathSegment' ||
        (constructorTypeName == 'PathSegment' && constructorName == 'literal');
    if (isLiteralPathSegment) {
      final valueExpression = normalizedExpression.argumentList.arguments
          .whereType<Expression>()
          .firstOrNull;
      if (valueExpression == null) {
        throw InvalidGenerationSourceError(
          'LiteralPathSegment requires a string value.',
          element: element,
        );
      }
      return _LiteralPathSegmentMetadata(
        value: _stringLiteral(valueExpression, element),
      );
    }

    if (constructorTypeName == 'PathParam') {
      throw InvalidGenerationSourceError(
        'Inline PathParam(...) constructor calls in path are not supported. '
        'Declare a field like `final foo = pathParam(...)` and use that field '
        'in path.',
        element: element,
      );
    }

    throw InvalidGenerationSourceError(
      'Unsupported path segment `${normalizedExpression.toSource()}`.',
      element: element,
    );
  }

  Future<_RoutePathParameterSegmentMetadata> _pathParameterMetadataFromField(
    PropertyInducingElement fieldElement, {
    required Element element,
    _ExpressionContext? evaluationContext,
  }) async {
    final fieldNode = await buildStep.resolver.astNodeFor(
      _fragmentFor(fieldElement.nonSynthetic),
      resolve: true,
    );
    if (fieldNode is! VariableDeclaration || fieldNode.initializer == null) {
      throw InvalidGenerationSourceError(
        'PathParam field `${fieldElement.displayName}` needs an initializer.',
        element: fieldElement,
      );
    }

    return _pathParameterMetadata(
      fieldNode.initializer!,
      key: fieldElement.displayName,
      memberName: fieldElement.displayName,
      element: element,
      evaluationContext: evaluationContext,
    );
  }

  Future<_RoutePathParameterSegmentMetadata> _pathParameterMetadata(
    Expression expression, {
    required String key,
    required String memberName,
    required Element element,
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _pathParameterMetadata(
          boundExpression,
          key: key,
          memberName: memberName,
          element: element,
          evaluationContext: evaluationContext,
        );
      }
    }

    Expression? codecExpression;
    if (normalizedExpression is MethodInvocation &&
        normalizedExpression.methodName.name == 'pathParam') {
      codecExpression = normalizedExpression.argumentList.arguments
          .whereType<Expression>()
          .firstOrNull;
    } else if (normalizedExpression is InstanceCreationExpression &&
        normalizedExpression.constructorName.type.toSource().split('<').first ==
            'PathParam') {
      codecExpression = normalizedExpression.argumentList.arguments
          .whereType<Expression>()
          .firstOrNull;
    }

    if (codecExpression == null) {
      throw InvalidGenerationSourceError(
        'Only pathParam(...) values are supported for generated path params.',
        element: element,
      );
    }

    if (evaluationContext != null &&
        _canResolveThroughContext(_unwrapExpression(codecExpression))) {
      final boundCodecExpression = await evaluationContext.resolveExpression(
        _unwrapExpression(codecExpression),
      );
      if (boundCodecExpression != null) {
        codecExpression = boundCodecExpression;
      }
    }

    return _RoutePathParameterSegmentMetadata(
      key: key,
      dartTypeSource: _codecValueTypeSourceForExpression(
        codecExpression,
        element,
      ),
      codecExpressionSource: _expressionSource(codecExpression),
      memberName: memberName,
    );
  }

  Future<Map<String, _RouteQueryParameterMetadata>> _queryParameterMapLiteral(
    Expression expression,
    Element element, {
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _queryParameterMapLiteral(
          boundExpression,
          element,
          evaluationContext: evaluationContext,
        );
      }
    }

    if (normalizedExpression is SetOrMapLiteral &&
        normalizedExpression.isMap == true) {
      final result = <String, _RouteQueryParameterMetadata>{};
      for (final item in normalizedExpression.elements) {
        final metadataByKey = await _queryParametersFromMapElement(
          item,
          elementForErrors: element,
          evaluationContext: evaluationContext,
        );
        for (final metadata in metadataByKey.values) {
          _registerQueryParameterMetadata(
            metadata,
            result,
            element: element,
          );
        }
      }
      return result;
    }

    final helperInvocation = await _helperInvocation(
      normalizedExpression,
      evaluationContext: evaluationContext,
    );
    if (helperInvocation != null) {
      return _queryParameterMapLiteral(
        helperInvocation.expression,
        element,
        evaluationContext: helperInvocation.context,
      );
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final targetExpression = await _declarationExpression(referencedElement);
      return _queryParameterMapLiteral(
        targetExpression,
        referencedElement,
        evaluationContext: evaluationContext,
      );
    }

    throw InvalidGenerationSourceError(
      'Only literal query parameter maps are supported.',
      element: element,
    );
  }

  Future<Map<String, _RouteQueryParameterMetadata>>
  _queryParametersFromMapElement(
    CollectionElement element, {
    required Element elementForErrors,
    _ExpressionContext? evaluationContext,
  }) async {
    switch (element) {
      case MapLiteralEntry():
        final key = _stringLiteral(element.key, elementForErrors);
        final metadata = await _queryParameterMetadata(
          element.value,
          key: key,
          element: elementForErrors,
          evaluationContext: evaluationContext,
        );
        return {metadata.key: metadata};
      case SpreadElement():
        return _queryParameterMapLiteral(
          element.expression,
          elementForErrors,
          evaluationContext: evaluationContext,
        );
      case IfElement():
        final result = <String, _RouteQueryParameterMetadata>{};
        for (final branchElement in [
          element.thenElement,
          if (element.elseElement != null) element.elseElement!,
        ]) {
          final branchMetadata = await _queryParametersFromMapElement(
            branchElement,
            elementForErrors: elementForErrors,
            evaluationContext: evaluationContext,
          );
          for (final metadata in branchMetadata.values) {
            _registerQueryParameterMetadata(
              metadata,
              result,
              element: elementForErrors,
            );
          }
        }
        return result;
      default:
        throw InvalidGenerationSourceError(
          'Unsupported element `${element.toSource()}` in queryParameters.',
          element: elementForErrors,
        );
    }
  }

  Future<_RouteQueryParameterMetadata> _queryParameterMetadata(
    Expression expression, {
    required String key,
    required Element element,
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _queryParameterMetadata(
          boundExpression,
          key: key,
          element: element,
          evaluationContext: evaluationContext,
        );
      }
    }
    if (normalizedExpression is! InstanceCreationExpression) {
      final helperInvocation = await _helperInvocation(
        normalizedExpression,
        evaluationContext: evaluationContext,
      );
      if (helperInvocation != null) {
        return _queryParameterMetadata(
          helperInvocation.expression,
          key: key,
          element: element,
          evaluationContext: helperInvocation.context,
        );
      }

      final referencedElement = _expressionElement(normalizedExpression);
      if (referencedElement != null) {
        final targetExpression = await _declarationExpression(
          referencedElement,
        );
        return _queryParameterMetadata(
          targetExpression,
          key: key,
          element: referencedElement,
          evaluationContext: evaluationContext,
        );
      }

      throw InvalidGenerationSourceError(
        'Only QueryParam values are supported in '
        'queryParameters.',
        element: element,
      );
    }

    final typeName = normalizedExpression.constructorName.type
        .toSource()
        .split('<')
        .first;
    if (typeName != 'QueryParam') {
      throw InvalidGenerationSourceError(
        'Only QueryParam values are supported in queryParameters.',
        element: element,
      );
    }

    final keyExpression = _namedArgumentExpression(
      normalizedExpression.argumentList.arguments,
      'key',
    );
    final codecExpression =
        _namedArgumentExpression(
          normalizedExpression.argumentList.arguments,
          'codec',
        ) ??
        normalizedExpression.argumentList.arguments
            .whereType<Expression>()
            .skip(keyExpression == null ? 0 : 1)
            .firstOrNull;
    final optionalExpression = _namedArgumentExpression(
      normalizedExpression.argumentList.arguments,
      'optional',
    );
    if (codecExpression == null) {
      throw InvalidGenerationSourceError(
        'QueryParam requires a codec.',
        element: element,
      );
    }

    var resolvedCodecExpression = codecExpression;
    if (evaluationContext != null &&
        _canResolveThroughContext(_unwrapExpression(codecExpression))) {
      final boundCodecExpression = await evaluationContext.resolveExpression(
        _unwrapExpression(codecExpression),
      );
      if (boundCodecExpression != null) {
        resolvedCodecExpression = boundCodecExpression;
      }
    }

    return _RouteQueryParameterMetadata(
      key: key,
      dartTypeSource: _codecValueTypeSourceForExpression(
        resolvedCodecExpression,
        element,
      ),
      codecExpressionSource: _expressionSource(resolvedCodecExpression),
      optional:
          optionalExpression != null &&
          await _boolExpression(
            optionalExpression,
            element,
            evaluationContext: evaluationContext,
          ),
    );
  }

  void _registerQueryParameterMetadata(
    _RouteQueryParameterMetadata metadata,
    Map<String, _RouteQueryParameterMetadata> target, {
    required Element element,
  }) {
    final existing = target[metadata.key];
    if (existing == null) {
      target[metadata.key] = metadata;
      return;
    }

    if (existing.dartTypeSource == metadata.dartTypeSource &&
        existing.codecExpressionSource == metadata.codecExpressionSource &&
        existing.optional == metadata.optional) {
      return;
    }

    throw InvalidGenerationSourceError(
      'Duplicate query parameter key `${metadata.key}` with conflicting '
      'definitions.',
      element: element,
    );
  }

  String _stringLiteral(Expression expression, Element element) {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is StringLiteral) {
      return normalizedExpression.stringValue ?? '';
    }
    if (normalizedExpression is AdjacentStrings) {
      return normalizedExpression.strings
          .map((string) => _stringLiteral(string, element))
          .join();
    }
    final constantValue = normalizedExpression.computeConstantValue();
    final stringValue = constantValue?.value?.toStringValue();
    if (stringValue != null) {
      return stringValue;
    }

    throw InvalidGenerationSourceError(
      'Only constant strings are supported in generated route metadata.',
      element: element,
    );
  }

  Future<bool> _boolExpression(
    Expression expression,
    Element element, {
    _ExpressionContext? evaluationContext,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (evaluationContext != null &&
        _canResolveThroughContext(normalizedExpression)) {
      final boundExpression = await evaluationContext.resolveExpression(
        normalizedExpression,
      );
      if (boundExpression != null) {
        return _boolExpression(
          boundExpression,
          element,
          evaluationContext: evaluationContext,
        );
      }
    }
    if (normalizedExpression is BooleanLiteral) {
      return normalizedExpression.value;
    }

    final constantValue = normalizedExpression.computeConstantValue();
    final boolValue = constantValue?.value?.toBoolValue();
    if (boolValue != null) {
      return boolValue;
    }

    throw InvalidGenerationSourceError(
      'Only constant booleans are supported in generated route metadata.',
      element: element,
    );
  }

  String _codecValueTypeSourceForExpression(
    Expression codecExpression,
    Element element,
  ) {
    final valueType = _codecValueType(codecExpression.staticType, element);
    if (valueType is TypeParameterType &&
        codecExpression is InstanceCreationExpression) {
      final inferredValueType = _inferCodecValueTypeFromArguments(
        codecExpression,
      );
      if (inferredValueType != null) {
        return inferredValueType.getDisplayString();
      }
    }

    return valueType.getDisplayString();
  }

  DartType _codecValueType(DartType? codecType, Element element) {
    if (codecType is! InterfaceType) {
      throw InvalidGenerationSourceError(
        'Route parameter codecs must have a concrete RouteParamCodec<T> type.',
        element: element,
      );
    }

    final routeCodecType = _supertypeNamed(codecType, 'RouteParamCodec');
    if (routeCodecType == null || routeCodecType.typeArguments.length != 1) {
      throw InvalidGenerationSourceError(
        'Route parameter codecs must extend RouteParamCodec<T>.',
        element: element,
      );
    }

    return routeCodecType.typeArguments.single;
  }

  DartType? _inferCodecValueTypeFromArguments(
    InstanceCreationExpression expression,
  ) {
    final codecTypeName = expression.constructorName.type
        .toSource()
        .split('<')
        .first;
    if (codecTypeName == 'EnumNameRouteParamCodec') {
      final valuesExpression = expression.argumentList.arguments
          .whereType<Expression>()
          .firstOrNull;
      if (valuesExpression == null) {
        return null;
      }

      final valuesType = valuesExpression.staticType;
      if (valuesType is! InterfaceType) {
        return null;
      }

      if (valuesType.typeArguments.length == 1) {
        return valuesType.typeArguments.single;
      }

      final iterableType = _supertypeNamed(valuesType, 'Iterable');
      if (iterableType != null && iterableType.typeArguments.length == 1) {
        return iterableType.typeArguments.single;
      }
    }

    return null;
  }

  InterfaceType? _supertypeNamed(InterfaceType type, String name) {
    InterfaceType? current = type;
    while (current != null) {
      if (current.element.name == name) {
        return current;
      }
      current = current.element.supertype;
    }
    return null;
  }

  bool _isQueryParamType(DartType? type) {
    if (type is! InterfaceType) {
      return false;
    }
    return _supertypeNamed(type, 'QueryParam') != null;
  }

  bool _isPathParamType(DartType? type) {
    if (type is! InterfaceType) {
      return false;
    }
    return _supertypeNamed(type, 'PathParam') != null;
  }

  String _expressionSource(Expression expression) {
    return _unwrapExpression(expression).toSource();
  }

  Expression? _namedArgumentExpression(
    List<Expression> arguments,
    String name,
  ) {
    for (final argument in arguments) {
      if (argument is NamedExpression && argument.name.label.name == name) {
        return argument.expression;
      }
    }
    return null;
  }

  Element? _expressionElement(
    Expression expression, {
    bool allowParameterizedExecutable = false,
  }) {
    var element = switch (expression) {
      MethodInvocation() => expression.methodName.element,
      FunctionExpressionInvocation() => expression.element,
      SimpleIdentifier() => expression.element,
      PrefixedIdentifier() => expression.identifier.element,
      PropertyAccess() => expression.propertyName.element,
      _ => null,
    };

    if (element is PropertyAccessorElement && element.isSynthetic) {
      element = element.variable;
    }

    if (element is ExecutableElement) {
      _validateHelperElement(element);
      if (!allowParameterizedExecutable &&
          element.formalParameters.isNotEmpty) {
        throw InvalidGenerationSourceError(
          'Helper functions used in generated route trees must not have '
          'parameters.',
          element: element,
        );
      }
      return element;
    }
    if (element is PropertyInducingElement) {
      _validateHelperElement(element);
      return element;
    }
    return null;
  }

  PropertyInducingElement? _fieldElementForExpression(Expression expression) {
    Element? element = switch (expression) {
      SimpleIdentifier() => expression.element,
      PrefixedIdentifier() => expression.identifier.element,
      PropertyAccess() => expression.propertyName.element,
      _ => null,
    };

    if (element is PropertyAccessorElement && element.isSynthetic) {
      element = element.variable;
    }

    return element is PropertyInducingElement ? element : null;
  }

  ExecutableElement? _invokedExecutableElement(Expression expression) {
    final element = _expressionElement(
      expression,
      allowParameterizedExecutable: true,
    );
    return element is ExecutableElement ? element : null;
  }

  List<Expression> _invocationArguments(Expression expression) {
    return switch (expression) {
      MethodInvocation() => expression.argumentList.arguments,
      FunctionExpressionInvocation() => expression.argumentList.arguments,
      _ => const <Expression>[],
    };
  }

  Element _normalizeDeclarationElement(Element element) {
    if (element is PropertyAccessorElement && element.isSynthetic) {
      return element.variable;
    }
    return element;
  }

  void _validateHelperElement(Element element) {
    final isTopLevel = element.enclosingElement is LibraryElement;

    final isSupported = switch (element) {
      TopLevelFunctionElement() => true,
      MethodElement() => element.isStatic,
      GetterElement() => isTopLevel || element.isStatic,
      ExecutableElement() => true,
      PropertyInducingElement() => isTopLevel || element.isStatic,
      _ => false,
    };

    if (!isSupported) {
      throw InvalidGenerationSourceError(
        'Helper declarations used in generated route trees must be top-level '
        'or static.',
        element: element,
      );
    }
  }

  void _validateInvokedHelperElement(ExecutableElement element) {
    _validateHelperElement(element);
  }

  Expression _unwrapExpression(Expression expression) {
    var current = expression;
    while (current is ParenthesizedExpression) {
      current = current.expression;
    }
    return current;
  }

  bool _canResolveThroughContext(Expression expression) {
    return expression is SimpleIdentifier ||
        expression is PrefixedIdentifier ||
        expression is PropertyAccess;
  }

  bool _isRouteNodeClass(InterfaceElement classElement) {
    InterfaceType? current = classElement.thisType;
    while (current != null) {
      if (current.element.name == 'RouteNode') {
        return true;
      }
      current = current.element.supertype;
    }
    return false;
  }

  bool _isLocationClass(InterfaceElement classElement) {
    InterfaceType? current = classElement.thisType;
    while (current != null) {
      if (current.element.name == 'Location') {
        return true;
      }
      current = current.element.supertype;
    }
    return false;
  }
}

abstract class _ExpressionContext {
  Future<Expression?> resolveExpression(Expression expression);

  Future<Expression?> resolveIdExpression(Expression expression);
}

class _ResolvedHelperInvocation {
  final Expression expression;
  final _ExpressionContext context;

  const _ResolvedHelperInvocation({
    required this.expression,
    required this.context,
  });
}

class _InstanceStringContext implements _ExpressionContext {
  final BuildStep buildStep;
  final Element rootElement;
  final InterfaceElement classElement;
  final ConstructorElement constructor;
  final ConstructorDeclaration constructorNode;
  final Map<String, _BoundStringExpression> parameterBindings;
  final _ExpressionContext? parentContext;

  _InstanceStringContext({
    required this.buildStep,
    required this.rootElement,
    required this.classElement,
    required this.constructor,
    required this.constructorNode,
    required this.parameterBindings,
    required this.parentContext,
  });

  static Future<_InstanceStringContext> fromCreation({
    required BuildStep buildStep,
    required InstanceCreationExpression creation,
    required Element rootElement,
    required _ExpressionContext? parentContext,
  }) async {
    final constructor = creation.constructorName.element;
    final classElement = constructor?.enclosingElement;
    if (constructor == null || classElement is! InterfaceElement) {
      throw InvalidGenerationSourceError(
        'Unable to resolve constructor metadata for `${creation.toSource()}`.',
        element: rootElement,
      );
    }

    final constructorNode = await _constructorDeclaration(
      buildStep: buildStep,
      classElement: classElement,
      constructor: constructor,
    );
    if (constructorNode == null) {
      throw InvalidGenerationSourceError(
        'Unable to read the constructor source for `${classElement.name}`.',
        element: constructor,
      );
    }

    final context = _InstanceStringContext(
      buildStep: buildStep,
      rootElement: rootElement,
      classElement: classElement,
      constructor: constructor,
      constructorNode: constructorNode,
      parameterBindings: {},
      parentContext: parentContext,
    );
    context.parameterBindings.addAll(
      context._bindArguments(
        parameters: constructorNode.parameters,
        arguments: creation.argumentList.arguments,
      ),
    );
    return context;
  }

  Future<String> evaluateGetter(PropertyAccessorElement getter) async {
    final node = await buildStep.resolver.astNodeFor(
      getter.firstFragment,
      resolve: true,
    );
    if (node is! MethodDeclaration && node is! FunctionDeclaration) {
      throw InvalidGenerationSourceError(
        'Unable to resolve getter `${getter.displayName}`.',
        element: getter,
      );
    }

    final body = switch (node) {
      MethodDeclaration() => node.body,
      FunctionDeclaration() => node.functionExpression.body,
      _ => throw StateError('Unreachable'),
    };

    final expression = _bodyExpression(body, getter);
    return _evaluateStringExpression(expression);
  }

  Future<Expression?> locationChildrenExpression() {
    return _fieldExpression('children');
  }

  @override
  Future<Expression?> resolveExpression(Expression expression) {
    return _resolveExpression(expression, <String>{});
  }

  Future<Expression?> _resolveExpression(
    Expression expression,
    Set<String> visited,
  ) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (!_markVisited(visited, 'expr', normalizedExpression)) {
      return null;
    }
    if (normalizedExpression is SimpleIdentifier) {
      final binding = parameterBindings[normalizedExpression.name];
      if (binding != null) {
        final boundExpression = _unwrapExpression(binding.expression);
        if (!_isSameSimpleIdentifier(boundExpression, normalizedExpression)) {
          if (_canResolveFurther(boundExpression)) {
            final resolvedExpression = await _resolveExpression(
              boundExpression,
              visited,
            );
            if (resolvedExpression != null) {
              return resolvedExpression;
            }
          }
          return binding.expression;
        }
      }

      final fieldExpression = await _fieldExpression(normalizedExpression.name);
      if (fieldExpression != null &&
          !_isSameSimpleIdentifier(fieldExpression, normalizedExpression)) {
        if (_canResolveFurther(fieldExpression)) {
          final resolvedExpression = await _resolveExpression(
            fieldExpression,
            visited,
          );
          if (resolvedExpression != null) {
            return resolvedExpression;
          }
        }
        return fieldExpression;
      }
    }
    return _resolveParentExpression(
      parentContext,
      normalizedExpression,
      visited,
    );
  }

  @override
  Future<Expression?> resolveIdExpression(Expression expression) {
    return _resolveIdExpression(expression, <String>{});
  }

  Future<Expression?> _resolveIdExpression(
    Expression expression,
    Set<String> visited,
  ) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (!_markVisited(visited, 'id', normalizedExpression)) {
      return null;
    }
    if (normalizedExpression is NullLiteral) {
      return null;
    }
    if (normalizedExpression is SimpleIdentifier) {
      final parameterBinding = parameterBindings[normalizedExpression.name];
      if (parameterBinding != null) {
        final boundExpression = _unwrapExpression(parameterBinding.expression);
        if (!_isSameSimpleIdentifier(boundExpression, normalizedExpression)) {
          return _resolveIdExpression(parameterBinding.expression, visited);
        }
      }
      final parentExpression = await _resolveParentExpression(
        parentContext,
        normalizedExpression,
        visited,
      );
      if (parentExpression != null) {
        return _resolveParentIdExpression(
          parentContext,
          parentExpression,
          visited,
        );
      }
    }
    if (normalizedExpression is ConditionalExpression) {
      if (!_isNullableIdCondition(normalizedExpression.condition) &&
          parentContext != null) {
        return _resolveParentIdExpression(
          parentContext,
          normalizedExpression,
          visited,
        );
      }
      final conditionResult = await _evaluateNullableIdCondition(
        normalizedExpression.condition,
      );
      final branch = conditionResult
          ? normalizedExpression.thenExpression
          : normalizedExpression.elseExpression;
      return _resolveIdExpression(branch, visited);
    }
    return normalizedExpression;
  }

  Map<String, _BoundStringExpression> _bindArguments({
    required FormalParameterList parameters,
    required List<Expression> arguments,
  }) {
    final positionalArguments = <Expression>[];
    final namedArguments = <String, Expression>{};
    for (final argument in arguments) {
      if (argument is NamedExpression) {
        namedArguments[argument.name.label.name] = argument.expression;
      } else {
        positionalArguments.add(argument);
      }
    }

    final bindings = <String, _BoundStringExpression>{};
    var positionalIndex = 0;
    for (final parameter in parameters.parameters) {
      final parameterName = _formalParameterName(parameter);
      if (parameterName == null) {
        continue;
      }

      Expression? argument;
      if (parameter.isNamed) {
        argument = namedArguments[parameterName];
        if (argument == null &&
            parameter is DefaultFormalParameter &&
            parameter.defaultValue != null) {
          argument = parameter.defaultValue;
        }
      } else if (positionalIndex < positionalArguments.length) {
        argument = positionalArguments[positionalIndex++];
      } else if (parameter is DefaultFormalParameter &&
          parameter.defaultValue != null) {
        argument = parameter.defaultValue;
      }

      if (argument != null) {
        bindings[parameterName] = _BoundStringExpression(
          expression: argument,
          context: this,
        );
      }
    }

    return bindings;
  }

  Future<_InstanceStringContext?> _superContext() async {
    final supertype = classElement.supertype;
    if (supertype == null) {
      return null;
    }

    final superInvocation = constructorNode.initializers
        .whereType<SuperConstructorInvocation>()
        .firstOrNull;
    final superConstructor =
        superInvocation?.element ?? supertype.element.unnamedConstructor;
    if (superConstructor == null) {
      return null;
    }

    final superClassElement = supertype.element;
    final superConstructorNode = await _constructorDeclaration(
      buildStep: buildStep,
      classElement: superClassElement,
      constructor: superConstructor,
    );
    if (superConstructorNode == null) {
      throw InvalidGenerationSourceError(
        'Unable to read the constructor source for `${supertype.element.name}`.',
        element: superConstructor,
      );
    }

    final context = _InstanceStringContext(
      buildStep: buildStep,
      rootElement: rootElement,
      classElement: supertype.element,
      constructor: superConstructor,
      constructorNode: superConstructorNode,
      parameterBindings: {},
      parentContext: parentContext,
    );
    context.parameterBindings.addAll(
      context._bindArguments(
        parameters: superConstructorNode.parameters,
        arguments: superInvocation?.argumentList.arguments ?? const [],
      ),
    );
    return context;
  }

  Future<String> _evaluateStringExpression(Expression expression) async {
    final normalizedExpression = _unwrapExpression(expression);

    if (normalizedExpression is StringLiteral) {
      return normalizedExpression.stringValue ?? '';
    }
    if (normalizedExpression is AdjacentStrings) {
      final parts = <String>[];
      for (final string in normalizedExpression.strings) {
        parts.add(await _evaluateStringExpression(string));
      }
      return parts.join();
    }

    if (normalizedExpression is SimpleIdentifier) {
      final parameterBinding = parameterBindings[normalizedExpression.name];
      if (parameterBinding != null) {
        return parameterBinding.evaluate();
      }
      return _evaluateField(normalizedExpression.name);
    }

    if (normalizedExpression is PrefixedIdentifier &&
        normalizedExpression.prefix.name == 'this') {
      return _evaluateField(normalizedExpression.identifier.name);
    }

    if (normalizedExpression is PropertyAccess &&
        normalizedExpression.realTarget is ThisExpression) {
      return _evaluateField(normalizedExpression.propertyName.name);
    }

    throw InvalidGenerationSourceError(
      'Only literal strings, constructor arguments, and fields backed by '
      'constructor arguments are supported in generated paths.',
      element: constructor,
    );
  }

  Future<bool> _evaluateNullableIdCondition(Expression expression) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is! BinaryExpression) {
      throw InvalidGenerationSourceError(
        'Only `id != null ? ... : null` style conditional ids are supported.',
        element: constructor,
      );
    }

    final operator = normalizedExpression.operator.lexeme;
    if (operator != '!=' && operator != '==') {
      throw InvalidGenerationSourceError(
        'Only `id != null ? ... : null` style conditional ids are supported.',
        element: constructor,
      );
    }

    final left = normalizedExpression.leftOperand;
    final right = normalizedExpression.rightOperand;
    if (left is NullLiteral) {
      final targetIsNull = await _evaluateIsNull(right);
      return operator == '!=' ? !targetIsNull : targetIsNull;
    }
    if (right is NullLiteral) {
      final targetIsNull = await _evaluateIsNull(left);
      return operator == '!=' ? !targetIsNull : targetIsNull;
    }

    throw InvalidGenerationSourceError(
      'Only `id != null ? ... : null` style conditional ids are supported.',
      element: constructor,
    );
  }

  bool _isNullableIdCondition(Expression expression) {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is! BinaryExpression) {
      return false;
    }

    final operator = normalizedExpression.operator.lexeme;
    if (operator != '!=' && operator != '==') {
      return false;
    }

    return normalizedExpression.leftOperand is NullLiteral ||
        normalizedExpression.rightOperand is NullLiteral;
  }

  Future<bool> _evaluateIsNull(Expression expression) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is NullLiteral) {
      return true;
    }
    if (normalizedExpression is SimpleIdentifier) {
      return _evaluateNamedValueIsNull(normalizedExpression.name);
    }
    if (normalizedExpression is PrefixedIdentifier &&
        normalizedExpression.prefix.name == 'this') {
      return _evaluateFieldIsNull(normalizedExpression.identifier.name);
    }
    if (normalizedExpression is PropertyAccess &&
        normalizedExpression.realTarget is ThisExpression) {
      return _evaluateFieldIsNull(normalizedExpression.propertyName.name);
    }

    final constantValue = normalizedExpression.computeConstantValue();
    final value = constantValue?.value;
    if (value != null) {
      return value.isNull;
    }

    return false;
  }

  Future<String> _evaluateField(String name) async {
    final field = classElement.getField(name);
    if (field != null) {
      final fieldInitializer = constructorNode.initializers
          .whereType<ConstructorFieldInitializer>()
          .firstWhereOrNull(
            (initializer) => initializer.fieldName.name == name,
          );
      if (fieldInitializer != null) {
        return _evaluateStringExpression(fieldInitializer.expression);
      }

      final fieldNode = await buildStep.resolver.astNodeFor(
        _fragmentFor(field.nonSynthetic),
        resolve: true,
      );
      if (fieldNode is VariableDeclaration && fieldNode.initializer != null) {
        return _evaluateStringExpression(fieldNode.initializer!);
      }
    }

    final superContext = await _superContext();
    if (superContext != null) {
      return superContext._evaluateField(name);
    }

    throw InvalidGenerationSourceError(
      'Unable to resolve the field `$name` in `${classElement.name}`.',
      element: classElement,
    );
  }

  Future<Expression?> _fieldExpression(String name) async {
    final field = classElement.getField(name);
    if (field != null) {
      final fieldFormalParameter = constructorNode.parameters.parameters
          .firstWhereOrNull(
            (parameter) => _formalParameterName(parameter) == name,
          );
      if (fieldFormalParameter != null &&
          _unwrapFormalParameter(fieldFormalParameter)
              is FieldFormalParameter) {
        final binding = parameterBindings[name];
        if (binding != null) {
          return binding.expression;
        }
        if (fieldFormalParameter is DefaultFormalParameter &&
            fieldFormalParameter.defaultValue != null) {
          return fieldFormalParameter.defaultValue;
        }
      }

      final fieldInitializer = constructorNode.initializers
          .whereType<ConstructorFieldInitializer>()
          .firstWhereOrNull(
            (initializer) => initializer.fieldName.name == name,
          );
      if (fieldInitializer != null) {
        return fieldInitializer.expression;
      }

      final fieldNode = await buildStep.resolver.astNodeFor(
        _fragmentFor(field.nonSynthetic),
        resolve: true,
      );
      if (fieldNode is VariableDeclaration && fieldNode.initializer != null) {
        return fieldNode.initializer;
      }
    }

    final getter = classElement.lookUpGetter(
      name: name,
      library: classElement.library,
    );
    if (getter != null &&
        getter.enclosingElement != classElement.supertype?.element) {
      final getterNode = await buildStep.resolver.astNodeFor(
        getter.firstFragment,
        resolve: true,
      );
      if (getterNode is MethodDeclaration ||
          getterNode is FunctionDeclaration) {
        final body = switch (getterNode) {
          MethodDeclaration() => getterNode.body,
          FunctionDeclaration() => getterNode.functionExpression.body,
          _ => throw StateError('Unreachable'),
        };
        return _bodyExpression(body, getter);
      }
    }

    return null;
  }

  Future<bool> _evaluateNamedValueIsNull(String name) async {
    final parameterBinding = parameterBindings[name];
    if (parameterBinding != null) {
      return parameterBinding.isNull();
    }

    final parameter = constructorNode.parameters.parameters.firstWhereOrNull((
      parameter,
    ) {
      return _formalParameterName(parameter) == name;
    });
    if (parameter != null) {
      if (parameter is DefaultFormalParameter) {
        final defaultValue = parameter.defaultValue;
        if (defaultValue == null) {
          return true;
        }
        return _evaluateIsNull(defaultValue);
      }
      return false;
    }

    return _evaluateFieldIsNull(name);
  }

  Future<bool> _evaluateFieldIsNull(String name) async {
    final field = classElement.getField(name);
    if (field != null) {
      final fieldInitializer = constructorNode.initializers
          .whereType<ConstructorFieldInitializer>()
          .firstWhereOrNull(
            (initializer) => initializer.fieldName.name == name,
          );
      if (fieldInitializer != null) {
        return _evaluateIsNull(fieldInitializer.expression);
      }

      final fieldNode = await buildStep.resolver.astNodeFor(
        _fragmentFor(field.nonSynthetic),
        resolve: true,
      );
      if (fieldNode is VariableDeclaration && fieldNode.initializer != null) {
        return _evaluateIsNull(fieldNode.initializer!);
      }
    }

    final superContext = await _superContext();
    if (superContext != null) {
      return superContext._evaluateNamedValueIsNull(name);
    }

    throw InvalidGenerationSourceError(
      'Unable to resolve the field `$name` in `${classElement.name}`.',
      element: classElement,
    );
  }

  Expression _bodyExpression(FunctionBody body, Element element) {
    if (body is ExpressionFunctionBody) {
      return body.expression;
    }
    if (body is BlockFunctionBody) {
      final returnExpression = body.block.statements
          .whereType<ReturnStatement>()
          .map((statement) => statement.expression)
          .nonNulls
          .firstOrNull;
      if (returnExpression != null) {
        return returnExpression;
      }
    }

    throw InvalidGenerationSourceError(
      'Only simple getter bodies are supported for generated paths.',
      element: element,
    );
  }

  Expression _unwrapExpression(Expression expression) {
    var current = expression;
    while (current is ParenthesizedExpression) {
      current = current.expression;
    }
    return current;
  }

  bool _isSameSimpleIdentifier(Expression left, Expression right) {
    return left is SimpleIdentifier &&
        right is SimpleIdentifier &&
        left.name == right.name;
  }

  bool _canResolveFurther(Expression expression) {
    return expression is SimpleIdentifier ||
        expression is PrefixedIdentifier ||
        expression is PropertyAccess;
  }

  bool _markVisited(
    Set<String> visited,
    String kind,
    Expression expression,
  ) {
    final key = switch (expression) {
      SimpleIdentifier() =>
        '$kind:${identityHashCode(this)}:simple:${expression.name}',
      _ =>
        '$kind:${identityHashCode(this)}:${expression.runtimeType}:${expression.offset}:${expression.length}',
    };
    return visited.add(key);
  }

  Future<Expression?> _resolveParentExpression(
    _ExpressionContext? context,
    Expression expression,
    Set<String> visited,
  ) {
    if (context case _InstanceStringContext()) {
      return context._resolveExpression(expression, visited);
    }
    if (context case _FunctionExpressionContext()) {
      return context._resolveExpression(expression, visited);
    }
    return context?.resolveExpression(expression) ?? Future.value(null);
  }

  Future<Expression?> _resolveParentIdExpression(
    _ExpressionContext? context,
    Expression expression,
    Set<String> visited,
  ) {
    if (context case _InstanceStringContext()) {
      return context._resolveIdExpression(expression, visited);
    }
    if (context case _FunctionExpressionContext()) {
      return context._resolveIdExpression(expression, visited);
    }
    return context?.resolveIdExpression(expression) ?? Future.value(null);
  }
}

class _FunctionExpressionContext implements _ExpressionContext {
  final Element rootElement;
  final ExecutableElement executable;
  final Map<String, Expression> parameterBindings;
  final _ExpressionContext? parentContext;

  _FunctionExpressionContext({
    required this.rootElement,
    required this.executable,
    required this.parameterBindings,
    required this.parentContext,
  });

  static Future<_FunctionExpressionContext> fromInvocation({
    required BuildStep buildStep,
    required Element rootElement,
    required ExecutableElement executable,
    required List<Expression> arguments,
    required _ExpressionContext? parentContext,
  }) async {
    final node = await buildStep.resolver.astNodeFor(
      _fragmentFor(executable),
      resolve: true,
    );

    final parameters = switch (node) {
      FunctionDeclaration() => node.functionExpression.parameters,
      FunctionDeclarationStatement() =>
        node.functionDeclaration.functionExpression.parameters,
      MethodDeclaration() => node.parameters,
      _ => throw InvalidGenerationSourceError(
        'Unable to resolve helper function `${executable.displayName}`.',
        element: executable,
      ),
    };

    if (parameters == null) {
      throw InvalidGenerationSourceError(
        'Unable to resolve helper function `${executable.displayName}`.',
        element: executable,
      );
    }

    return _FunctionExpressionContext(
      rootElement: rootElement,
      executable: executable,
      parameterBindings: _bindArguments(
        parameters: parameters,
        arguments: arguments,
      ),
      parentContext: parentContext,
    );
  }

  @override
  Future<Expression?> resolveExpression(Expression expression) {
    return _resolveExpression(expression, <String>{});
  }

  Future<Expression?> _resolveExpression(
    Expression expression,
    Set<String> visited,
  ) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (!_markVisited(visited, 'expr', normalizedExpression)) {
      return null;
    }
    if (normalizedExpression is SimpleIdentifier) {
      final boundExpression = parameterBindings[normalizedExpression.name];
      if (boundExpression != null) {
        final normalizedBoundExpression = _unwrapExpression(boundExpression);
        if (!_isSameSimpleIdentifier(
          normalizedBoundExpression,
          normalizedExpression,
        )) {
          if (_canResolveFurther(normalizedBoundExpression)) {
            final resolvedExpression = await _resolveExpression(
              normalizedBoundExpression,
              visited,
            );
            if (resolvedExpression != null) {
              return resolvedExpression;
            }
          }
          return boundExpression;
        }
      }
    }
    return _resolveParentExpression(
      parentContext,
      normalizedExpression,
      visited,
    );
  }

  @override
  Future<Expression?> resolveIdExpression(Expression expression) {
    return _resolveIdExpression(expression, <String>{});
  }

  Future<Expression?> _resolveIdExpression(
    Expression expression,
    Set<String> visited,
  ) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (!_markVisited(visited, 'id', normalizedExpression)) {
      return null;
    }
    if (normalizedExpression is NullLiteral) {
      return null;
    }
    if (normalizedExpression is SimpleIdentifier) {
      final boundExpression = parameterBindings[normalizedExpression.name];
      if (boundExpression != null) {
        final normalizedBoundExpression = _unwrapExpression(boundExpression);
        if (!_isSameSimpleIdentifier(
          normalizedBoundExpression,
          normalizedExpression,
        )) {
          return _resolveIdExpression(boundExpression, visited);
        }
      }
      final parentExpression = await _resolveParentExpression(
        parentContext,
        normalizedExpression,
        visited,
      );
      if (parentExpression != null) {
        return _resolveIdExpression(parentExpression, visited);
      }
    }
    if (normalizedExpression is ConditionalExpression) {
      final conditionResult = await _evaluateCondition(
        normalizedExpression.condition,
      );
      return _resolveIdExpression(
        conditionResult
            ? normalizedExpression.thenExpression
            : normalizedExpression.elseExpression,
        visited,
      );
    }
    return normalizedExpression;
  }

  static Map<String, Expression> _bindArguments({
    required FormalParameterList parameters,
    required List<Expression> arguments,
  }) {
    final positionalArguments = <Expression>[];
    final namedArguments = <String, Expression>{};
    for (final argument in arguments) {
      if (argument is NamedExpression) {
        namedArguments[argument.name.label.name] = argument.expression;
      } else {
        positionalArguments.add(argument);
      }
    }

    final bindings = <String, Expression>{};
    var positionalIndex = 0;
    for (final parameter in parameters.parameters) {
      final parameterName = _formalParameterName(parameter);
      if (parameterName == null) {
        continue;
      }

      Expression? argument;
      if (parameter.isNamed) {
        argument = namedArguments[parameterName];
        if (argument == null &&
            parameter is DefaultFormalParameter &&
            parameter.defaultValue != null) {
          argument = parameter.defaultValue;
        }
      } else if (positionalIndex < positionalArguments.length) {
        argument = positionalArguments[positionalIndex++];
      } else if (parameter is DefaultFormalParameter &&
          parameter.defaultValue != null) {
        argument = parameter.defaultValue;
      }

      if (argument != null) {
        bindings[parameterName] = argument;
      }
    }

    return bindings;
  }

  Future<bool> _evaluateCondition(Expression expression) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is BooleanLiteral) {
      return normalizedExpression.value;
    }
    if (normalizedExpression is PrefixExpression &&
        normalizedExpression.operator.lexeme == '!') {
      return !(await _evaluateCondition(normalizedExpression.operand));
    }
    if (normalizedExpression is SimpleIdentifier) {
      final boundExpression = parameterBindings[normalizedExpression.name];
      if (boundExpression != null) {
        return _evaluateCondition(boundExpression);
      }
      final parentExpression = await parentContext?.resolveExpression(
        normalizedExpression,
      );
      if (parentExpression != null) {
        return _evaluateCondition(parentExpression);
      }
    }

    final constantValue = normalizedExpression.computeConstantValue();
    final boolValue = constantValue?.value?.toBoolValue();
    if (boolValue != null) {
      return boolValue;
    }

    throw InvalidGenerationSourceError(
      'Only statically known boolean helper arguments can be used in '
      'generated route ids.',
      element: executable,
    );
  }

  Expression _unwrapExpression(Expression expression) {
    var current = expression;
    while (current is ParenthesizedExpression) {
      current = current.expression;
    }
    return current;
  }

  bool _isSameSimpleIdentifier(Expression left, Expression right) {
    return left is SimpleIdentifier &&
        right is SimpleIdentifier &&
        left.name == right.name;
  }

  bool _canResolveFurther(Expression expression) {
    return expression is SimpleIdentifier ||
        expression is PrefixedIdentifier ||
        expression is PropertyAccess;
  }

  bool _markVisited(
    Set<String> visited,
    String kind,
    Expression expression,
  ) {
    final key = switch (expression) {
      SimpleIdentifier() =>
        '$kind:${identityHashCode(this)}:simple:${expression.name}',
      _ =>
        '$kind:${identityHashCode(this)}:${expression.runtimeType}:${expression.offset}:${expression.length}',
    };
    return visited.add(key);
  }

  Future<Expression?> _resolveParentExpression(
    _ExpressionContext? context,
    Expression expression,
    Set<String> visited,
  ) {
    if (context case _InstanceStringContext()) {
      return context._resolveExpression(expression, visited);
    }
    if (context case _FunctionExpressionContext()) {
      return context._resolveExpression(expression, visited);
    }
    return context?.resolveExpression(expression) ?? Future.value(null);
  }
}

Fragment _fragmentFor(Element element) => element.firstFragment;

FormalParameter _unwrapFormalParameter(FormalParameter parameter) {
  var current = parameter;
  while (current is DefaultFormalParameter) {
    current = current.parameter;
  }
  return current;
}

String? _formalParameterName(FormalParameter parameter) {
  final unwrapped = _unwrapFormalParameter(parameter);
  final elementName = unwrapped.declaredFragment?.element.name;
  if (elementName != null) {
    return elementName;
  }

  return switch (unwrapped) {
    SimpleFormalParameter() => unwrapped.name?.lexeme,
    FieldFormalParameter() => unwrapped.name.lexeme,
    SuperFormalParameter() => unwrapped.name.lexeme,
    FunctionTypedFormalParameter() => unwrapped.name.lexeme,
    _ => null,
  };
}

Future<ConstructorDeclaration?> _constructorDeclaration({
  required BuildStep buildStep,
  required InterfaceElement classElement,
  required ConstructorElement constructor,
}) async {
  final classNode = await buildStep.resolver.astNodeFor(
    classElement.firstFragment,
    resolve: true,
  );
  if (classNode is! ClassDeclaration) {
    return null;
  }

  final constructorName = constructor.name;
  return classNode.members.whereType<ConstructorDeclaration>().firstWhereOrNull(
    (member) {
      final memberElement = member.declaredFragment?.element;
      if (identical(memberElement, constructor)) {
        return true;
      }
      return (member.name?.lexeme ?? '') == constructorName;
    },
  );
}

class _BoundStringExpression {
  final Expression expression;
  final _InstanceStringContext context;

  const _BoundStringExpression({
    required this.expression,
    required this.context,
  });

  Future<String> evaluate() => context._evaluateStringExpression(expression);

  Future<bool> isNull() => context._evaluateIsNull(expression);
}

class _RouteNode {
  final String? idExpression;
  final bool isLocation;
  final InterfaceElement locationClassElement;
  final String locationTypeSource;
  final List<_PathSegmentMetadata> pathSegments;
  final Map<String, _RouteQueryParameterMetadata> queryParameters;
  final List<_RouteNode> children;

  const _RouteNode({
    required this.idExpression,
    required this.isLocation,
    required this.locationClassElement,
    required this.locationTypeSource,
    required this.pathSegments,
    required this.queryParameters,
    required this.children,
  });
}

class _GeneratedRouteMethod {
  final String idTypeSource;
  final String name;
  final String targetClassName;
  final String? idExpression;
  final String? childLocationTypeSource;
  final List<_GeneratedPathWrite> pathWrites;
  final Map<String, _GeneratedRouteParameter> pathParameters;
  final Map<String, _GeneratedRouteParameter> queryParameters;

  const _GeneratedRouteMethod._({
    required this.idTypeSource,
    required this.name,
    required this.targetClassName,
    required this.idExpression,
    required this.childLocationTypeSource,
    required this.pathWrites,
    required this.pathParameters,
    required this.queryParameters,
  });

  factory _GeneratedRouteMethod.toId({
    required String idTypeSource,
    required String name,
    required String targetClassName,
    required String idExpression,
    required List<_GeneratedPathWrite> pathWrites,
    required Map<String, _GeneratedRouteParameter> pathParameters,
    required Map<String, _GeneratedRouteParameter> queryParameters,
  }) {
    return _GeneratedRouteMethod._(
      idTypeSource: idTypeSource,
      name: name,
      targetClassName: targetClassName,
      idExpression: idExpression,
      childLocationTypeSource: null,
      pathWrites: pathWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  factory _GeneratedRouteMethod.toChild({
    required String idTypeSource,
    required String name,
    required String targetClassName,
    required String childLocationTypeSource,
    required List<_GeneratedPathWrite> pathWrites,
    required Map<String, _GeneratedRouteParameter> pathParameters,
    required Map<String, _GeneratedRouteParameter> queryParameters,
  }) {
    return _GeneratedRouteMethod._(
      idTypeSource: idTypeSource,
      name: name,
      targetClassName: targetClassName,
      idExpression: null,
      childLocationTypeSource: childLocationTypeSource,
      pathWrites: pathWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  bool isEquivalent(_GeneratedRouteMethod other) {
    return name == other.name &&
        targetClassName == other.targetClassName &&
        idExpression == other.idExpression &&
        childLocationTypeSource == other.childLocationTypeSource &&
        _pathWritesEquivalent(pathWrites, other.pathWrites) &&
        _parametersEquivalent(pathParameters, other.pathParameters) &&
        _parametersEquivalent(queryParameters, other.queryParameters);
  }

  bool _pathWritesEquivalent(
    List<_GeneratedPathWrite> first,
    List<_GeneratedPathWrite> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (var i = 0; i < first.length; i++) {
      final left = first[i];
      final right = second[i];
      if (left.locationTypeSource != right.locationTypeSource ||
          left.memberName != right.memberName ||
          left.parameterName != right.parameterName) {
        return false;
      }
    }

    return true;
  }

  bool _parametersEquivalent(
    Map<String, _GeneratedRouteParameter> first,
    Map<String, _GeneratedRouteParameter> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (final entry in first.entries) {
      final other = second[entry.key];
      if (other == null ||
          other.parameterName != entry.value.parameterName ||
          other.dartTypeSource != entry.value.dartTypeSource ||
          other.codecExpressionSource != entry.value.codecExpressionSource ||
          other.optional != entry.value.optional) {
        return false;
      }
    }

    return true;
  }

  String renderMethod() {
    final buffer = StringBuffer();
    final parameters = [
      ...pathParameters.entries,
      ...queryParameters.entries,
    ];

    if (parameters.isEmpty) {
      buffer.writeln('  void $name() {');
      buffer.writeln('    routeTo($targetClassName());');
      buffer.writeln('  }');
      return buffer.toString();
    }

    buffer.writeln('  void $name({');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      final typeSource = generatedParameter.optional
          ? '${generatedParameter.dartTypeSource}?'
          : generatedParameter.dartTypeSource;
      final requiredKeyword = generatedParameter.optional ? '' : 'required ';
      buffer.writeln(
        '    $requiredKeyword$typeSource ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('  }) {');
    buffer.writeln('    routeTo(');
    buffer.writeln('      $targetClassName(');
    for (final parameter in parameters) {
      buffer.writeln(
        '        ${parameter.value.parameterName}: '
        '${parameter.value.parameterName},',
      );
    }
    buffer.writeln('      ),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    return buffer.toString();
  }

  String renderTargetClass() {
    final buffer = StringBuffer();
    final parameters = [
      ...pathParameters.entries,
      ...queryParameters.entries,
    ];
    final canUseConstConstructor = idExpression != null && parameters.isEmpty;

    if (idExpression != null) {
      buffer.writeln(
        'final class $targetClassName extends IdRouteTarget<$idTypeSource> {',
      );
    } else {
      buffer.writeln(
        'final class $targetClassName extends ChildRouteTarget<$idTypeSource> {',
      );
    }

    if (parameters.isEmpty) {
      final constKeyword = canUseConstConstructor ? 'const ' : '';
      buffer.writeln('  $constKeyword$targetClassName()');
    } else {
      buffer.writeln('  $targetClassName({');
      for (final parameter in parameters) {
        final generatedParameter = parameter.value;
        final typeSource = generatedParameter.optional
            ? '${generatedParameter.dartTypeSource}?'
            : generatedParameter.dartTypeSource;
        final requiredKeyword = generatedParameter.optional ? '' : 'required ';
        buffer.writeln(
          '    $requiredKeyword$typeSource ${generatedParameter.parameterName},',
        );
      }
      buffer.writeln('  })');
    }

    _writeSuperInvocation(buffer);
    buffer.writeln('}');
    return buffer.toString();
  }

  void _writeSuperInvocation(StringBuffer buffer) {
    final pathWritesByLocationType =
        <String, Map<int, List<_GeneratedPathWrite>>>{};
    for (final pathWrite in pathWrites) {
      final byOccurrence = pathWritesByLocationType.putIfAbsent(
        pathWrite.locationTypeSource,
        () => <int, List<_GeneratedPathWrite>>{},
      );
      byOccurrence
          .putIfAbsent(pathWrite.occurrenceIndex, () => [])
          .add(pathWrite);
    }

    if (idExpression != null) {
      buffer.writeln('      : super(');
      buffer.writeln('          $idExpression,');
    } else {
      buffer.writeln('      : super(');
      buffer.writeln(
        '          (location) => location is $childLocationTypeSource,',
      );
    }

    if (pathWrites.isNotEmpty) {
      buffer.writeln('          writePathParameters: (() {');
      for (final entry in pathWritesByLocationType.entries) {
        final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
        buffer.writeln('            var $counterName = 0;');
      }
      buffer.writeln('            return (location, path) {');
      for (final entry in pathWritesByLocationType.entries) {
        final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
        buffer.writeln(
          '              if (location is ${entry.key}) {',
        );
        buffer.writeln('                switch ($counterName++) {');
        final occurrences = entry.value.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key));
        for (final occurrence in occurrences) {
          buffer.writeln('                  case ${occurrence.key}:');
          for (final pathWrite in occurrence.value) {
            buffer.writeln(
              '                    path(location.${pathWrite.memberName}, '
              '${pathWrite.parameterName});',
            );
          }
          buffer.writeln('                    break;');
        }
        buffer.writeln('                }');
        buffer.writeln('              }');
      }
      buffer.writeln('            };');
      buffer.writeln('          })(),');
    }

    if (queryParameters.isNotEmpty) {
      buffer.writeln('          queryParameters: {');
      for (final parameter in queryParameters.entries) {
        final generatedParameter = parameter.value;
        if (generatedParameter.optional) {
          buffer.writeln(
            "            if (${generatedParameter.parameterName} != null) "
            "'${parameter.key}': ${generatedParameter.codecExpressionSource}"
            '.encode(${generatedParameter.parameterName}),',
          );
        } else {
          buffer.writeln(
            "            '${parameter.key}': "
            "${generatedParameter.codecExpressionSource}.encode("
            "${generatedParameter.parameterName}),",
          );
        }
      }
      buffer.writeln('          },');
    }

    buffer.writeln('        );');
  }
}

sealed class _PathSegmentMetadata {
  const _PathSegmentMetadata();
}

class _LiteralPathSegmentMetadata extends _PathSegmentMetadata {
  final String value;

  const _LiteralPathSegmentMetadata({required this.value});
}

class _RoutePathParameterSegmentMetadata extends _PathSegmentMetadata {
  final String key;
  final String dartTypeSource;
  final String codecExpressionSource;
  final String? memberName;

  const _RoutePathParameterSegmentMetadata({
    required this.key,
    required this.dartTypeSource,
    required this.codecExpressionSource,
    this.memberName,
  });
}

class _RouteQueryParameterMetadata {
  final String key;
  final String dartTypeSource;
  final String codecExpressionSource;
  final bool optional;
  final String? memberName;

  const _RouteQueryParameterMetadata({
    required this.key,
    required this.dartTypeSource,
    required this.codecExpressionSource,
    required this.optional,
    this.memberName,
  });

  _RouteQueryParameterMetadata copyWith({
    String? key,
    String? dartTypeSource,
    String? codecExpressionSource,
    bool? optional,
    String? memberName,
  }) {
    return _RouteQueryParameterMetadata(
      key: key ?? this.key,
      dartTypeSource: dartTypeSource ?? this.dartTypeSource,
      codecExpressionSource:
          codecExpressionSource ?? this.codecExpressionSource,
      optional: optional ?? this.optional,
      memberName: memberName ?? this.memberName,
    );
  }
}

class _GeneratedLocationMixin {
  final String mixinName;
  final String locationBaseTypeSource;
  final List<_RouteQueryParameterMetadata> queryParameters;

  const _GeneratedLocationMixin({
    required this.mixinName,
    required this.locationBaseTypeSource,
    required this.queryParameters,
  });

  String render() {
    final buffer = StringBuffer()
      ..writeln('mixin $mixinName on $locationBaseTypeSource {');

    for (final parameter in queryParameters) {
      buffer.writeln(
        '  QueryParam<${parameter.dartTypeSource}> get ${parameter.memberName};',
      );
    }

    if (queryParameters.isNotEmpty) {
      buffer
        ..writeln('  @override')
        ..writeln(
          '  Map<String, QueryParam<dynamic>> get queryParameters => {',
        );
      for (final parameter in queryParameters) {
        buffer.writeln("    '${parameter.key}': ${parameter.memberName},");
      }
      buffer.writeln('  };');
    }

    buffer.writeln('}');
    return buffer.toString();
  }
}

class _GeneratedPathWrite {
  final String locationTypeSource;
  final int occurrenceIndex;
  final String memberName;
  final String parameterName;

  const _GeneratedPathWrite({
    required this.locationTypeSource,
    required this.occurrenceIndex,
    required this.memberName,
    required this.parameterName,
  });
}

class _GeneratedRouteParameter {
  final String routeKey;
  final String parameterName;
  final String dartTypeSource;
  final String codecExpressionSource;
  final bool optional;

  const _GeneratedRouteParameter({
    required this.routeKey,
    required this.parameterName,
    required this.dartTypeSource,
    required this.codecExpressionSource,
    required this.optional,
  });

  _GeneratedRouteParameter copyWith({
    String? routeKey,
    String? parameterName,
    String? dartTypeSource,
    String? codecExpressionSource,
    bool? optional,
  }) {
    return _GeneratedRouteParameter(
      routeKey: routeKey ?? this.routeKey,
      parameterName: parameterName ?? this.parameterName,
      dartTypeSource: dartTypeSource ?? this.dartTypeSource,
      codecExpressionSource:
          codecExpressionSource ?? this.codecExpressionSource,
      optional: optional ?? this.optional,
    );
  }
}

String _toUpperCamelCase(String value) {
  final pieces = _splitIdentifier(value);
  if (pieces.isEmpty) {
    return 'Route';
  }

  return pieces
      .map((piece) => piece[0].toUpperCase() + piece.substring(1))
      .join();
}

String _childMethodBaseName(String locationTypeSource) {
  const suffix = 'Location';
  if (locationTypeSource.endsWith(suffix) &&
      locationTypeSource.length > suffix.length) {
    return locationTypeSource.substring(
      0,
      locationTypeSource.length - suffix.length,
    );
  }

  return locationTypeSource;
}

String _generatedLocationMixinName(String locationTypeSource) {
  final normalizedTypeSource = locationTypeSource.replaceFirst(
    RegExp('^_+'),
    '',
  );
  return '${normalizedTypeSource}Generated';
}

String _toParameterIdentifier(String value) {
  final pieces = _splitIdentifier(value);
  if (pieces.isEmpty) {
    return 'value';
  }

  final buffer = StringBuffer(pieces.first.toLowerCase());
  for (final piece in pieces.skip(1)) {
    buffer.write(piece[0].toUpperCase());
    buffer.write(piece.substring(1));
  }

  var identifier = buffer.toString();
  if (RegExp('^[0-9]').hasMatch(identifier)) {
    identifier = 'value$identifier';
  }
  if (_dartKeywords.contains(identifier)) {
    identifier = '${identifier}Value';
  }
  return identifier;
}

List<String> _splitIdentifier(String value) {
  final sanitized = value.replaceAll(RegExp('[^a-zA-Z0-9]+'), ' ');
  final spaceSeparated = sanitized
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .trim();
  if (spaceSeparated.isEmpty) {
    return const [];
  }
  return spaceSeparated
      .split(RegExp(r'\s+'))
      .map((piece) => piece.toLowerCase())
      .where((piece) => piece.isNotEmpty)
      .toList();
}

const _dartKeywords = {
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
};
