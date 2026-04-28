import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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
    _validateRouteDeclarationType(declarationElement);
    final extractor = _StaticRouteTreeExtractor(
      buildStep: buildStep,
      rootElement: declarationElement,
    );
    final roots = await extractor.extract(declarationElement);
    final methods = _collectRouteMethods(roots, declarationElement);
    final locationChildTargetResult = _collectLocationChildTargetMethods(
      roots,
      declarationElement,
      onSuppressedAmbiguousMethod: (warning) => log.warning(warning),
    );
    if (methods.isEmpty &&
        locationChildTargetResult.methods.isEmpty &&
        locationChildTargetResult.firstRouteMethods.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();

    for (final method in methods) {
      buffer.writeln(method.renderTargetClass());
    }
    final extensionName =
        '${_toUpperCamelCase(declarationElement.displayName)}GeneratedRoutes';
    buffer.writeln(
      'extension $extensionName on WorkingRouterSailor {',
    );

    for (final method in methods) {
      buffer.writeln(method.renderMethod());
    }

    buffer.writeln('}');

    final childMethodsByOwner = groupBy(
      locationChildTargetResult.methods,
      (method) => method.ownerTypeSource,
    );
    final firstChildMethodsByOwner = groupBy(
      locationChildTargetResult.firstRouteMethods,
      (method) => method.ownerTypeSource,
    );
    final ownerTypes = <String>{
      ...childMethodsByOwner.keys,
      ...firstChildMethodsByOwner.keys,
    }.toList()..sort();
    for (final ownerType in ownerTypes) {
      buffer.writeln(
        'extension ${ownerType}GeneratedChildTargets on $ownerType {',
      );
      for (final method
          in childMethodsByOwner[ownerType] ??
              const <_GeneratedLocationChildTargetMethod>[]) {
        buffer.writeln(method.renderMethod());
        buffer.writeln(method.renderRouteMethod());
      }
      for (final method
          in firstChildMethodsByOwner[ownerType] ??
              const <_GeneratedFirstLocationChildRouteMethod>[]) {
        buffer.writeln(method.renderRouteMethod());
      }
      buffer.writeln('}');
    }
    return buffer.toString();
  }

  void _validateRouteDeclarationType(Element element) {
    _validateDeclarationTarget(element);

    if (element case ExecutableElement()) {
      final routeNodeType = _routeNodeType(element.returnType);
      if (routeNodeType != null) {
        return;
      }
    }

    if (element case PropertyInducingElement()) {
      final routeNodeType = _routeNodeType(element.type);
      if (routeNodeType != null) {
        return;
      }
    }

    throw InvalidGenerationSourceError(
      'The annotated declaration must have type RouteNode or '
      'Iterable<RouteNode>.',
      element: element,
    );
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
      if (node.idExpression != null && !node.isOverlay) {
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

      for (final child in node.children) {
        visit(child, nextChain);
      }
    }

    for (final root in roots) {
      visit(root, const []);
    }
    return methods;
  }

  _GeneratedLocationChildTargetMethodsResult _collectLocationChildTargetMethods(
    Iterable<_RouteNode> roots,
    Element element, {
    void Function(String warning)? onSuppressedAmbiguousMethod,
  }) {
    final variants = <_GeneratedLocationChildTargetMethodVariant>[];
    final suppressedMethodKeys = <String>{};

    void visit(_RouteNode node, List<_RouteNode> chain) {
      final nextChain = [...chain, node];
      if (_supportsGeneratedLocationChildTarget(node)) {
        for (var i = 0; i < chain.length; i++) {
          final owner = chain[i];
          if (!owner.isRoutableLocation ||
              owner.locationTypeSource == 'Location' ||
              owner.locationTypeSource == 'ShellLocation' ||
              owner.locationTypeSource == 'Scope') {
            continue;
          }

          final relativeChain = nextChain.sublist(i + 1);
          if (relativeChain.isEmpty) {
            continue;
          }

          variants.add(
            _buildLocationChildTargetMethodVariant(
              owner: owner,
              relativeChain: relativeChain,
              target: node,
              element: element,
            ),
          );
        }
      }

      if (node.isRoutableLocation &&
          node.locationTypeSource != 'Location' &&
          node.locationTypeSource != 'ShellLocation' &&
          node.locationTypeSource != 'Scope') {
        for (final overlay in node.overlays) {
          if (_supportsGeneratedLocationChildTarget(overlay)) {
            variants.add(
              _buildLocationChildTargetMethodVariant(
                owner: node,
                relativeChain: [overlay],
                target: overlay,
                element: element,
                isOverlay: true,
              ),
            );
          }
        }
      }

      for (final child in node.children) {
        visit(child, nextChain);
      }
    }

    for (final root in roots) {
      visit(root, const []);
    }

    final namedVariants = _assignLocationChildTargetMethodNames(variants);
    final methods = <_GeneratedLocationChildTargetMethod>[];
    final firstRouteMethods = <_GeneratedFirstLocationChildRouteMethod>[];
    final variantsByOwnerAndName =
        <String, List<_GeneratedLocationChildTargetMethodVariant>>{};
    for (final variant in namedVariants) {
      final methodKey = '${variant.ownerTypeSource}.${variant.name}';
      variantsByOwnerAndName.putIfAbsent(methodKey, () => []).add(variant);
    }
    for (final entry in variantsByOwnerAndName.entries) {
      final deduplicatedVariants =
          <_GeneratedLocationChildTargetMethodVariant>[];
      for (final variant in entry.value) {
        final previousForSameOwner = deduplicatedVariants
            .where(
              (previous) => identical(previous.ownerNode, variant.ownerNode),
            )
            .toList(growable: false);
        final higherPrecedencePreviousForSameOwner = previousForSameOwner.where(
          (previous) =>
              _compareLocationChildTargetVariantPrecedence(
                previous,
                variant,
              ) >
              0,
        );
        if (higherPrecedencePreviousForSameOwner.isNotEmpty) {
          continue;
        }
        deduplicatedVariants.removeWhere(
          (previous) =>
              identical(previous.ownerNode, variant.ownerNode) &&
              _compareLocationChildTargetVariantPrecedence(variant, previous) >
                  0,
        );
        if (variant.hasTargetIdentity &&
            previousForSameOwner.any(
              (previous) =>
                  _compareLocationChildTargetVariantPrecedence(
                        previous,
                        variant,
                      ) ==
                      0 &&
                  !previous.hasTargetIdentity,
            )) {
          deduplicatedVariants.removeWhere(
            (previous) =>
                identical(previous.ownerNode, variant.ownerNode) &&
                _compareLocationChildTargetVariantPrecedence(
                      previous,
                      variant,
                    ) ==
                    0 &&
                !previous.hasTargetIdentity,
          );
        }
        final hasCompatibleVariant = deduplicatedVariants.any(
          (previous) => _locationChildTargetMethodVariantsAreCompatible(
            previous,
            variant,
          ),
        );
        if (!hasCompatibleVariant) {
          deduplicatedVariants.add(variant);
        }
      }

      final method = _mergeLocationChildTargetMethodVariants(
        deduplicatedVariants,
      );
      if (method != null) {
        methods.add(method);
        continue;
      }

      suppressedMethodKeys.add(entry.key);
      final firstRouteMethod = _mergeFirstLocationChildRouteMethodVariants(
        deduplicatedVariants,
      );
      if (firstRouteMethod != null) {
        firstRouteMethods.add(firstRouteMethod);
      } else {
        onSuppressedAmbiguousMethod?.call(
          'Skipped `${entry.key}`: multiple descendant routes would match this '
          'child target.',
        );
      }
    }

    final methodsByOwnerAndTargetType =
        <String, List<_GeneratedLocationChildTargetMethod>>{};
    for (final method in methods) {
      final familyKey = '${method.ownerTypeSource}.${method.targetTypeSource}';
      methodsByOwnerAndTargetType.putIfAbsent(familyKey, () => []).add(method);
    }
    for (final family in methodsByOwnerAndTargetType.values) {
      for (final method in family) {
        if (method.hasTargetIdentity) {
          continue;
        }
        final hasConflictingFamilyMember = family.any(
          (other) =>
              !identical(other, method) &&
              other.name == method.name &&
              !_locationChildTargetMethodsAreCompatible(method, other),
        );
        if (!hasConflictingFamilyMember) {
          continue;
        }

        final methodKey = '${method.ownerTypeSource}.${method.name}';
        if (suppressedMethodKeys.contains(methodKey)) {
          continue;
        }
        methods.remove(method);
        suppressedMethodKeys.add(methodKey);
        firstRouteMethods.add(
          _GeneratedFirstLocationChildRouteMethod(
            variants: method.variants,
          ),
        );
      }
    }
    return _GeneratedLocationChildTargetMethodsResult(
      methods: methods,
      firstRouteMethods: firstRouteMethods,
    );
  }

  bool _locationChildTargetMethodsAreCompatible(
    _GeneratedLocationChildTargetMethod first,
    _GeneratedLocationChildTargetMethod second,
  ) {
    return first.isEquivalent(second);
  }

  bool _locationChildTargetMethodVariantsAreCompatible(
    _GeneratedLocationChildTargetMethodVariant first,
    _GeneratedLocationChildTargetMethodVariant second,
  ) {
    return first.isEquivalent(second) &&
        (!identical(first.ownerNode, second.ownerNode) ||
            _branchSelectionsAreMutuallyExclusive(
              first.exclusiveBranchSelections,
              second.exclusiveBranchSelections,
            ));
  }

  int _compareLocationChildTargetVariantPrecedence(
    _GeneratedLocationChildTargetMethodVariant first,
    _GeneratedLocationChildTargetMethodVariant second,
  ) {
    final depthComparison = second.relativeDepth.compareTo(first.relativeDepth);
    if (depthComparison != 0) {
      return depthComparison;
    }
    if (first.hasTargetIdentity != second.hasTargetIdentity) {
      return first.hasTargetIdentity ? 1 : -1;
    }
    return 0;
  }

  List<_GeneratedLocationChildTargetMethodVariant>
  _assignLocationChildTargetMethodNames(
    List<_GeneratedLocationChildTargetMethodVariant> variants,
  ) {
    final variantsByOwnerType =
        <String, List<_GeneratedLocationChildTargetMethodVariant>>{};
    for (final variant in variants) {
      variantsByOwnerType
          .putIfAbsent(variant.ownerTypeSource, () => [])
          .add(variant);
    }

    final namedVariants = <_GeneratedLocationChildTargetMethodVariant>[];
    for (final ownerTypeVariants in variantsByOwnerType.values) {
      final assignedNames =
          <_GeneratedLocationChildTargetMethodVariant, String>{};
      final pending = ownerTypeVariants.toSet();
      var segmentLength = 1;

      while (pending.isNotEmpty) {
        final candidateGroups =
            <String, List<_GeneratedLocationChildTargetMethodVariant>>{};
        for (final variant in pending) {
          final candidate = _childTargetMethodNameFromSegments(
            variant.structuralNameSegments,
            length: segmentLength,
          );
          candidateGroups.putIfAbsent(candidate, () => []).add(variant);
        }

        final nextPending = <_GeneratedLocationChildTargetMethodVariant>{};
        for (final group in candidateGroups.values) {
          if (group.length == 1) {
            assignedNames[group.single] = _childTargetMethodNameFromSegments(
              group.single.structuralNameSegments,
              length: segmentLength,
            );
            continue;
          }

          final canExpandStructurally = group.any(
            (variant) => variant.structuralNameSegments.length > segmentLength,
          );
          if (canExpandStructurally) {
            nextPending.addAll(group);
            continue;
          }

          final identityGroups =
              <String, List<_GeneratedLocationChildTargetMethodVariant>>{};
          for (final variant in group) {
            final identityCandidate = _childTargetMethodNameFromSegments(
              variant.identityAwareNameSegments,
              length: segmentLength,
            );
            identityGroups
                .putIfAbsent(identityCandidate, () => [])
                .add(variant);
          }

          for (final entry in identityGroups.entries) {
            final identityGroup = entry.value;
            if (identityGroup.length == 1) {
              assignedNames[identityGroup.single] = entry.key;
              continue;
            }

            for (final variant in identityGroup) {
              assignedNames[variant] = entry.key;
            }
          }
        }

        if (nextPending.length == pending.length) {
          for (final variant in nextPending) {
            assignedNames.putIfAbsent(
              variant,
              () => _childTargetMethodNameFromSegments(
                variant.identityAwareNameSegments,
                length: variant.identityAwareNameSegments.length,
              ),
            );
          }
          break;
        }

        pending
          ..clear()
          ..addAll(nextPending);
        segmentLength += 1;
      }

      for (final variant in ownerTypeVariants) {
        namedVariants.add(
          variant.copyWith(
            name:
                assignedNames[variant] ??
                _childTargetMethodNameFromSegments(
                  variant.identityAwareNameSegments,
                  length: variant.identityAwareNameSegments.length,
                ),
          ),
        );
      }
    }

    return namedVariants;
  }

  String _childTargetMethodNameFromSegments(
    List<String> segments, {
    required int length,
  }) {
    final clampedLength = math.min(length, segments.length);
    final usedSegments = segments.skip(segments.length - clampedLength);
    return 'child${_toUpperCamelCase(usedSegments.join())}Target';
  }

  bool _supportsGeneratedLocationChildTarget(_RouteNode node) {
    if (!node.isRoutableLocation) {
      return false;
    }

    if (node.localIdExpression != null) {
      return true;
    }

    if (node.idExpression != null) {
      return true;
    }

    return node.locationTypeSource != 'Location' &&
        node.locationTypeSource != 'ShellLocation' &&
        node.locationTypeSource != 'MultiShellLocation' &&
        node.locationTypeSource != 'Scope';
  }

  _GeneratedRouteMethod _buildMethod(
    List<_RouteNode> chain,
    String idExpression,
    Element element,
  ) {
    final idBaseName = _identityBaseNameFromExpression(idExpression);
    final methodName = 'routeTo${_toUpperCamelCase(idBaseName)}';
    final targetClassName = '${_toUpperCamelCase(idBaseName)}RouteTarget';
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
    final queryWrites = _collectQueryWrites(
      chain,
      queryParameters,
    );

    return _GeneratedRouteMethod.toId(
      name: methodName,
      targetClassName: targetClassName,
      idExpression: idExpression,
      pathWrites: pathWrites,
      queryWrites: queryWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  _GeneratedLocationChildTargetMethodVariant
  _buildLocationChildTargetMethodVariant({
    required _RouteNode owner,
    required List<_RouteNode> relativeChain,
    required _RouteNode target,
    required Element element,
    bool isOverlay = false,
  }) {
    final (pathParameters, queryParameters) = _collectParameters(
      relativeChain,
      element: element,
      errorContext:
          '${owner.locationTypeSource} -> ${target.idExpression ?? target.locationTypeSource}',
    );
    if (!isOverlay && owner.overlays.isNotEmpty) {
      _addOptionalOwnerQueryParameters(
        owner: owner,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        element: element,
        errorContext:
            '${owner.locationTypeSource} -> ${target.idExpression ?? target.locationTypeSource}',
      );
    }
    final pathWrites = _collectPathWrites(
      relativeChain,
      pathParameters,
      element: element,
      errorContext:
          '${owner.locationTypeSource} -> ${target.idExpression ?? target.locationTypeSource}',
    );
    final queryWrites = [
      if (!isOverlay && owner.overlays.isNotEmpty)
        ..._collectOwnerQueryWrites(owner, queryParameters),
      ..._collectQueryWrites(
        relativeChain,
        queryParameters,
      ),
    ];
    if (isOverlay && pathParameters.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Overlay target `${target.locationTypeSource}` cannot declare '
        'path parameters.',
        element: element,
      );
    }

    return _GeneratedLocationChildTargetMethodVariant(
      ownerNode: owner,
      ownerSelectorExpression: _ownerSelectorExpression(owner),
      ownerSelectorMatchSource: _ownerSelectorMatchSource(owner),
      ownerTypeSource: owner.locationTypeSource,
      name: '',
      targetTypeSource: target.locationTypeSource,
      hasTargetIdentity:
          target.localIdExpression != null || target.idExpression != null,
      childLocationMatchSource: _childRouteNodeMatchSource(target),
      relativeDepth: relativeChain.length,
      structuralNameSegments: [
        for (final node in relativeChain)
          _childMethodBaseName(node.locationTypeSource),
      ],
      identityAwareNameSegments: [
        for (final node in relativeChain) _childMethodBaseNameForNode(node),
      ],
      relativeNodeMatchSources: [
        for (final node in relativeChain) _routeNodeMatchSourceOn('node', node),
      ],
      isOverlay: isOverlay,
      exclusiveBranchSelections: target.exclusiveBranchSelections,
      pathWrites: pathWrites,
      queryWrites: queryWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  _GeneratedLocationChildTargetMethod? _mergeLocationChildTargetMethodVariants(
    List<_GeneratedLocationChildTargetMethodVariant> variants,
  ) {
    if (variants.isEmpty) {
      return null;
    }

    final first = variants.first;
    if (variants.length == 1) {
      return _GeneratedLocationChildTargetMethod(variants: variants);
    }

    if (variants.any(
      (variant) =>
          variant.ownerTypeSource != first.ownerTypeSource ||
          variant.name != first.name ||
          variant.targetTypeSource != first.targetTypeSource ||
          !_parametersEquivalent(
            variant.pathParameters,
            first.pathParameters,
          ) ||
          !_parametersEquivalent(
            variant.queryParameters,
            first.queryParameters,
          ),
    )) {
      return null;
    }

    final defaultVariants = variants
        .where((variant) => variant.ownerSelectorExpression == null)
        .toList(growable: false);
    if (defaultVariants.length > 1) {
      return null;
    }

    final usedOwnerIds = <String>{};
    for (final variant in variants) {
      final ownerSelectorExpression = variant.ownerSelectorExpression;
      if (ownerSelectorExpression == null) {
        continue;
      }
      if (!usedOwnerIds.add(ownerSelectorExpression)) {
        return null;
      }
    }

    final orderedVariants = [
      ...variants
          .where((variant) => variant.ownerSelectorExpression != null)
          .sortedBy((variant) => variant.ownerSelectorExpression!),
      ...defaultVariants,
    ];
    return _GeneratedLocationChildTargetMethod(variants: orderedVariants);
  }

  _GeneratedFirstLocationChildRouteMethod?
  _mergeFirstLocationChildRouteMethodVariants(
    List<_GeneratedLocationChildTargetMethodVariant> variants,
  ) {
    if (variants.isEmpty) {
      return null;
    }

    final first = variants.first;
    if (variants.any(
      (variant) =>
          variant.ownerTypeSource != first.ownerTypeSource ||
          variant.name != first.name ||
          !_parametersEquivalent(
            variant.pathParameters,
            first.pathParameters,
          ) ||
          !_parametersEquivalent(
            variant.queryParameters,
            first.queryParameters,
          ),
    )) {
      return null;
    }

    final defaultVariants = variants
        .where((variant) => variant.ownerSelectorExpression == null)
        .toList(growable: false);
    if (defaultVariants.length > 1 &&
        defaultVariants.map((variant) => variant.ownerNode).toSet().length >
            1) {
      return null;
    }

    final firstVariantByOwnerSelector =
        <String, _GeneratedLocationChildTargetMethodVariant>{};
    for (final variant in variants) {
      final ownerSelectorExpression = variant.ownerSelectorExpression;
      if (ownerSelectorExpression == null) {
        continue;
      }
      firstVariantByOwnerSelector.putIfAbsent(ownerSelectorExpression, () {
        return variant;
      });
    }

    final orderedVariants = [
      ...firstVariantByOwnerSelector.entries
          .sortedBy((entry) => entry.key)
          .map(
            (entry) => entry.value,
          ),
      if (defaultVariants.isNotEmpty) defaultVariants.first,
    ];
    return _GeneratedFirstLocationChildRouteMethod(variants: orderedVariants);
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
          _throwGeneratedParameterError(
            'The generated helper for `$errorContext` needs two path '
            'parameters named `$originalName`. Rename one of those path '
            'parameter fields.',
            parameter: parameter,
            fallbackElement: element,
          );
        }
        final existing = target[originalName]!;
        final mergedParameter = _mergeCompatibleQueryParameter(
          existing,
          parameter,
        );
        if (mergedParameter == null) {
          _throwGeneratedParameterError(
            'The generated helper for `$errorContext` needs conflicting $kind '
            'parameter metadata for `$originalName`.',
            parameter: parameter,
            fallbackElement: element,
          );
        }
        target[originalName] = mergedParameter;
        return;
      }

      final parameterName = _toParameterIdentifier(originalName);
      final previousOriginalName = usedParameterNames[parameterName];
      if (previousOriginalName != null &&
          previousOriginalName != originalName) {
        _throwGeneratedParameterError(
          'The generated helper for `$errorContext` needs two $kind '
          'parameters that both map to `$parameterName` '
          '($previousOriginalName and $originalName).',
          parameter: parameter,
          fallbackElement: element,
        );
      }

      if (pathParameters.containsKey(originalName) &&
          !identical(target, pathParameters)) {
        _throwGeneratedParameterError(
          'The generated helper for `$errorContext` uses `$originalName` as '
          'both a path parameter and a query parameter.',
          parameter: parameter,
          fallbackElement: element,
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
              sourceNode: segment.sourceNode,
              sourceElement: segment.sourceElement,
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
            sourceNode: queryParameter.sourceNode,
            sourceElement: queryParameter.sourceElement,
          ),
          queryParameters,
          'query',
        );
      }
    }

    return (pathParameters, queryParameters);
  }

  void _addOptionalOwnerQueryParameters({
    required _RouteNode owner,
    required Map<String, _GeneratedRouteParameter> pathParameters,
    required Map<String, _GeneratedRouteParameter> queryParameters,
    required Element element,
    required String errorContext,
  }) {
    for (final queryParameter in owner.queryParameters.values) {
      final parameter = _GeneratedRouteParameter(
        routeKey: queryParameter.key,
        parameterName: '',
        dartTypeSource: queryParameter.dartTypeSource,
        codecExpressionSource: queryParameter.codecExpressionSource,
        optional: true,
        sourceNode: queryParameter.sourceNode,
        sourceElement: queryParameter.sourceElement,
      );

      final existing = queryParameters[queryParameter.key];
      if (existing != null) {
        final mergedParameter = _mergeCompatibleQueryParameter(
          existing,
          parameter,
        );
        if (mergedParameter == null) {
          _throwGeneratedParameterError(
            'The generated helper for `$errorContext` needs conflicting query '
            'parameter metadata for `${queryParameter.key}`.',
            parameter: parameter,
            fallbackElement: element,
          );
        }
        queryParameters[queryParameter.key] = mergedParameter;
        continue;
      }

      final parameterName = _toParameterIdentifier(queryParameter.key);
      final conflictingPathParameter = pathParameters.values
          .where(
            (pathParameter) =>
                pathParameter.parameterName == parameterName &&
                pathParameter.routeKey != queryParameter.key,
          )
          .firstOrNull;
      if (conflictingPathParameter != null) {
        _throwGeneratedParameterError(
          'The generated helper for `$errorContext` needs a query parameter '
          'that maps to `$parameterName`, but a path parameter already uses '
          'that generated name.',
          parameter: parameter,
          fallbackElement: element,
        );
      }

      final conflictingQueryParameter = queryParameters.values
          .where(
            (existingParameter) =>
                existingParameter.parameterName == parameterName &&
                existingParameter.routeKey != queryParameter.key,
          )
          .firstOrNull;
      if (conflictingQueryParameter != null) {
        _throwGeneratedParameterError(
          'The generated helper for `$errorContext` needs two query '
          'parameters that both map to `$parameterName` '
          '(${conflictingQueryParameter.routeKey} and ${queryParameter.key}).',
          parameter: parameter,
          fallbackElement: element,
        );
      }

      if (pathParameters.containsKey(queryParameter.key)) {
        _throwGeneratedParameterError(
          'The generated helper for `$errorContext` uses '
          '`${queryParameter.key}` as both a path parameter and a query '
          'parameter.',
          parameter: parameter,
          fallbackElement: element,
        );
      }

      queryParameters[queryParameter.key] = parameter.copyWith(
        parameterName: parameterName,
      );
    }
  }

  Never _throwGeneratedParameterError(
    String message, {
    required _GeneratedRouteParameter parameter,
    required Element fallbackElement,
  }) {
    if (parameter.sourceNode != null) {
      throw InvalidGenerationSourceError(
        message,
        node: parameter.sourceNode,
      );
    }
    throw InvalidGenerationSourceError(
      message,
      element: parameter.sourceElement ?? fallbackElement,
    );
  }

  _GeneratedRouteParameter? _mergeCompatibleQueryParameter(
    _GeneratedRouteParameter existing,
    _GeneratedRouteParameter incoming,
  ) {
    if (existing.codecExpressionSource != incoming.codecExpressionSource) {
      return null;
    }

    if (_nonNullableTypeSource(existing.dartTypeSource) !=
        _nonNullableTypeSource(incoming.dartTypeSource)) {
      return null;
    }

    if (!existing.optional && !incoming.optional) {
      return existing.dartTypeSource == incoming.dartTypeSource
          ? existing
          : null;
    }

    final mergedOptional = existing.optional && incoming.optional;
    final preferIncomingSource = !incoming.optional && existing.optional;

    return existing.copyWith(
      dartTypeSource: _nonNullableTypeSource(existing.dartTypeSource),
      optional: mergedOptional,
      sourceNode: preferIncomingSource ? incoming.sourceNode : null,
      sourceElement: preferIncomingSource ? incoming.sourceElement : null,
    );
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
      final matchDiscriminator = _routeNodeMatchDiscriminator(node);
      final occurrenceIndex = locationOccurrences[matchDiscriminator] ?? 0;
      for (final segment
          in node.pathSegments
              .whereType<_RoutePathParameterSegmentMetadata>()) {
        final generatedParameter = pathParameters[segment.key];
        if (generatedParameter == null) {
          continue;
        }

        final parameterAccessorSource = switch ((
          segment.memberName,
          segment.pathParameterIndex,
        )) {
          (final String memberName?, _) => 'node.$memberName',
          (_, final int pathParameterIndex?) =>
            'node.pathParameters[$pathParameterIndex] '
                'as PathParam<${segment.dartTypeSource}>',
          _ => throw InvalidGenerationSourceError(
            'The generated helper for `$errorContext` could not resolve how '
            'to access one of its path parameters.',
            element: element,
          ),
        };

        writes.add(
          _GeneratedPathWrite(
            locationMatchDiscriminator: matchDiscriminator,
            locationMatchSource: _routeNodeMatchSourceOn('node', node),
            occurrenceIndex: occurrenceIndex,
            parameterAccessorSource: parameterAccessorSource,
            parameterIsOptional: false,
            parameterName: generatedParameter.parameterName,
          ),
        );
      }
      locationOccurrences[matchDiscriminator] = occurrenceIndex + 1;
    }

    return writes;
  }

  List<_GeneratedPathWrite> _collectQueryWrites(
    Iterable<_RouteNode> nodes,
    Map<String, _GeneratedRouteParameter> queryParameters,
  ) {
    final writes = <_GeneratedPathWrite>[];
    final locationOccurrences = <String, int>{};

    for (final node in nodes) {
      final matchDiscriminator = _routeNodeMatchDiscriminator(node);
      final occurrenceIndex = locationOccurrences[matchDiscriminator] ?? 0;
      for (final queryParameter in node.queryParameters.values) {
        final generatedParameter = queryParameters[queryParameter.key];
        if (generatedParameter == null) {
          continue;
        }

        writes.add(
          _GeneratedPathWrite(
            locationMatchDiscriminator: matchDiscriminator,
            locationMatchSource: _routeNodeMatchSourceOn('node', node),
            occurrenceIndex: occurrenceIndex,
            parameterAccessorSource:
                'node.queryParameters.firstWhere((it) => '
                'it.name == ${_quotedDartString(queryParameter.key)}) '
                'as QueryParam<${queryParameter.dartTypeSource}>',
            parameterIsOptional: generatedParameter.optional,
            parameterName: generatedParameter.parameterName,
          ),
        );
      }
      locationOccurrences[matchDiscriminator] = occurrenceIndex + 1;
    }

    return writes;
  }

  List<_GeneratedPathWrite> _collectOwnerQueryWrites(
    _RouteNode owner,
    Map<String, _GeneratedRouteParameter> queryParameters,
  ) {
    final writes = <_GeneratedPathWrite>[];
    for (final queryParameter in owner.queryParameters.values) {
      final generatedParameter = queryParameters[queryParameter.key];
      if (generatedParameter == null) {
        continue;
      }

      writes.add(
        _GeneratedPathWrite(
          locationMatchDiscriminator:
              '${_routeNodeMatchDiscriminator(owner)}Owner',
          locationMatchSource: 'identical(node, this)',
          occurrenceIndex: 0,
          parameterAccessorSource:
              'node.queryParameters.firstWhere((it) => '
              'it.name == ${_quotedDartString(queryParameter.key)}) '
              'as QueryParam<${queryParameter.dartTypeSource}>',
          parameterIsOptional: true,
          parameterName: generatedParameter.parameterName,
        ),
      );
    }
    return writes;
  }

  String _routeNodeMatchDiscriminator(_RouteNode node) {
    if (node.idExpression != null) {
      return node.idExpression!;
    }
    if (node.localIdExpression != null) {
      return node.localIdExpression!;
    }
    return node.locationTypeSource;
  }

  String _routeNodeMatchSource(_RouteNode node) {
    return _routeNodeMatchSourceOn('location', node);
  }

  String _routeNodeMatchSourceOn(String variableName, _RouteNode node) {
    if (node.idExpression != null) {
      return '$variableName.id == ${node.idExpression}';
    }
    if (node.localIdExpression != null) {
      return '$variableName.localId == ${node.localIdExpression}';
    }
    return '$variableName is ${node.locationTypeSource}';
  }

  String _childMethodBaseNameForNode(_RouteNode node) {
    if (node.localIdExpression != null) {
      return _identityBaseNameFromExpression(node.localIdExpression!);
    }
    if (node.idExpression != null) {
      return _identityBaseNameFromExpression(node.idExpression!);
    }
    return _childMethodBaseName(node.locationTypeSource);
  }

  String _childRouteNodeMatchSource(_RouteNode node) {
    if (node.localIdExpression != null) {
      return 'location.localId == ${node.localIdExpression}';
    }
    return _routeNodeMatchSource(node);
  }

  String? _ownerSelectorExpression(_RouteNode node) {
    return node.localIdExpression ?? node.idExpression;
  }

  String? _ownerSelectorMatchSource(_RouteNode node) {
    if (node.localIdExpression != null) {
      return 'localId == ${node.localIdExpression}';
    }
    if (node.idExpression != null) {
      return 'id == ${node.idExpression}';
    }
    return null;
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
}

String _unsupportedConditionalIdMessage(Expression expression) {
  return 'Only `id != null ? ... : null` style conditional ids are '
      'supported, but got condition `${expression.toSource()}`.';
}

class _NestedBuilderDeclarationFinder extends RecursiveAstVisitor<void> {
  final String builderParameterName;
  MethodInvocation? invocation;

  _NestedBuilderDeclarationFinder({
    required this.builderParameterName,
  });

  static MethodInvocation? find(
    Expression expression, {
    required String builderParameterName,
  }) {
    final visitor = _NestedBuilderDeclarationFinder(
      builderParameterName: builderParameterName,
    );
    expression.accept(visitor);
    return visitor.invocation;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Nested callbacks belong to widget/content builders, not the route DSL
    // body currently being analyzed.
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (invocation != null) {
      return;
    }
    if (_isBuilderRouteDeclaration(node)) {
      invocation = node;
      return;
    }
    super.visitMethodInvocation(node);
  }

  bool _isBuilderRouteDeclaration(MethodInvocation invocation) {
    if (invocation.realTarget case final SimpleIdentifier target
        when target.name == builderParameterName) {
      return _builderRouteDeclarationMethods.contains(
        invocation.methodName.name,
      );
    }
    return false;
  }
}

const _builderRouteDeclarationMethods = {
  'pathSegment',
  'pathLiteral',
  'pathParam',
  'stringPathParam',
  'intPathParam',
  'doublePathParam',
  'boolPathParam',
  'dateTimePathParam',
  'uriPathParam',
  'enumPathParam',
  'queryParam',
  'defaultQueryParam',
  'stringQueryParam',
  'defaultStringQueryParam',
  'nullableStringQueryParam',
  'intQueryParam',
  'defaultIntQueryParam',
  'nullableIntQueryParam',
  'doubleQueryParam',
  'defaultDoubleQueryParam',
  'nullableDoubleQueryParam',
  'boolQueryParam',
  'defaultBoolQueryParam',
  'nullableBoolQueryParam',
  'dateTimeQueryParam',
  'defaultDateTimeQueryParam',
  'nullableDateTimeQueryParam',
  'uriQueryParam',
  'defaultUriQueryParam',
  'nullableUriQueryParam',
  'enumQueryParam',
  'defaultEnumQueryParam',
  'nullableEnumQueryParam',
  'bindParam',
  'bindQueryParam',
  'bindDefaultQueryParam',
  'id',
  'localId',
  'child',
  'location',
  'shell',
};

class _StaticRouteTreeExtractor {
  final BuildStep buildStep;
  final Element rootElement;
  int _nextExclusiveBranchGroupId = 0;

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
          'The annotated route-node tree variable must have an initializer.',
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
          'The annotated route-node tree variable must have an initializer.',
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
          'The annotated route-node tree variable must have an initializer.',
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
          'The annotated route-node tree variable must have an initializer.',
          element: declarationElement,
        );
      }
      return initializer;
    }

    throw InvalidGenerationSourceError(
      'Unable to read the annotated route-node tree source.',
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
      _unsupportedRouteTreeExpressionMessage(normalizedExpression),
      node: normalizedExpression,
    );
  }

  String _unsupportedRouteTreeExpressionMessage(Expression expression) {
    final baseMessage =
        'Unsupported route tree expression `${expression.toSource()}`. '
        'Use static constructor trees, helper getters, helper variables, or '
        'zero-argument helper functions.';

    final unresolvedInvocationName = switch (expression) {
      MethodInvocation(:final target, :final methodName)
          when target == null && expression.argumentList.arguments.isEmpty =>
        methodName.name,
      FunctionExpressionInvocation(:final function)
          when expression.argumentList.arguments.isEmpty =>
        switch (function) {
          SimpleIdentifier() => function.name,
          PrefixedIdentifier() => function.identifier.name,
          PropertyAccess() => function.propertyName.name,
          _ => null,
        },
      _ => null,
    };

    if (unresolvedInvocationName == null) {
      return baseMessage;
    }

    return '$baseMessage `$unresolvedInvocationName()` could not be '
        'resolved here. If this should create a RouteNode, check that '
        '`$unresolvedInvocationName` is imported and visible in this '
        'library.';
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

    final isOverlay = _isOverlayLikeClass(classElement);
    final isLocation = _isLocationLikeClass(classElement);
    final supportsPathAndQuery =
        (isLocation && !isOverlay) || _isShellLikeClass(classElement);
    final isDirectBaseNode =
        classElement.displayName == 'Location' ||
        classElement.displayName == 'AbstractLocation' ||
        classElement.displayName == 'ShellLocation' ||
        classElement.displayName == 'AbstractShellLocation' ||
        classElement.displayName == 'MultiShellLocation' ||
        classElement.displayName == 'AbstractMultiShellLocation' ||
        classElement.displayName == 'MultiShell' ||
        classElement.displayName == 'AbstractMultiShell' ||
        classElement.displayName == 'Overlay' ||
        classElement.displayName == 'AbstractOverlay' ||
        classElement.displayName == 'Scope' ||
        classElement.displayName == 'AbstractScope' ||
        classElement.displayName == 'Shell' ||
        classElement.displayName == 'AbstractShell';
    final context = isDirectBaseNode
        ? evaluationContext
        : await _InstanceStringContext.fromCreation(
            buildStep: buildStep,
            creation: expression,
            rootElement: rootElement,
            parentContext: evaluationContext,
          );
    final instanceContext = context is _InstanceStringContext ? context : null;
    final dslDefinition = await _resolveDslDefinition(
      classElement: classElement,
      creation: expression,
      evaluationContext: context ?? _NoopExpressionContext(),
      isLocation: isLocation,
      supportsPathAndQuery: supportsPathAndQuery,
    );
    final pathSegments =
        dslDefinition?.pathSegments ??
        (supportsPathAndQuery
            ? await _resolvePathSegments(instanceContext!)
            : const <_PathSegmentMetadata>[]);
    final queryParameters =
        dslDefinition?.queryParameters ??
        (supportsPathAndQuery
            ? await _resolveQueryParameters(
                classElement,
                evaluationContext: context,
              )
            : const <String, _RouteQueryParameterMetadata>{});
    final children =
        dslDefinition?.children ??
        await (() async {
          final childrenExpression = await instanceContext!
              .locationChildrenExpression();
          return childrenExpression == null
              ? const <_RouteNode>[]
              : await _locationsFromListExpression(
                  childrenExpression,
                  evaluationContext: context,
                );
        })();
    final overlays = dslDefinition?.overlays ?? const <_RouteNode>[];

    return _RouteNode(
      idExpression:
          (isLocation || isOverlay) && classElement.displayName != 'Scope'
          ? await _resolveIdExpression(
              _namedArgumentExpression(
                expression.argumentList.arguments,
                'id',
              ),
              evaluationContext: evaluationContext,
            )
          : null,
      localIdExpression: await _resolveIdExpression(
        _namedArgumentExpression(
          expression.argumentList.arguments,
          'localId',
        ),
        evaluationContext: evaluationContext,
      ),
      isLocation: isLocation,
      isOverlay: isOverlay,
      isRoutableLocation: _isRoutableLocationLikeClass(classElement),
      locationTypeSource: classElement.displayName,
      pathSegments: pathSegments,
      queryParameters: queryParameters,
      overlays: overlays,
      children: children,
    );
  }

  Future<_ResolvedDslDefinition?> _resolveDslDefinition({
    required InterfaceElement classElement,
    required InstanceCreationExpression creation,
    required _ExpressionContext evaluationContext,
    required bool isLocation,
    required bool supportsPathAndQuery,
  }) async {
    final directBuildExpression = _namedArgumentExpression(
      creation.argumentList.arguments,
      'build',
    );
    if (directBuildExpression != null) {
      return _resolveDslDefinitionFromExpression(
        directBuildExpression,
        evaluationContext: evaluationContext,
        isLocation: isLocation,
        supportsPathAndQuery: supportsPathAndQuery,
      );
    }

    if (classElement.displayName == 'Location' ||
        classElement.displayName == 'AbstractLocation' ||
        classElement.displayName == 'ShellLocation' ||
        classElement.displayName == 'AbstractShellLocation' ||
        classElement.displayName == 'MultiShellLocation' ||
        classElement.displayName == 'AbstractMultiShellLocation' ||
        classElement.displayName == 'MultiShell' ||
        classElement.displayName == 'AbstractMultiShell' ||
        classElement.displayName == 'Overlay' ||
        classElement.displayName == 'AbstractOverlay' ||
        classElement.displayName == 'Scope' ||
        classElement.displayName == 'AbstractScope' ||
        classElement.displayName == 'Shell' ||
        classElement.displayName == 'AbstractShell') {
      return null;
    }

    final buildMethod = classElement.lookUpMethod(
      name: 'build',
      library: classElement.library,
    );
    if (buildMethod == null ||
        buildMethod.enclosingElement?.displayName == 'Location' ||
        buildMethod.enclosingElement?.displayName == 'AbstractLocation' ||
        buildMethod.enclosingElement?.displayName == 'ShellLocation' ||
        buildMethod.enclosingElement?.displayName == 'AbstractShellLocation' ||
        buildMethod.enclosingElement?.displayName == 'MultiShellLocation' ||
        buildMethod.enclosingElement?.displayName ==
            'AbstractMultiShellLocation' ||
        buildMethod.enclosingElement?.displayName == 'MultiShell' ||
        buildMethod.enclosingElement?.displayName == 'AbstractMultiShell' ||
        buildMethod.enclosingElement?.displayName == 'Overlay' ||
        buildMethod.enclosingElement?.displayName == 'AbstractOverlay' ||
        buildMethod.enclosingElement?.displayName == 'Scope' ||
        buildMethod.enclosingElement?.displayName == 'AbstractScope' ||
        buildMethod.enclosingElement?.displayName == 'Shell' ||
        buildMethod.enclosingElement?.displayName == 'AbstractShell') {
      return null;
    }

    final node = await buildStep.resolver.astNodeFor(
      buildMethod.firstFragment,
      resolve: true,
    );
    if (node is! MethodDeclaration) {
      throw InvalidGenerationSourceError(
        'Unsupported build(...) declaration in `${classElement.name}`.',
        element: buildMethod,
      );
    }

    final builderParameterName = _buildCallbackBuilderParameterName(
      node.parameters?.parameters,
    );
    if (builderParameterName == null) {
      throw InvalidGenerationSourceError(
        'build(...) on `${classElement.name}` must take the builder as its '
        'first parameter, optionally followed by location/scope/shell '
        'context parameters.',
        element: buildMethod,
      );
    }

    return _resolveDslDefinitionFromBody(
      body: node.body,
      builderParameterName: builderParameterName,
      evaluationContext: evaluationContext,
      elementForErrors: buildMethod,
      isLocation: isLocation,
      supportsPathAndQuery: supportsPathAndQuery,
    );
  }

  Future<_ResolvedDslDefinition> _resolveDslDefinitionFromExpression(
    Expression expression, {
    required _ExpressionContext evaluationContext,
    required bool isLocation,
    required bool supportsPathAndQuery,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is FunctionExpression) {
      final builderParameterName = _buildCallbackBuilderParameterName(
        normalizedExpression.parameters?.parameters,
      );
      if (builderParameterName == null) {
        throw InvalidGenerationSourceError(
          'Route build callbacks must take the builder as their first '
          'parameter, optionally followed by location/scope/shell context '
          'parameters.',
          element: rootElement,
        );
      }
      return _resolveDslDefinitionFromBody(
        body: normalizedExpression.body,
        builderParameterName: builderParameterName,
        evaluationContext: evaluationContext,
        elementForErrors: rootElement,
        isLocation: isLocation,
        supportsPathAndQuery: supportsPathAndQuery,
      );
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final node = await buildStep.resolver.astNodeFor(
        _fragmentFor(_normalizeDeclarationElement(referencedElement)),
        resolve: true,
      );
      if (node is FunctionDeclaration) {
        final builderParameterName = _buildCallbackBuilderParameterName(
          node.functionExpression.parameters?.parameters,
        );
        if (builderParameterName == null) {
          throw InvalidGenerationSourceError(
            'Route build helpers must take the builder as their first '
            'parameter, optionally followed by location/scope/shell context '
            'parameters.',
            element: referencedElement,
          );
        }
        return _resolveDslDefinitionFromBody(
          body: node.functionExpression.body,
          builderParameterName: builderParameterName,
          evaluationContext: evaluationContext,
          elementForErrors: referencedElement,
          isLocation: isLocation,
          supportsPathAndQuery: supportsPathAndQuery,
        );
      }
    }

    throw InvalidGenerationSourceError(
      'Unsupported route build expression `${normalizedExpression.toSource()}`.',
      element: rootElement,
    );
  }

  Future<_ResolvedDslDefinition> _resolveDslDefinitionFromBody({
    required FunctionBody body,
    required String builderParameterName,
    required _ExpressionContext evaluationContext,
    required Element elementForErrors,
    required bool isLocation,
    required bool supportsPathAndQuery,
  }) async {
    final context = _DslStatementContext(parent: evaluationContext);
    final result = _ResolvedDslDefinition.empty();

    if (body is ExpressionFunctionBody) {
      result.children.addAll(
        await _locationsFromListExpression(
          body.expression,
          evaluationContext: context,
        ),
      );
      return result;
    }
    if (body is! BlockFunctionBody) {
      throw InvalidGenerationSourceError(
        'Only block-bodied build(...) definitions are supported.',
        element: elementForErrors,
      );
    }

    for (final statement in body.block.statements) {
      await _resolveDslStatement(
        statement,
        builderParameterName: builderParameterName,
        context: context,
        result: result,
        elementForErrors: elementForErrors,
        isLocation: isLocation,
        supportsPathAndQuery: supportsPathAndQuery,
      );
    }

    return result;
  }

  Future<void> _resolveDslStatement(
    Statement statement, {
    required String builderParameterName,
    required _DslStatementContext context,
    required _ResolvedDslDefinition result,
    required Element elementForErrors,
    required bool isLocation,
    required bool supportsPathAndQuery,
  }) async {
    switch (statement) {
      case ExpressionStatement():
        if (await _resolveDslOverlaysAssignment(
          statement.expression,
          builderParameterName: builderParameterName,
          context: context,
          result: result,
        )) {
          return;
        }
        if (await _resolveDslChildrenAssignment(
          statement.expression,
          builderParameterName: builderParameterName,
          context: context,
          result: result,
          elementForErrors: elementForErrors,
        )) {
          return;
        }
        if (await _resolveDslBoundAssignment(
          statement.expression,
          builderParameterName: builderParameterName,
          context: context,
          result: result,
          elementForErrors: elementForErrors,
          isLocation: isLocation,
          supportsPathAndQuery: supportsPathAndQuery,
        )) {
          return;
        }
        await _resolveDslExpression(
          statement.expression,
          variableName: null,
          builderParameterName: builderParameterName,
          context: context,
          result: result,
          elementForErrors: elementForErrors,
          isLocation: isLocation,
          supportsPathAndQuery: supportsPathAndQuery,
        );
      case VariableDeclarationStatement():
        for (final variable in statement.variables.variables) {
          final initializer = variable.initializer;
          if (initializer == null) {
            continue;
          }
          context.bind(variable.name.lexeme, initializer);
          await _resolveDslExpression(
            initializer,
            variableName: variable.name.lexeme,
            builderParameterName: builderParameterName,
            context: context,
            result: result,
            elementForErrors: elementForErrors,
            isLocation: isLocation,
            supportsPathAndQuery: supportsPathAndQuery,
          );
        }
      case Block():
        final blockContext = context.child();
        for (final nestedStatement in statement.statements) {
          await _resolveDslStatement(
            nestedStatement,
            builderParameterName: builderParameterName,
            context: blockContext,
            result: result,
            elementForErrors: elementForErrors,
            isLocation: isLocation,
            supportsPathAndQuery: supportsPathAndQuery,
          );
        }
      case IfStatement():
        final branchGroupId = _nextExclusiveBranchGroupId++;
        final thenResult = result.copy();
        await _resolveDslStatement(
          statement.thenStatement,
          builderParameterName: builderParameterName,
          context: context.child(),
          result: thenResult,
          elementForErrors: elementForErrors,
          isLocation: isLocation,
          supportsPathAndQuery: supportsPathAndQuery,
        );
        _markExclusiveBranchChildren(
          baseline: result,
          branchResult: thenResult,
          groupId: branchGroupId,
          branchId: 0,
        );
        result.merge(thenResult);
        final elseStatement = statement.elseStatement;
        if (elseStatement != null) {
          final elseResult = result.copy();
          await _resolveDslStatement(
            elseStatement,
            builderParameterName: builderParameterName,
            context: context.child(),
            result: elseResult,
            elementForErrors: elementForErrors,
            isLocation: isLocation,
            supportsPathAndQuery: supportsPathAndQuery,
          );
          _markExclusiveBranchChildren(
            baseline: result,
            branchResult: elseResult,
            groupId: branchGroupId,
            branchId: 1,
          );
          result.merge(elseResult);
        }
      case ReturnStatement():
        final expression = statement.expression;
        if (expression != null) {
          result.children.addAll(
            await _locationsFromListExpression(
              expression,
              evaluationContext: context,
            ),
          );
        }
        return;
      default:
        return;
    }
  }

  Future<bool> _resolveDslChildrenAssignment(
    Expression expression, {
    required String builderParameterName,
    required _DslStatementContext context,
    required _ResolvedDslDefinition result,
    required Element elementForErrors,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is! AssignmentExpression ||
        normalizedExpression.operator.lexeme != '=') {
      return false;
    }

    final target = normalizedExpression.leftHandSide;
    final isBuilderChildren = switch (target) {
      PrefixedIdentifier(:final prefix, :final identifier) =>
        prefix.name == builderParameterName && identifier.name == 'children',
      PropertyAccess(:final target?, :final propertyName) =>
        target is SimpleIdentifier &&
            target.name == builderParameterName &&
            propertyName.name == 'children',
      _ => false,
    };
    if (!isBuilderChildren) {
      return false;
    }

    result.children.addAll(
      await _locationsFromListExpression(
        normalizedExpression.rightHandSide,
        evaluationContext: context,
      ),
    );
    return true;
  }

  Future<bool> _resolveDslOverlaysAssignment(
    Expression expression, {
    required String builderParameterName,
    required _DslStatementContext context,
    required _ResolvedDslDefinition result,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is! AssignmentExpression ||
        normalizedExpression.operator.lexeme != '=') {
      return false;
    }

    final target = normalizedExpression.leftHandSide;
    final isBuilderOverlays = switch (target) {
      PrefixedIdentifier(:final prefix, :final identifier) =>
        prefix.name == builderParameterName && identifier.name == 'overlays',
      PropertyAccess(:final target?, :final propertyName) =>
        target is SimpleIdentifier &&
            target.name == builderParameterName &&
            propertyName.name == 'overlays',
      _ => false,
    };
    if (!isBuilderOverlays) {
      return false;
    }

    result.overlays.addAll(
      await _locationsFromListExpression(
        normalizedExpression.rightHandSide,
        evaluationContext: context,
      ),
    );
    return true;
  }

  void _markExclusiveBranchChildren({
    required _ResolvedDslDefinition baseline,
    required _ResolvedDslDefinition branchResult,
    required int groupId,
    required int branchId,
  }) {
    final markedOverlays = [
      for (final overlay in branchResult.overlays.skip(
        baseline.overlays.length,
      ))
        overlay.withExclusiveBranch(groupId, branchId),
    ];
    for (var i = 0; i < markedOverlays.length; i++) {
      branchResult.overlays[baseline.overlays.length + i] = markedOverlays[i];
    }
    final markedChildren = _withExclusiveBranchSelection(
      branchResult.children.skip(baseline.children.length),
      groupId,
      branchId,
    );
    for (var i = 0; i < markedChildren.length; i++) {
      branchResult.children[baseline.children.length + i] = markedChildren[i];
    }
  }

  List<_RouteNode> _withExclusiveBranchSelection(
    Iterable<_RouteNode> nodes,
    int groupId,
    int branchId,
  ) {
    return [
      for (final node in nodes) node.withExclusiveBranch(groupId, branchId),
    ];
  }

  Future<bool> _resolveDslBoundAssignment(
    Expression expression, {
    required String builderParameterName,
    required _DslStatementContext context,
    required _ResolvedDslDefinition result,
    required Element elementForErrors,
    required bool isLocation,
    required bool supportsPathAndQuery,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is! AssignmentExpression ||
        normalizedExpression.operator.lexeme != '=') {
      return false;
    }

    final targetName = _assignmentTargetName(
      normalizedExpression.leftHandSide,
    );
    if (targetName == null) {
      return false;
    }

    final rightHandSide = normalizedExpression.rightHandSide;
    context.bind(targetName, rightHandSide);
    await _resolveDslExpression(
      rightHandSide,
      variableName: targetName,
      builderParameterName: builderParameterName,
      context: context,
      result: result,
      elementForErrors: elementForErrors,
      isLocation: isLocation,
      supportsPathAndQuery: supportsPathAndQuery,
    );
    return true;
  }

  Future<void> _resolveDslExpression(
    Expression expression, {
    required String? variableName,
    required String builderParameterName,
    required _DslStatementContext context,
    required _ResolvedDslDefinition result,
    required Element elementForErrors,
    required bool isLocation,
    required bool supportsPathAndQuery,
  }) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is! MethodInvocation ||
        !_isBuilderInvocation(normalizedExpression, builderParameterName)) {
      _throwIfNestedBuilderDeclaration(
        normalizedExpression,
        builderParameterName: builderParameterName,
      );
      return;
    }

    switch (normalizedExpression.methodName.name) {
      case 'pathSegment':
        if (!supportsPathAndQuery) {
          return;
        }
        final segmentExpression = normalizedExpression.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (segmentExpression == null) {
          throw InvalidGenerationSourceError(
            'pathSegment(...) requires a PathSegment.',
            element: elementForErrors,
          );
        }
        final segmentMetadata = await _pathSegmentMetadata(
          segmentExpression,
          elementForErrors,
          evaluationContext: context,
        );
        result.pathSegments.add(
          segmentMetadata is _RoutePathParameterSegmentMetadata
              ? _RoutePathParameterSegmentMetadata(
                  key: segmentMetadata.key,
                  dartTypeSource: segmentMetadata.dartTypeSource,
                  codecExpressionSource: segmentMetadata.codecExpressionSource,
                  memberName: segmentMetadata.memberName,
                  pathParameterIndex:
                      segmentMetadata.pathParameterIndex ??
                      result.pathParameterCount,
                  sourceNode: segmentMetadata.sourceNode,
                  sourceElement: segmentMetadata.sourceElement,
                )
              : segmentMetadata,
        );
        if (segmentMetadata is _RoutePathParameterSegmentMetadata) {
          result.pathParameterCount += 1;
        }
      case 'pathLiteral':
        if (!supportsPathAndQuery) {
          return;
        }
        final valueExpression = normalizedExpression.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (valueExpression == null) {
          throw InvalidGenerationSourceError(
            'pathLiteral(...) requires a string value.',
            element: elementForErrors,
          );
        }
        result.pathSegments.add(
          _LiteralPathSegmentMetadata(
            value: _stringLiteral(valueExpression, elementForErrors),
          ),
        );
      case 'pathParam':
      case 'stringPathParam':
      case 'intPathParam':
      case 'doublePathParam':
      case 'boolPathParam':
      case 'dateTimePathParam':
      case 'uriPathParam':
      case 'enumPathParam':
        if (!supportsPathAndQuery) {
          return;
        }
        final codecMetadata = _dslPathParamCodecMetadata(
          normalizedExpression,
          elementForErrors,
        );
        if (codecMetadata == null) {
          throw InvalidGenerationSourceError(
            '${normalizedExpression.methodName.name}(...) requires a codec.',
            element: elementForErrors,
          );
        }
        if (variableName == null) {
          throw InvalidGenerationSourceError(
            'Store the result of ${normalizedExpression.methodName.name}(...) '
            'in a local variable so '
            'generated route helpers can name that parameter.',
            element: elementForErrors,
          );
        }
        result.pathSegments.add(
          _RoutePathParameterSegmentMetadata(
            key: _stripParamSuffix(variableName),
            dartTypeSource: codecMetadata.dartTypeSource,
            codecExpressionSource: codecMetadata.codecExpressionSource,
            pathParameterIndex: result.pathParameterCount,
            sourceNode: normalizedExpression,
            sourceElement: elementForErrors,
          ),
        );
        result.pathParameterCount += 1;
      case 'queryParam':
      case 'defaultQueryParam':
      case 'stringQueryParam':
      case 'defaultStringQueryParam':
      case 'nullableStringQueryParam':
      case 'intQueryParam':
      case 'defaultIntQueryParam':
      case 'nullableIntQueryParam':
      case 'doubleQueryParam':
      case 'defaultDoubleQueryParam':
      case 'nullableDoubleQueryParam':
      case 'boolQueryParam':
      case 'defaultBoolQueryParam':
      case 'nullableBoolQueryParam':
      case 'dateTimeQueryParam':
      case 'defaultDateTimeQueryParam':
      case 'nullableDateTimeQueryParam':
      case 'uriQueryParam':
      case 'defaultUriQueryParam':
      case 'nullableUriQueryParam':
      case 'enumQueryParam':
      case 'defaultEnumQueryParam':
      case 'nullableEnumQueryParam':
        if (!supportsPathAndQuery) {
          return;
        }
        final queryParameterMetadata = _dslQueryParamMetadata(
          normalizedExpression,
          elementForErrors,
        );
        if (queryParameterMetadata == null) {
          throw InvalidGenerationSourceError(
            '${normalizedExpression.methodName.name}(...) requires a name '
            'and a codec.',
            element: elementForErrors,
          );
        }
        _registerQueryParameterMetadata(
          queryParameterMetadata,
          result.queryParameters,
          element: elementForErrors,
        );
      case 'bindParam':
      case 'bindQueryParam':
      case 'bindDefaultQueryParam':
        if (!supportsPathAndQuery) {
          return;
        }
        final parameterExpression = normalizedExpression.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (parameterExpression == null) {
          throw InvalidGenerationSourceError(
            'bindParam(...) requires an UnboundParam.',
            element: elementForErrors,
          );
        }
        final boundParameterMetadata = await _dslBoundParamMetadata(
          parameterExpression,
          elementForErrors,
          evaluationContext: context,
        );
        if (boundParameterMetadata == null) {
          throw InvalidGenerationSourceError(
            'bindParam(...) requires an UnboundPathParam or '
            'UnboundQueryParam.',
            element: elementForErrors,
          );
        }
        if (boundParameterMetadata.isPath) {
          if (variableName == null) {
            throw InvalidGenerationSourceError(
              'Store the result of bindParam(...) for unbound path params in '
              'a local variable so generated route helpers can name that '
              'parameter.',
              element: elementForErrors,
            );
          }
          result.pathSegments.add(
            _RoutePathParameterSegmentMetadata(
              key: _stripParamSuffix(variableName),
              dartTypeSource: boundParameterMetadata.dartTypeSource,
              codecExpressionSource:
                  boundParameterMetadata.codecExpressionSource,
              pathParameterIndex: result.pathParameterCount,
              sourceNode: boundParameterMetadata.sourceNode,
              sourceElement: boundParameterMetadata.sourceElement,
            ),
          );
          result.pathParameterCount += 1;
          return;
        }
        _registerQueryParameterMetadata(
          _RouteQueryParameterMetadata(
            key: boundParameterMetadata.queryKey!,
            dartTypeSource: boundParameterMetadata.dartTypeSource,
            codecExpressionSource: boundParameterMetadata.codecExpressionSource,
            optional: boundParameterMetadata.optional,
            sourceNode: boundParameterMetadata.sourceNode,
            sourceElement: boundParameterMetadata.sourceElement,
          ),
          result.queryParameters,
          element: elementForErrors,
        );
      case 'id':
        if (!isLocation) {
          return;
        }
        final idExpression = normalizedExpression.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (idExpression == null) {
          throw InvalidGenerationSourceError(
            'id(...) requires a route id value.',
            element: elementForErrors,
          );
        }
        if (result.locationIdExpression != null) {
          throw InvalidGenerationSourceError(
            'id(...) may only be called once per inline location.',
            element: elementForErrors,
          );
        }
        result.locationIdExpression = await _resolveIdExpression(
          idExpression,
          evaluationContext: context,
        );
      case 'localId':
        final localIdExpression = normalizedExpression.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (localIdExpression == null) {
          throw InvalidGenerationSourceError(
            'localId(...) requires a route local id value.',
            element: elementForErrors,
          );
        }
        if (result.locationLocalIdExpression != null) {
          throw InvalidGenerationSourceError(
            'localId(...) may only be called once per inline route node.',
            element: elementForErrors,
          );
        }
        result.locationLocalIdExpression = await _resolveIdExpression(
          localIdExpression,
          evaluationContext: context,
        );
      case 'child':
        final childExpression = normalizedExpression.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (childExpression == null) {
          throw InvalidGenerationSourceError(
            'child(...) requires a RouteNode.',
            element: elementForErrors,
          );
        }
        result.children.add(
          await _locationFromExpression(
            childExpression,
            evaluationContext: context,
          ),
        );
      case 'location':
        result.children.add(
          await _routeNodeFromBuilderInvocation(
            normalizedExpression,
            evaluationContext: context,
            isLocation: true,
            supportsPathAndQuery: true,
            elementForErrors: elementForErrors,
          ),
        );
      case 'shell':
        result.children.add(
          await _routeNodeFromBuilderInvocation(
            normalizedExpression,
            evaluationContext: context,
            isLocation: false,
            supportsPathAndQuery: true,
            elementForErrors: elementForErrors,
          ),
        );
      default:
        return;
    }
  }

  Future<_RouteNode> _routeNodeFromBuilderInvocation(
    MethodInvocation invocation, {
    required _ExpressionContext evaluationContext,
    required bool isLocation,
    required bool supportsPathAndQuery,
    required Element elementForErrors,
  }) async {
    final arguments = invocation.argumentList.arguments;
    final buildExpression =
        _namedArgumentExpression(arguments, 'build') ??
        arguments.whereType<Expression>().firstOrNull;
    if (buildExpression == null) {
      throw InvalidGenerationSourceError(
        '${invocation.methodName.name}(...) requires a build callback.',
        element: elementForErrors,
      );
    }

    final dslDefinition = await _resolveDslDefinitionFromExpression(
      buildExpression,
      evaluationContext: evaluationContext,
      isLocation: isLocation,
      supportsPathAndQuery: supportsPathAndQuery,
    );

    return _RouteNode(
      idExpression: isLocation
          ? dslDefinition.locationIdExpression ??
                await _resolveIdExpression(
                  _namedArgumentExpression(arguments, 'id'),
                  evaluationContext: evaluationContext,
                )
          : null,
      localIdExpression:
          dslDefinition.locationLocalIdExpression ??
          await _resolveIdExpression(
            _namedArgumentExpression(arguments, 'localId'),
            evaluationContext: evaluationContext,
          ),
      isLocation: isLocation,
      isOverlay: false,
      isRoutableLocation: isLocation,
      locationTypeSource: isLocation ? 'Location' : 'Shell',
      pathSegments: supportsPathAndQuery
          ? dslDefinition.pathSegments
          : const <_PathSegmentMetadata>[],
      queryParameters: supportsPathAndQuery
          ? dslDefinition.queryParameters
          : const <String, _RouteQueryParameterMetadata>{},
      overlays: dslDefinition.overlays,
      children: dslDefinition.children,
    );
  }

  bool _isBuilderInvocation(
    MethodInvocation invocation,
    String builderParameterName,
  ) {
    return switch (invocation.realTarget) {
      final SimpleIdentifier identifier =>
        identifier.name == builderParameterName,
      _ => false,
    };
  }

  void _throwIfNestedBuilderDeclaration(
    Expression expression, {
    required String builderParameterName,
  }) {
    final invocation = _NestedBuilderDeclarationFinder.find(
      expression,
      builderParameterName: builderParameterName,
    );
    if (invocation == null) {
      return;
    }

    throw InvalidGenerationSourceError(
      'Builder route declarations must be direct statements or local '
      'initializers in build(...). Found nested '
      '`${invocation.toSource()}` inside an unsupported expression. '
      'Declare each location parameter unconditionally in the location that '
      'reads it; fallback declarations such as '
      '`existingParam ?? ${invocation.toSource()}` are not supported by '
      'generated route helpers.',
      node: invocation,
    );
  }

  _DslCodecMetadata? _dslPathParamCodecMetadata(
    MethodInvocation invocation,
    Element elementForErrors,
  ) {
    final methodName = invocation.methodName.name;
    return switch (methodName) {
      'pathParam' => (() {
        final codecExpression = invocation.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (codecExpression == null) {
          return null;
        }
        return _DslCodecMetadata(
          dartTypeSource: _codecValueTypeSourceForExpression(
            codecExpression,
            elementForErrors,
          ),
          codecExpressionSource: _expressionSource(codecExpression),
        );
      })(),
      'stringPathParam' => const _DslCodecMetadata(
        dartTypeSource: 'String',
        codecExpressionSource: 'const StringRouteParamCodec()',
      ),
      'intPathParam' => const _DslCodecMetadata(
        dartTypeSource: 'int',
        codecExpressionSource: 'const IntRouteParamCodec()',
      ),
      'doublePathParam' => const _DslCodecMetadata(
        dartTypeSource: 'double',
        codecExpressionSource: 'const DoubleRouteParamCodec()',
      ),
      'boolPathParam' => const _DslCodecMetadata(
        dartTypeSource: 'bool',
        codecExpressionSource: 'const BoolRouteParamCodec()',
      ),
      'dateTimePathParam' => const _DslCodecMetadata(
        dartTypeSource: 'DateTime',
        codecExpressionSource: 'const DateTimeIsoRouteParamCodec()',
      ),
      'uriPathParam' => const _DslCodecMetadata(
        dartTypeSource: 'Uri',
        codecExpressionSource: 'const UriRouteParamCodec()',
      ),
      'enumPathParam' => (() {
        final valuesExpression = invocation.argumentList.arguments
            .whereType<Expression>()
            .firstOrNull;
        if (valuesExpression == null) {
          return null;
        }
        return _DslCodecMetadata(
          dartTypeSource: _enumValuesTypeSourceForExpression(
            valuesExpression,
            elementForErrors,
          ),
          codecExpressionSource:
              'EnumRouteParamCodec(${_expressionSource(valuesExpression)})',
        );
      })(),
      _ => null,
    };
  }

  _RouteQueryParameterMetadata? _dslQueryParamMetadata(
    MethodInvocation invocation,
    Element elementForErrors,
  ) {
    final arguments = invocation.argumentList.arguments
        .whereType<Expression>()
        .toList(growable: false);
    final namedArguments = {
      for (final argument
          in invocation.argumentList.arguments.whereType<NamedExpression>())
        argument.name.label.name: argument.expression,
    };
    final methodName = invocation.methodName.name;
    switch (methodName) {
      case 'queryParam':
      case 'defaultQueryParam':
        if (arguments.length < 2) {
          return null;
        }
        if (methodName == 'queryParam' &&
            namedArguments.containsKey('defaultValue')) {
          throw InvalidGenerationSourceError(
            'queryParam(...) no longer accepts defaultValue. Use '
            'defaultQueryParam(...) for query parameters with defaults.',
            element: elementForErrors,
          );
        }
        final defaultValueExpression = methodName == 'defaultQueryParam'
            ? namedArguments['defaultValue']
            : null;
        final codecValueTypeSource = _codecValueTypeSourceForExpression(
          arguments[1],
          elementForErrors,
        );
        return _RouteQueryParameterMetadata(
          key: _stringLiteral(arguments[0], elementForErrors),
          dartTypeSource: _queryParameterTypeSource(
            codecValueTypeSource,
            defaultValueExpression,
          ),
          codecExpressionSource: _expressionSource(arguments[1]),
          optional: methodName == 'defaultQueryParam',
          sourceNode: invocation,
          sourceElement: elementForErrors,
        );
      case 'stringQueryParam':
      case 'defaultStringQueryParam':
      case 'nullableStringQueryParam':
      case 'intQueryParam':
      case 'defaultIntQueryParam':
      case 'nullableIntQueryParam':
      case 'doubleQueryParam':
      case 'defaultDoubleQueryParam':
      case 'nullableDoubleQueryParam':
      case 'boolQueryParam':
      case 'defaultBoolQueryParam':
      case 'nullableBoolQueryParam':
      case 'dateTimeQueryParam':
      case 'defaultDateTimeQueryParam':
      case 'nullableDateTimeQueryParam':
      case 'uriQueryParam':
      case 'defaultUriQueryParam':
      case 'nullableUriQueryParam':
      case 'enumQueryParam':
      case 'defaultEnumQueryParam':
      case 'nullableEnumQueryParam':
        final nameExpression = arguments.firstOrNull;
        if (nameExpression == null) {
          return null;
        }
        final codecMetadata = switch (methodName) {
          'stringQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'String',
            codecExpressionSource: 'const StringRouteParamCodec()',
          ),
          'defaultStringQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'String',
            codecExpressionSource: 'const StringRouteParamCodec()',
          ),
          'nullableStringQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'String?',
            codecExpressionSource: 'const StringRouteParamCodec()',
          ),
          'intQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'int',
            codecExpressionSource: 'const IntRouteParamCodec()',
          ),
          'defaultIntQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'int',
            codecExpressionSource: 'const IntRouteParamCodec()',
          ),
          'nullableIntQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'int?',
            codecExpressionSource: 'const IntRouteParamCodec()',
          ),
          'doubleQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'double',
            codecExpressionSource: 'const DoubleRouteParamCodec()',
          ),
          'defaultDoubleQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'double',
            codecExpressionSource: 'const DoubleRouteParamCodec()',
          ),
          'nullableDoubleQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'double?',
            codecExpressionSource: 'const DoubleRouteParamCodec()',
          ),
          'boolQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'bool',
            codecExpressionSource: 'const BoolRouteParamCodec()',
          ),
          'defaultBoolQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'bool',
            codecExpressionSource: 'const BoolRouteParamCodec()',
          ),
          'nullableBoolQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'bool?',
            codecExpressionSource: 'const BoolRouteParamCodec()',
          ),
          'dateTimeQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'DateTime',
            codecExpressionSource: 'const DateTimeIsoRouteParamCodec()',
          ),
          'defaultDateTimeQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'DateTime',
            codecExpressionSource: 'const DateTimeIsoRouteParamCodec()',
          ),
          'nullableDateTimeQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'DateTime?',
            codecExpressionSource: 'const DateTimeIsoRouteParamCodec()',
          ),
          'uriQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'Uri',
            codecExpressionSource: 'const UriRouteParamCodec()',
          ),
          'defaultUriQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'Uri',
            codecExpressionSource: 'const UriRouteParamCodec()',
          ),
          'nullableUriQueryParam' => const _DslCodecMetadata(
            dartTypeSource: 'Uri?',
            codecExpressionSource: 'const UriRouteParamCodec()',
          ),
          'enumQueryParam' => (() {
            final valuesExpression = arguments.length >= 2
                ? arguments[1]
                : null;
            if (valuesExpression == null) {
              return null;
            }
            return _DslCodecMetadata(
              dartTypeSource: _enumValuesTypeSourceForExpression(
                valuesExpression,
                elementForErrors,
              ),
              codecExpressionSource:
                  'EnumRouteParamCodec(${_expressionSource(valuesExpression)})',
            );
          })(),
          'defaultEnumQueryParam' => (() {
            final valuesExpression = arguments.length >= 2
                ? arguments[1]
                : null;
            if (valuesExpression == null) {
              return null;
            }
            return _DslCodecMetadata(
              dartTypeSource: _enumValuesTypeSourceForExpression(
                valuesExpression,
                elementForErrors,
              ),
              codecExpressionSource:
                  'EnumRouteParamCodec(${_expressionSource(valuesExpression)})',
            );
          })(),
          'nullableEnumQueryParam' => (() {
            final valuesExpression = arguments.length >= 2
                ? arguments[1]
                : null;
            if (valuesExpression == null) {
              return null;
            }
            return _DslCodecMetadata(
              dartTypeSource:
                  '${_enumValuesTypeSourceForExpression(valuesExpression, elementForErrors)}?',
              codecExpressionSource:
                  'EnumRouteParamCodec(${_expressionSource(valuesExpression)})',
            );
          })(),
          _ => null,
        };
        if (codecMetadata == null) {
          return null;
        }
        if (!methodName.startsWith('default') &&
            namedArguments.containsKey('defaultValue')) {
          throw InvalidGenerationSourceError(
            '$methodName(...) no longer accepts defaultValue. Use '
            'default${methodName.substring(0, 1).toUpperCase()}'
            '${methodName.substring(1)}(...) for query parameters with '
            'defaults.',
            element: elementForErrors,
          );
        }
        final defaultValueExpression = methodName.startsWith('default')
            ? namedArguments['defaultValue']
            : null;
        return _RouteQueryParameterMetadata(
          key: _stringLiteral(nameExpression, elementForErrors),
          dartTypeSource: _queryParameterTypeSource(
            codecMetadata.dartTypeSource,
            defaultValueExpression,
          ),
          codecExpressionSource: codecMetadata.codecExpressionSource,
          optional:
              defaultValueExpression != null ||
              methodName.startsWith('default') ||
              methodName.startsWith('nullable'),
          sourceNode: invocation,
          sourceElement: elementForErrors,
        );
      default:
        return null;
    }
  }

  Future<_DslBoundParamMetadata?> _dslBoundParamMetadata(
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
        return _dslBoundParamMetadata(
          boundExpression,
          element,
          evaluationContext: evaluationContext,
        );
      }
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final targetExpression = await _declarationExpression(referencedElement);
      return _dslBoundParamMetadata(
        targetExpression,
        referencedElement,
        evaluationContext: evaluationContext,
      );
    }

    if (normalizedExpression is! InstanceCreationExpression) {
      return null;
    }

    final typeName = normalizedExpression.constructorName.type
        .toSource()
        .split('<')
        .first;
    final positionalArguments = normalizedExpression.argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .whereType<Expression>()
        .toList(growable: false);

    switch (typeName) {
      case 'UnboundPathParam':
        var codecExpression = positionalArguments.firstOrNull;
        if (codecExpression == null) {
          return null;
        }
        if (evaluationContext != null &&
            _canResolveThroughContext(_unwrapExpression(codecExpression))) {
          final boundCodecExpression = await evaluationContext
              .resolveExpression(
                _unwrapExpression(codecExpression),
              );
          if (boundCodecExpression != null) {
            codecExpression = boundCodecExpression;
          }
        }
        return _DslBoundParamMetadata(
          isPath: true,
          dartTypeSource: _codecValueTypeSourceForExpression(
            codecExpression,
            element,
          ),
          codecExpressionSource: _expressionSource(codecExpression),
          optional: false,
          sourceNode: normalizedExpression,
          sourceElement: element,
        );
      case 'UnboundQueryParam':
      case 'RequiredUnboundQueryParam':
      case 'DefaultUnboundQueryParam':
        var keyExpression = positionalArguments.firstOrNull;
        var codecExpression = positionalArguments.skip(1).firstOrNull;
        final defaultValueExpression = _namedArgumentExpression(
          normalizedExpression.argumentList.arguments,
          'defaultValue',
        );
        if (keyExpression == null || codecExpression == null) {
          return null;
        }
        if (evaluationContext != null &&
            _canResolveThroughContext(_unwrapExpression(keyExpression))) {
          final boundKeyExpression = await evaluationContext.resolveExpression(
            _unwrapExpression(keyExpression),
          );
          if (boundKeyExpression != null) {
            keyExpression = boundKeyExpression;
          }
        }
        if (evaluationContext != null &&
            _canResolveThroughContext(_unwrapExpression(codecExpression))) {
          final boundCodecExpression = await evaluationContext
              .resolveExpression(
                _unwrapExpression(codecExpression),
              );
          if (boundCodecExpression != null) {
            codecExpression = boundCodecExpression;
          }
        }
        return _DslBoundParamMetadata(
          isPath: false,
          queryKey: _stringLiteral(keyExpression, element),
          dartTypeSource: _queryParameterTypeSource(
            _codecValueTypeSourceForExpression(
              codecExpression,
              element,
            ),
            defaultValueExpression,
          ),
          codecExpressionSource: _expressionSource(codecExpression),
          optional:
              defaultValueExpression != null ||
              typeName == 'DefaultUnboundQueryParam',
          sourceNode: normalizedExpression,
          sourceElement: element,
        );
      default:
        return null;
    }
  }

  String _queryParameterTypeSource(
    String codecValueTypeSource,
    Expression? defaultValueExpression,
  ) {
    if (_defaultValueExpressionIsNull(defaultValueExpression)) {
      return _nullableTypeSource(codecValueTypeSource);
    }
    return codecValueTypeSource;
  }

  bool _defaultValueExpressionIsNull(Expression? expression) {
    if (expression == null) {
      return false;
    }

    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is NullLiteral) {
      return true;
    }

    return _expressionIsNull(normalizedExpression);
  }

  bool _expressionIsNull(Expression expression) {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is NullLiteral) {
      return true;
    }

    final constantValue = normalizedExpression.computeConstantValue();
    final value = constantValue?.value;
    if (value != null) {
      return value.isNull;
    }

    return false;
  }

  String _stripParamSuffix(String value) {
    for (final suffix in ['Parameter', 'Param']) {
      if (value.endsWith(suffix) && value.length > suffix.length) {
        return value.substring(0, value.length - suffix.length);
      }
    }
    return value;
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
      node: normalizedExpression,
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
        final thenResult = await _locationsFromCollectionElement(
          element.thenElement,
          evaluationContext: evaluationContext,
        );
        final elseElement = element.elseElement;
        if (elseElement == null) {
          result.addAll(thenResult);
          return result;
        }
        final branchGroupId = _nextExclusiveBranchGroupId++;
        result.addAll(
          _withExclusiveBranchSelection(thenResult, branchGroupId, 0),
        );
        result.addAll(
          _withExclusiveBranchSelection(
            await _locationsFromCollectionElement(
              elseElement,
              evaluationContext: evaluationContext,
            ),
            branchGroupId,
            1,
          ),
        );
        return result;
      default:
        throw InvalidGenerationSourceError(
          'Unsupported list element `${element.toSource()}` in the location '
          'tree.',
          node: element,
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
          node: normalizedExpression,
        );
      }
      final resolvedExpression = await evaluationContext.resolveIdExpression(
        normalizedExpression,
      );
      if (resolvedExpression != null) {
        return _resolveIdExpression(
          resolvedExpression,
          evaluationContext: evaluationContext,
        );
      }

      final conditionResult = await _evaluateNullableIdConditionFromContext(
        normalizedExpression.condition,
        evaluationContext,
      );
      return _resolveIdExpression(
        conditionResult
            ? normalizedExpression.thenExpression
            : normalizedExpression.elseExpression,
        evaluationContext: evaluationContext,
      );
    }

    return normalizedExpression.toSource();
  }

  Future<bool> _evaluateNullableIdConditionFromContext(
    Expression expression,
    _ExpressionContext evaluationContext,
  ) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is SimpleIdentifier) {
      final boundExpression = await _lookupNamedExpressionInContext(
        normalizedExpression.name,
        evaluationContext,
      );
      if (boundExpression != null &&
          boundExpression.expression.toSource() !=
              normalizedExpression.toSource()) {
        return _evaluateNullableIdConditionFromContext(
          boundExpression.expression,
          boundExpression.context,
        );
      }
    }
    final resolvedExpression =
        await evaluationContext.resolveIdExpression(normalizedExpression) ??
        await evaluationContext.resolveExpression(normalizedExpression);
    if (resolvedExpression != null &&
        resolvedExpression.toSource() != normalizedExpression.toSource()) {
      return _evaluateNullableIdConditionFromContext(
        resolvedExpression,
        evaluationContext,
      );
    }

    final constantValue = normalizedExpression.computeConstantValue();
    final boolValue = constantValue?.value?.toBoolValue();
    if (boolValue != null) {
      return boolValue;
    }

    if (normalizedExpression is! BinaryExpression) {
      throw InvalidGenerationSourceError(
        _unsupportedConditionalIdMessage(normalizedExpression),
        node: normalizedExpression,
      );
    }

    final operator = normalizedExpression.operator.lexeme;
    if (operator != '!=' && operator != '==') {
      throw InvalidGenerationSourceError(
        _unsupportedConditionalIdMessage(normalizedExpression),
        node: normalizedExpression,
      );
    }

    final left = normalizedExpression.leftOperand;
    final right = normalizedExpression.rightOperand;
    if (left is NullLiteral) {
      final targetIsNull = await _evaluateIdConditionValueIsNull(
        right,
        evaluationContext,
      );
      return operator == '!=' ? !targetIsNull : targetIsNull;
    }
    if (right is NullLiteral) {
      final targetIsNull = await _evaluateIdConditionValueIsNull(
        left,
        evaluationContext,
      );
      return operator == '!=' ? !targetIsNull : targetIsNull;
    }

    throw InvalidGenerationSourceError(
      _unsupportedConditionalIdMessage(normalizedExpression),
      node: normalizedExpression,
    );
  }

  Future<bool> _evaluateIdConditionValueIsNull(
    Expression expression,
    _ExpressionContext evaluationContext,
  ) async {
    final normalizedExpression = _unwrapExpression(expression);
    final resolvedExpression =
        await evaluationContext.resolveIdExpression(normalizedExpression) ??
        await evaluationContext.resolveExpression(normalizedExpression);
    if (resolvedExpression != null &&
        resolvedExpression.toSource() != normalizedExpression.toSource()) {
      return _evaluateIdConditionValueIsNull(
        resolvedExpression,
        evaluationContext,
      );
    }

    if (normalizedExpression is NullLiteral) {
      return true;
    }

    final constantValue = normalizedExpression.computeConstantValue();
    final value = constantValue?.value;
    if (value != null) {
      return value.isNull;
    }

    final referencedElement = _topLevelOrStaticDeclarationElement(
      normalizedExpression,
    );
    if (referencedElement != null) {
      final declarationExpression = await _declarationExpression(
        referencedElement,
      );
      if (declarationExpression.toSource() != normalizedExpression.toSource()) {
        return _evaluateIdConditionValueIsNull(
          declarationExpression,
          evaluationContext,
        );
      }
    }

    if (normalizedExpression is SimpleIdentifier) {
      final namedResult = await _evaluateNamedValueIsNullInContext(
        normalizedExpression.name,
        evaluationContext,
      );
      if (namedResult != null) {
        return namedResult;
      }
    }
    if (normalizedExpression is PrefixedIdentifier &&
        normalizedExpression.prefix.name == 'this') {
      final fieldResult = await _evaluateFieldIsNullInContext(
        normalizedExpression.identifier.name,
        evaluationContext,
      );
      if (fieldResult != null) {
        return fieldResult;
      }
    }
    if (normalizedExpression is PropertyAccess &&
        normalizedExpression.realTarget is ThisExpression) {
      final fieldResult = await _evaluateFieldIsNullInContext(
        normalizedExpression.propertyName.name,
        evaluationContext,
      );
      if (fieldResult != null) {
        return fieldResult;
      }
    }

    final contextualResult = await _evaluateExpressionIsNullInContext(
      normalizedExpression,
      evaluationContext,
    );
    if (contextualResult != null) {
      return contextualResult;
    }

    return false;
  }

  Future<bool?> _evaluateNamedValueIsNullInContext(
    String name,
    _ExpressionContext? evaluationContext,
  ) async {
    if (evaluationContext == null) {
      return null;
    }
    if (evaluationContext case _DslStatementContext(
      :final _bindings,
      :final parent,
    )) {
      final binding = _bindings[name];
      if (binding != null && binding.toSource() != name) {
        return _evaluateIdConditionValueIsNull(binding, evaluationContext);
      }
      return _evaluateNamedValueIsNullInContext(name, parent);
    }
    if (evaluationContext case _InstanceStringContext()) {
      return evaluationContext._evaluateNamedValueIsNull(name);
    }
    if (evaluationContext case _FunctionExpressionContext(
      :final parameterBindings,
      :final parentContext,
    )) {
      final binding = parameterBindings[name];
      if (binding != null && binding.toSource() != name) {
        return _evaluateIdConditionValueIsNull(binding, evaluationContext);
      }
      return _evaluateNamedValueIsNullInContext(name, parentContext);
    }
    return null;
  }

  Future<bool?> _evaluateFieldIsNullInContext(
    String name,
    _ExpressionContext? evaluationContext,
  ) async {
    if (evaluationContext == null) {
      return null;
    }
    if (evaluationContext case _DslStatementContext(:final parent)) {
      return _evaluateFieldIsNullInContext(name, parent);
    }
    if (evaluationContext case _InstanceStringContext()) {
      return evaluationContext._evaluateFieldIsNull(name);
    }
    if (evaluationContext case _FunctionExpressionContext(
      :final parentContext,
    )) {
      return _evaluateFieldIsNullInContext(name, parentContext);
    }
    return null;
  }

  Future<bool?> _evaluateExpressionIsNullInContext(
    Expression expression,
    _ExpressionContext? evaluationContext,
  ) async {
    if (evaluationContext == null) {
      return null;
    }
    if (evaluationContext case _DslStatementContext(:final parent)) {
      return _evaluateExpressionIsNullInContext(expression, parent);
    }
    if (evaluationContext case _InstanceStringContext()) {
      return evaluationContext._evaluateIsNull(expression);
    }
    if (evaluationContext case _FunctionExpressionContext()) {
      return evaluationContext._evaluateIsNull(expression);
    }
    return null;
  }

  Future<_ResolvedContextExpression?> _lookupNamedExpressionInContext(
    String name,
    _ExpressionContext? evaluationContext,
  ) async {
    if (evaluationContext == null) {
      return null;
    }
    if (evaluationContext case _DslStatementContext(
      :final _bindings,
      :final parent,
    )) {
      final binding = _bindings[name];
      if (binding != null) {
        return _ResolvedContextExpression(
          expression: binding,
          context: evaluationContext,
        );
      }
      return _lookupNamedExpressionInContext(name, parent);
    }
    if (evaluationContext case _InstanceStringContext()) {
      final parameterBinding = evaluationContext.parameterBindings[name];
      if (parameterBinding != null) {
        return _ResolvedContextExpression(
          expression: parameterBinding.expression,
          context: evaluationContext,
        );
      }
      final fieldExpression = await evaluationContext._fieldExpression(name);
      if (fieldExpression != null && fieldExpression.toSource() != name) {
        return _ResolvedContextExpression(
          expression: fieldExpression,
          context: evaluationContext,
        );
      }
      if (evaluationContext._hasUnboundConstructorParameter(name)) {
        return null;
      }
      return _lookupNamedExpressionInContext(
        name,
        evaluationContext.parentContext,
      );
    }
    if (evaluationContext case _FunctionExpressionContext(
      :final parameterBindings,
      :final parentContext,
    )) {
      final binding = parameterBindings[name];
      if (binding != null) {
        return _ResolvedContextExpression(
          expression: binding,
          context: evaluationContext,
        );
      }
      return _lookupNamedExpressionInContext(name, parentContext);
    }
    return null;
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
    if (getter == null ||
        _isFrameworkRouteMemberOwner(getter.enclosingElement)) {
      return const <_PathSegmentMetadata>[];
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
    if (getter != null &&
        !_isFrameworkRouteMemberOwner(getter.enclosingElement)) {
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
      return _queryParameterListLiteral(
        expression,
        getter,
        evaluationContext: evaluationContext,
      );
    }

    return const <String, _RouteQueryParameterMetadata>{};
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
        'Inline builder.pathParam(...) calls in path are not supported. '
        'Prefer the builder DSL and keep the returned param in a local inside '
        'build(...), or use a static literal-only path getter.',
        element: element,
      );
    }

    if (normalizedExpression is MethodInvocation &&
        normalizedExpression.methodName.name == 'literal') {
      final valueExpression = normalizedExpression.argumentList.arguments
          .whereType<Expression>()
          .firstOrNull;
      if (valueExpression == null) {
        throw InvalidGenerationSourceError(
          'literal(...) requires a string value.',
          element: element,
        );
      }
      return _LiteralPathSegmentMetadata(
        value: _stringLiteral(valueExpression, element),
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
        'Prefer the builder DSL and declare the path param through '
        'builder.pathParam(...).',
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
      key: _pathParameterRouteKey(fieldElement.displayName),
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
        'Only builder-declared path params are supported for generated path '
        'params.',
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
      sourceElement: element,
    );
  }

  String _pathParameterRouteKey(String memberName) {
    for (final suffix in ['Parameter', 'Param']) {
      if (memberName.endsWith(suffix) && memberName.length > suffix.length) {
        return memberName.substring(0, memberName.length - suffix.length);
      }
    }
    return memberName;
  }

  Future<Map<String, _RouteQueryParameterMetadata>> _queryParameterListLiteral(
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
        return _queryParameterListLiteral(
          boundExpression,
          element,
          evaluationContext: evaluationContext,
        );
      }
    }

    if (normalizedExpression is ListLiteral) {
      final result = <String, _RouteQueryParameterMetadata>{};
      for (final item in normalizedExpression.elements) {
        final metadataByKey = await _queryParametersFromListElement(
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
      return _queryParameterListLiteral(
        helperInvocation.expression,
        element,
        evaluationContext: helperInvocation.context,
      );
    }

    final referencedElement = _expressionElement(normalizedExpression);
    if (referencedElement != null) {
      final targetExpression = await _declarationExpression(referencedElement);
      return _queryParameterListLiteral(
        targetExpression,
        referencedElement,
        evaluationContext: evaluationContext,
      );
    }

    throw InvalidGenerationSourceError(
      'Only literal query parameter lists are supported.',
      element: element,
    );
  }

  Future<Map<String, _RouteQueryParameterMetadata>>
  _queryParametersFromListElement(
    CollectionElement element, {
    required Element elementForErrors,
    _ExpressionContext? evaluationContext,
  }) async {
    switch (element) {
      case Expression():
        final metadata = await _queryParameterMetadata(
          element,
          element: elementForErrors,
          evaluationContext: evaluationContext,
        );
        return {metadata.key: metadata};
      case SpreadElement():
        return _queryParameterListLiteral(
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
          final branchMetadata = await _queryParametersFromListElement(
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

    final positionalArguments = normalizedExpression.argumentList.arguments
        .where((argument) => argument is! NamedExpression)
        .whereType<Expression>()
        .toList(growable: false);
    final keyExpression = positionalArguments.firstOrNull;
    final codecExpression =
        _namedArgumentExpression(
          normalizedExpression.argumentList.arguments,
          'codec',
        ) ??
        positionalArguments.skip(1).firstOrNull;
    final defaultValueExpression = _namedArgumentExpression(
      normalizedExpression.argumentList.arguments,
      'defaultValue',
    );
    if (keyExpression == null || codecExpression == null) {
      throw InvalidGenerationSourceError(
        'QueryParam requires a string name and a codec.',
        element: element,
      );
    }

    var resolvedKeyExpression = keyExpression;
    if (evaluationContext != null &&
        _canResolveThroughContext(_unwrapExpression(keyExpression))) {
      final boundKeyExpression = await evaluationContext.resolveExpression(
        _unwrapExpression(keyExpression),
      );
      if (boundKeyExpression != null) {
        resolvedKeyExpression = boundKeyExpression;
      }
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
      key: _stringLiteral(resolvedKeyExpression, element),
      dartTypeSource: _queryParameterTypeSource(
        _codecValueTypeSourceForExpression(
          resolvedCodecExpression,
          element,
        ),
        defaultValueExpression,
      ),
      codecExpressionSource: _expressionSource(resolvedCodecExpression),
      optional: defaultValueExpression != null,
      sourceNode: normalizedExpression,
      sourceElement: element,
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
      node: metadata.sourceNode,
      element: metadata.sourceNode == null
          ? metadata.sourceElement ?? element
          : null,
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
    if (codecTypeName == 'EnumRouteParamCodec') {
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

  String _enumValuesTypeSourceForExpression(
    Expression valuesExpression,
    Element element,
  ) {
    final valuesType = valuesExpression.staticType;
    if (valuesType is InterfaceType) {
      if (valuesType.typeArguments.length == 1) {
        return valuesType.typeArguments.single.getDisplayString();
      }

      final iterableType = _supertypeNamed(valuesType, 'Iterable');
      if (iterableType != null && iterableType.typeArguments.length == 1) {
        return iterableType.typeArguments.single.getDisplayString();
      }
    }

    throw InvalidGenerationSourceError(
      'Enum param shortcuts require a concrete enum values list.',
      element: element,
    );
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

  String? _assignmentTargetName(Expression expression) {
    final normalizedExpression = _unwrapExpression(expression);
    return switch (normalizedExpression) {
      SimpleIdentifier() => normalizedExpression.name,
      PrefixedIdentifier(:final prefix, :final identifier)
          when prefix.name == 'this' =>
        identifier.name,
      PropertyAccess(:final realTarget, :final propertyName)
          when realTarget is ThisExpression =>
        propertyName.name,
      _ => null,
    };
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

  bool _isLocationLikeClass(InterfaceElement classElement) {
    InterfaceType? current = classElement.thisType;
    while (current != null) {
      if (current.element.name == 'Location' ||
          current.element.name == 'AbstractLocation' ||
          current.element.name == 'ShellLocation' ||
          current.element.name == 'AbstractShellLocation' ||
          current.element.name == 'MultiShellLocation' ||
          current.element.name == 'AbstractMultiShellLocation' ||
          current.element.name == 'AbstractScope' ||
          current.element.name == 'Scope') {
        return true;
      }
      current = current.element.supertype;
    }
    return false;
  }

  bool _isRoutableLocationLikeClass(InterfaceElement classElement) {
    InterfaceType? current = classElement.thisType;
    while (current != null) {
      if (current.element.name == 'Location' ||
          current.element.name == 'AbstractLocation' ||
          current.element.name == 'ShellLocation' ||
          current.element.name == 'AbstractShellLocation' ||
          current.element.name == 'MultiShellLocation' ||
          current.element.name == 'AbstractMultiShellLocation' ||
          current.element.name == 'Overlay' ||
          current.element.name == 'AbstractOverlay') {
        return true;
      }
      current = current.element.supertype;
    }
    return false;
  }

  bool _isOverlayLikeClass(InterfaceElement classElement) {
    InterfaceType? current = classElement.thisType;
    while (current != null) {
      if (current.element.name == 'Overlay' ||
          current.element.name == 'AbstractOverlay') {
        return true;
      }
      current = current.element.supertype;
    }
    return false;
  }

  bool _isShellLikeClass(InterfaceElement classElement) {
    InterfaceType? current = classElement.thisType;
    while (current != null) {
      if (current.element.name == 'Shell' ||
          current.element.name == 'ShellLocation' ||
          current.element.name == 'MultiShellLocation' ||
          current.element.name == 'AbstractMultiShellLocation' ||
          current.element.name == 'MultiShell' ||
          current.element.name == 'AbstractMultiShell' ||
          current.element.name == 'AbstractShell') {
        return true;
      }
      current = current.element.supertype;
    }
    return false;
  }
}

bool _isFrameworkRouteMemberOwner(Element? element) {
  final ownerName = element?.displayName;
  return ownerName == 'RouteNode' ||
      ownerName == 'PathRouteNode' ||
      ownerName == 'AnyOverlay' ||
      ownerName == 'AnyLocation' ||
      ownerName == 'AbstractOverlay' ||
      ownerName == 'AbstractLocation' ||
      ownerName == 'AbstractShellLocation' ||
      ownerName == 'AbstractMultiShellLocation' ||
      ownerName == 'AbstractMultiShell' ||
      ownerName == 'AbstractScope' ||
      ownerName == 'AbstractShell' ||
      ownerName == 'Scope' ||
      ownerName == 'Overlay' ||
      ownerName == 'Location' ||
      ownerName == 'ShellLocation' ||
      ownerName == 'MultiShellLocation' ||
      ownerName == 'MultiShell' ||
      ownerName == 'Shell';
}

abstract class _ExpressionContext {
  Future<Expression?> resolveExpression(Expression expression);

  Future<Expression?> resolveIdExpression(Expression expression);
}

class _NoopExpressionContext implements _ExpressionContext {
  @override
  Future<Expression?> resolveExpression(Expression expression) async => null;

  @override
  Future<Expression?> resolveIdExpression(Expression expression) async => null;
}

class _ResolvedHelperInvocation {
  final Expression expression;
  final _ExpressionContext context;

  const _ResolvedHelperInvocation({
    required this.expression,
    required this.context,
  });
}

class _ResolvedContextExpression {
  final Expression expression;
  final _ExpressionContext context;

  const _ResolvedContextExpression({
    required this.expression,
    required this.context,
  });
}

class _ResolvedDslDefinition {
  String? locationIdExpression;
  String? locationLocalIdExpression;
  final List<_PathSegmentMetadata> pathSegments;
  final Map<String, _RouteQueryParameterMetadata> queryParameters;
  final List<_RouteNode> overlays;
  final List<_RouteNode> children;
  int pathParameterCount;

  _ResolvedDslDefinition({
    required this.locationIdExpression,
    required this.locationLocalIdExpression,
    required this.pathSegments,
    required this.queryParameters,
    required this.overlays,
    required this.children,
    required this.pathParameterCount,
  });

  factory _ResolvedDslDefinition.empty() {
    return _ResolvedDslDefinition(
      locationIdExpression: null,
      locationLocalIdExpression: null,
      pathSegments: <_PathSegmentMetadata>[],
      queryParameters: <String, _RouteQueryParameterMetadata>{},
      overlays: <_RouteNode>[],
      children: <_RouteNode>[],
      pathParameterCount: 0,
    );
  }

  _ResolvedDslDefinition copy() {
    return _ResolvedDslDefinition(
      locationIdExpression: locationIdExpression,
      locationLocalIdExpression: locationLocalIdExpression,
      pathSegments: [...pathSegments],
      queryParameters: {...queryParameters},
      overlays: [...overlays],
      children: [...children],
      pathParameterCount: pathParameterCount,
    );
  }

  void merge(_ResolvedDslDefinition other) {
    locationIdExpression ??= other.locationIdExpression;
    locationLocalIdExpression ??= other.locationLocalIdExpression;
    if (pathSegments.isEmpty) {
      pathSegments.addAll(other.pathSegments);
    }
    queryParameters.addAll(other.queryParameters);
    overlays.addAll(other.overlays);
    children.addAll(other.children);
    if (other.pathParameterCount > pathParameterCount) {
      pathParameterCount = other.pathParameterCount;
    }
  }
}

class _DslStatementContext implements _ExpressionContext {
  final _ExpressionContext? parent;
  final Map<String, Expression> _bindings;

  _DslStatementContext({
    required this.parent,
    Map<String, Expression>? bindings,
  }) : _bindings = bindings ?? <String, Expression>{};

  void bind(String name, Expression expression) {
    _bindings[name] = expression;
  }

  _DslStatementContext child() {
    return _DslStatementContext(
      parent: parent,
      bindings: Map<String, Expression>.from(_bindings),
    );
  }

  @override
  Future<Expression?> resolveExpression(Expression expression) async {
    var normalizedExpression = expression;
    while (normalizedExpression is ParenthesizedExpression) {
      normalizedExpression = normalizedExpression.expression;
    }
    if (normalizedExpression is SimpleIdentifier) {
      final binding = _bindings[normalizedExpression.name];
      if (binding != null) {
        return binding;
      }
    }
    return parent?.resolveExpression(expression);
  }

  @override
  Future<Expression?> resolveIdExpression(Expression expression) async {
    var normalizedExpression = expression;
    while (normalizedExpression is ParenthesizedExpression) {
      normalizedExpression = normalizedExpression.expression;
    }
    if (normalizedExpression is ConditionalExpression) {
      return null;
    }
    if (normalizedExpression is SimpleIdentifier) {
      final binding = _bindings[normalizedExpression.name];
      if (binding != null) {
        return binding;
      }
    }
    return parent?.resolveIdExpression(expression);
  }
}

class _InstanceStringContext implements _ExpressionContext {
  final BuildStep buildStep;
  final Element rootElement;
  final InterfaceElement resolutionStartClassElement;
  final InterfaceElement classElement;
  final ConstructorElement constructor;
  final ConstructorDeclaration? constructorNode;
  final Map<String, _BoundStringExpression> parameterBindings;
  final _ExpressionContext? parentContext;

  _InstanceStringContext({
    required this.buildStep,
    required this.rootElement,
    required this.resolutionStartClassElement,
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
      if (!constructor.isSynthetic ||
          creation.argumentList.arguments.isNotEmpty) {
        throw InvalidGenerationSourceError(
          'Unable to read the constructor source for `${classElement.name}`.',
          element: constructor,
        );
      }
    }

    final context = _InstanceStringContext(
      buildStep: buildStep,
      rootElement: rootElement,
      resolutionStartClassElement: classElement,
      classElement: classElement,
      constructor: constructor,
      constructorNode: constructorNode,
      parameterBindings: {},
      parentContext: parentContext,
    );
    if (constructorNode != null) {
      context.parameterBindings.addAll(
        context._bindArguments(
          parameters: constructorNode.parameters,
          arguments: creation.argumentList.arguments,
        ),
      );
    }
    return context;
  }

  Iterable<FormalParameter> get _constructorParameters =>
      constructorNode?.parameters.parameters ?? const <FormalParameter>[];

  Iterable<ConstructorInitializer> get _constructorInitializers =>
      constructorNode?.initializers ?? const <ConstructorInitializer>[];

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

      if (_hasUnboundConstructorParameter(normalizedExpression.name)) {
        return null;
      }
    }
    if (normalizedExpression is PrefixedIdentifier &&
        normalizedExpression.prefix.name == 'this') {
      final fieldExpression = await _fieldExpression(
        normalizedExpression.identifier.name,
      );
      if (fieldExpression != null &&
          fieldExpression.toSource() != normalizedExpression.toSource()) {
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
      if (_hasUnboundConstructorParameter(
        normalizedExpression.identifier.name,
      )) {
        return null;
      }
    }
    if (normalizedExpression is PropertyAccess &&
        normalizedExpression.realTarget is ThisExpression) {
      final fieldExpression = await _fieldExpression(
        normalizedExpression.propertyName.name,
      );
      if (fieldExpression != null &&
          fieldExpression.toSource() != normalizedExpression.toSource()) {
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
      if (_hasUnboundConstructorParameter(
        normalizedExpression.propertyName.name,
      )) {
        return null;
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
      final fieldExpression = await _fieldExpression(normalizedExpression.name);
      if (fieldExpression != null &&
          fieldExpression.toSource() != normalizedExpression.toSource()) {
        return _resolveIdExpression(fieldExpression, visited);
      }
      if (_hasUnboundConstructorParameter(normalizedExpression.name)) {
        return null;
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
    if (normalizedExpression is PrefixedIdentifier &&
        normalizedExpression.prefix.name == 'this') {
      final fieldExpression = await _fieldExpression(
        normalizedExpression.identifier.name,
      );
      if (fieldExpression != null &&
          fieldExpression.toSource() != normalizedExpression.toSource()) {
        return _resolveIdExpression(fieldExpression, visited);
      }
      if (_hasUnboundConstructorParameter(
        normalizedExpression.identifier.name,
      )) {
        return null;
      }
    }
    if (normalizedExpression is PropertyAccess &&
        normalizedExpression.realTarget is ThisExpression) {
      final fieldExpression = await _fieldExpression(
        normalizedExpression.propertyName.name,
      );
      if (fieldExpression != null &&
          fieldExpression.toSource() != normalizedExpression.toSource()) {
        return _resolveIdExpression(fieldExpression, visited);
      }
      if (_hasUnboundConstructorParameter(
        normalizedExpression.propertyName.name,
      )) {
        return null;
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

  bool _hasUnboundConstructorParameter(String name) {
    if (parameterBindings.containsKey(name)) {
      return false;
    }

    return _constructorParameters.any((parameter) {
      return _formalParameterName(parameter) == name;
    });
  }

  FormalParameter? _forwardingConstructorParameter(String name) {
    final parameter = _constructorParameters.firstWhereOrNull((parameter) {
      return _formalParameterName(parameter) == name;
    });
    if (parameter == null) {
      return null;
    }

    final unwrapped = _unwrapFormalParameter(parameter);
    if (unwrapped is FieldFormalParameter ||
        unwrapped is SuperFormalParameter) {
      return parameter;
    }
    return null;
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

  Future<_InstanceStringContext?> _superContext({
    String? memberName,
    required String resolutionKind,
  }) async {
    final supertype = classElement.supertype;
    if (supertype == null) {
      return null;
    }
    if (supertype.isDartCoreObject) {
      return null;
    }

    final superInvocation = _constructorInitializers
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
      if (!superConstructor.isSynthetic ||
          (superInvocation?.argumentList.arguments.isNotEmpty ?? false)) {
        throw InvalidGenerationSourceError(
          _unreadableSuperConstructorMessage(
            _interfaceElementName(supertype.element),
            memberName: memberName,
            resolutionKind: resolutionKind,
          ),
          element: superConstructor,
        );
      }
    }

    final context = _InstanceStringContext(
      buildStep: buildStep,
      rootElement: rootElement,
      resolutionStartClassElement: resolutionStartClassElement,
      classElement: supertype.element,
      constructor: superConstructor,
      constructorNode: superConstructorNode,
      parameterBindings: {},
      parentContext: parentContext,
    );
    if (superConstructorNode != null) {
      context.parameterBindings.addAll(
        context._bindArguments(
          parameters: superConstructorNode.parameters,
          arguments: superInvocation?.argumentList.arguments ?? const [],
        ),
      );
    }
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
        _unsupportedConditionalIdMessage(normalizedExpression),
        node: normalizedExpression,
      );
    }

    final operator = normalizedExpression.operator.lexeme;
    if (operator != '!=' && operator != '==') {
      throw InvalidGenerationSourceError(
        _unsupportedConditionalIdMessage(normalizedExpression),
        node: normalizedExpression,
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
      _unsupportedConditionalIdMessage(normalizedExpression),
      node: normalizedExpression,
    );
  }

  String _unsupportedConditionalIdMessage(Expression expression) {
    return 'Only `id != null ? ... : null` style conditional ids are '
        'supported, but got condition `${expression.toSource()}`.';
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
    final forwardingParameter = _forwardingConstructorParameter(name);
    if (forwardingParameter != null) {
      final binding = parameterBindings[name];
      if (binding != null) {
        return binding.evaluate();
      }
      if (forwardingParameter is DefaultFormalParameter &&
          forwardingParameter.defaultValue != null) {
        return _evaluateStringExpression(forwardingParameter.defaultValue!);
      }
    }

    final field = classElement.getField(name);
    if (field != null) {
      final fieldInitializer = _constructorInitializers
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

    final superContext = await _superContext(
      memberName: name,
      resolutionKind: 'resolving its value',
    );
    if (superContext != null) {
      return superContext._evaluateField(name);
    }

    throw InvalidGenerationSourceError(
      _unresolvedMemberMessage(
        name,
        resolutionKind: 'resolving its value',
      ),
      element: classElement,
    );
  }

  Future<Expression?> _fieldExpression(String name) async {
    final forwardingParameter = _forwardingConstructorParameter(name);
    if (forwardingParameter != null) {
      final binding = parameterBindings[name];
      if (binding != null) {
        return binding.expression;
      }
      if (forwardingParameter is DefaultFormalParameter &&
          forwardingParameter.defaultValue != null) {
        return forwardingParameter.defaultValue;
      }
      return null;
    }

    final field = classElement.getField(name);
    if (field != null) {
      final fieldFormalParameter = _constructorParameters.firstWhereOrNull(
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

      final fieldInitializer = _constructorInitializers
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
        getter.enclosingElement != classElement.supertype?.element &&
        !_isFrameworkRouteMemberOwner(getter.enclosingElement)) {
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

    final parameter = _constructorParameters.firstWhereOrNull((
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
    final forwardingParameter = _forwardingConstructorParameter(name);
    if (forwardingParameter != null) {
      final binding = parameterBindings[name];
      if (binding != null) {
        return binding.isNull();
      }
      if (forwardingParameter is DefaultFormalParameter) {
        final defaultValue = forwardingParameter.defaultValue;
        if (defaultValue == null) {
          return true;
        }
        return _evaluateIsNull(defaultValue);
      }
      return false;
    }

    final field = classElement.getField(name);
    if (field != null) {
      final fieldInitializer = _constructorInitializers
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

    final superContext = await _superContext(
      memberName: name,
      resolutionKind: 'evaluating whether it is null',
    );
    if (superContext != null) {
      return superContext._evaluateNamedValueIsNull(name);
    }

    throw InvalidGenerationSourceError(
      _unresolvedMemberMessage(
        name,
        resolutionKind: 'evaluating whether it is null',
      ),
      element: classElement,
    );
  }

  String _unresolvedMemberMessage(
    String name, {
    required String resolutionKind,
  }) {
    return 'Unable to resolve inherited member `$name` while '
        '$resolutionKind from '
        '`${_interfaceElementName(resolutionStartClassElement)}`. '
        'This usually means the generator hit an inherited alias or getter '
        'that hides the real route value. The generator supports direct '
        '`id`/`localId` checks and local aliases in the same `build(...)` '
        'method, but it does not reliably follow inherited aliases across '
        'base classes. Inline the expression instead, for example '
        '`id != null` or `final hasIds = id != null` inside `build(...)`. '
        'Superclass chain: `${_inheritanceChainLabel()}`.';
  }

  String _unreadableSuperConstructorMessage(
    String superTypeName, {
    String? memberName,
    required String resolutionKind,
  }) {
    final memberClause = memberName == null
        ? ''
        : ' for inherited member `$memberName`';
    return 'Unable to read the constructor source for `$superTypeName` while '
        '$resolutionKind$memberClause from '
        '`${_interfaceElementName(resolutionStartClassElement)}`. '
        'This usually means the generator had to walk into an inherited alias '
        'or getter and ran out of readable source while following the '
        'superclass chain `${_inheritanceChainLabel()}`. Inline the '
        'expression instead. For route ids, prefer direct `id != null` checks '
        'or a local alias like `final hasIds = id != null` in the same '
        '`build(...)` method.';
  }

  String _inheritanceChainLabel() {
    final names = <String>[
      _interfaceElementName(resolutionStartClassElement),
    ];
    var current = resolutionStartClassElement.supertype;
    while (current != null) {
      names.add(_interfaceElementName(current.element));
      if (current.isDartCoreObject) {
        break;
      }
      current = current.element.supertype;
    }
    return names.join(' -> ');
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

  Future<bool> _evaluateIsNull(Expression expression) async {
    final normalizedExpression = _unwrapExpression(expression);
    if (normalizedExpression is NullLiteral) {
      return true;
    }
    if (normalizedExpression is SimpleIdentifier) {
      final boundExpression = parameterBindings[normalizedExpression.name];
      if (boundExpression != null) {
        return _evaluateIsNull(boundExpression);
      }
      final parentExpression = await parentContext?.resolveExpression(
        normalizedExpression,
      );
      if (parentExpression != null &&
          parentExpression.toSource() != normalizedExpression.toSource()) {
        return _evaluateIsNull(parentExpression);
      }
    }

    final constantValue = normalizedExpression.computeConstantValue();
    final value = constantValue?.value;
    if (value != null) {
      return value.isNull;
    }

    final parent = parentContext;
    if (parent is _InstanceStringContext) {
      return parent._evaluateIsNull(normalizedExpression);
    }
    if (parent is _FunctionExpressionContext) {
      return parent._evaluateIsNull(normalizedExpression);
    }

    return false;
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

String _interfaceElementName(InterfaceElement element) {
  return element.name ?? element.displayName;
}

Element? _topLevelOrStaticDeclarationElement(Expression expression) {
  Element? element = switch (expression) {
    SimpleIdentifier() => expression.element,
    PrefixedIdentifier() => expression.identifier.element,
    PropertyAccess() => expression.propertyName.element,
    _ => null,
  };

  if (element is PropertyAccessorElement && element.isSynthetic) {
    element = element.variable;
  }

  final enclosingElement = element?.enclosingElement;
  final isTopLevel = enclosingElement is LibraryElement;
  final isStatic = switch (element) {
    PropertyInducingElement(:final isStatic) => isStatic,
    ExecutableElement(:final isStatic) => isStatic,
    _ => false,
  };

  if (!isTopLevel && !isStatic) {
    return null;
  }

  return switch (element) {
    PropertyInducingElement() => element,
    ExecutableElement() => element,
    _ => null,
  };
}

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

String? _buildCallbackBuilderParameterName(
  Iterable<FormalParameter>? parameters,
) {
  final parameterList = parameters?.toList(growable: false);
  if (parameterList == null ||
      parameterList.isEmpty ||
      parameterList.length > 3) {
    return null;
  }
  return _formalParameterName(parameterList.first);
}

Future<ConstructorDeclaration?> _constructorDeclaration({
  required BuildStep buildStep,
  required InterfaceElement classElement,
  required ConstructorElement constructor,
}) async {
  AstNode? classNode;
  try {
    classNode = await buildStep.resolver.astNodeFor(
      classElement.firstFragment,
      resolve: true,
    );
  } on TypeError {
    // ignore: avoid_catching_errors
    // `build_runner` may fail to materialize AST nodes for dependency sources.
    // Treat those constructors as unavailable so the caller can either fall
    // back or raise a normal generation error instead of crashing.
    return null;
  }
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
  final String? localIdExpression;
  final bool isLocation;
  final bool isOverlay;
  final bool isRoutableLocation;
  final String locationTypeSource;
  final Map<int, int> exclusiveBranchSelections;
  final List<_PathSegmentMetadata> pathSegments;
  final Map<String, _RouteQueryParameterMetadata> queryParameters;
  final List<_RouteNode> overlays;
  final List<_RouteNode> children;

  const _RouteNode({
    required this.idExpression,
    required this.localIdExpression,
    required this.isLocation,
    required this.isOverlay,
    required this.isRoutableLocation,
    required this.locationTypeSource,
    this.exclusiveBranchSelections = const {},
    required this.pathSegments,
    required this.queryParameters,
    required this.overlays,
    required this.children,
  });

  _RouteNode withExclusiveBranch(int groupId, int branchId) {
    return _RouteNode(
      idExpression: idExpression,
      localIdExpression: localIdExpression,
      isLocation: isLocation,
      isOverlay: isOverlay,
      isRoutableLocation: isRoutableLocation,
      locationTypeSource: locationTypeSource,
      exclusiveBranchSelections: {
        ...exclusiveBranchSelections,
        groupId: branchId,
      },
      pathSegments: pathSegments,
      queryParameters: queryParameters,
      overlays: [
        for (final overlay in overlays)
          overlay.withExclusiveBranch(groupId, branchId),
      ],
      children: [
        for (final child in children)
          child.withExclusiveBranch(groupId, branchId),
      ],
    );
  }
}

class _GeneratedRouteMethod {
  final String name;
  final String targetClassName;
  final String? idExpression;
  final String? childLocationMatchSource;
  final List<_GeneratedPathWrite> pathWrites;
  final List<_GeneratedPathWrite> queryWrites;
  final Map<String, _GeneratedRouteParameter> pathParameters;
  final Map<String, _GeneratedRouteParameter> queryParameters;

  const _GeneratedRouteMethod._({
    required this.name,
    required this.targetClassName,
    required this.idExpression,
    required this.childLocationMatchSource,
    required this.pathWrites,
    required this.queryWrites,
    required this.pathParameters,
    required this.queryParameters,
  });

  factory _GeneratedRouteMethod.toId({
    required String name,
    required String targetClassName,
    required String idExpression,
    required List<_GeneratedPathWrite> pathWrites,
    required List<_GeneratedPathWrite> queryWrites,
    required Map<String, _GeneratedRouteParameter> pathParameters,
    required Map<String, _GeneratedRouteParameter> queryParameters,
  }) {
    return _GeneratedRouteMethod._(
      name: name,
      targetClassName: targetClassName,
      idExpression: idExpression,
      childLocationMatchSource: null,
      pathWrites: pathWrites,
      queryWrites: queryWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  bool isEquivalent(_GeneratedRouteMethod other) {
    return _generatedTargetDefinitionEquivalent(
      name: name,
      targetClassName: targetClassName,
      idExpression: idExpression,
      childLocationMatchSource: childLocationMatchSource,
      pathWrites: pathWrites,
      queryWrites: queryWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      otherName: other.name,
      otherTargetClassName: other.targetClassName,
      otherIdExpression: other.idExpression,
      otherChildLocationMatchSource: other.childLocationMatchSource,
      otherPathWrites: other.pathWrites,
      otherQueryWrites: other.queryWrites,
      otherPathParameters: other.pathParameters,
      otherQueryParameters: other.queryParameters,
    );
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
          ? _nullableTypeSource(generatedParameter.dartTypeSource)
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
    if (idExpression != null) {
      buffer.writeln(
        'final class $targetClassName extends IdRouteTarget {',
      );
    } else {
      buffer.writeln(
        'final class $targetClassName extends ChildRouteTarget {',
      );
    }

    if (parameters.isEmpty) {
      buffer.writeln('  $targetClassName()');
    } else {
      buffer.writeln('  $targetClassName({');
      for (final parameter in parameters) {
        final generatedParameter = parameter.value;
        final typeSource = generatedParameter.optional
            ? _nullableTypeSource(generatedParameter.dartTypeSource)
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
        pathWrite.locationMatchDiscriminator,
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
        '          (location) => $childLocationMatchSource,',
      );
    }

    if (pathWrites.isNotEmpty) {
      buffer.writeln('          writePathParameters: (() {');
      for (final entry in pathWritesByLocationType.entries) {
        final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
        buffer.writeln('            var $counterName = 0;');
      }
      buffer.writeln('            return (node, path) {');
      for (final entry in pathWritesByLocationType.entries) {
        final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
        buffer.writeln(
          '              if (${entry.value.values.first.first.locationMatchSource}) {',
        );
        buffer.writeln('                switch ($counterName++) {');
        final occurrences = entry.value.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key));
        for (final occurrence in occurrences) {
          buffer.writeln('                  case ${occurrence.key}:');
          for (final pathWrite in occurrence.value) {
            buffer.writeln(
              '                    path(${pathWrite.parameterAccessorSource}, '
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

    _writeQueryWrites(buffer, '          ', queryWrites);

    buffer.writeln('        );');
  }
}

class _GeneratedLocationChildTargetMethod {
  final List<_GeneratedLocationChildTargetMethodVariant> variants;

  const _GeneratedLocationChildTargetMethod({
    required this.variants,
  });

  String get ownerTypeSource => variants.first.ownerTypeSource;

  String get name => variants.first.name;

  String get targetTypeSource => variants.first.targetTypeSource;

  String get targetRouteTypeSource {
    return variants.any((variant) => variant.isOverlay)
        ? 'RouteTarget'
        : 'ChildRouteTarget';
  }

  bool get hasTargetIdentity =>
      variants.any((variant) => variant.hasTargetIdentity);

  bool isEquivalent(_GeneratedLocationChildTargetMethod other) {
    if (variants.length != other.variants.length) {
      return false;
    }

    for (var i = 0; i < variants.length; i++) {
      if (!variants[i].isOwnerAwareEquivalent(other.variants[i])) {
        return false;
      }
    }
    return true;
  }

  String get routeMethodName => _routeMethodNameForChildTarget(name);

  String renderMethod() {
    if (variants.length == 1) {
      return variants.single.renderMethod();
    }

    final first = variants.first;
    final buffer = StringBuffer();
    final parameters = [
      ...first.pathParameters.entries,
      ...first.queryParameters.entries,
    ];

    if (parameters.isEmpty) {
      buffer.writeln(
        '  $targetRouteTypeSource get ${first.name} {',
      );
      _writeOwnerDispatch(buffer, first, indent: '    ');
      buffer.writeln('  }');
      return buffer.toString();
    }

    buffer.writeln('  $targetRouteTypeSource ${first.name}({');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      final typeSource = generatedParameter.optional
          ? _nullableTypeSource(generatedParameter.dartTypeSource)
          : generatedParameter.dartTypeSource;
      final requiredKeyword = generatedParameter.optional ? '' : 'required ';
      buffer.writeln(
        '    $requiredKeyword$typeSource ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('  }) {');
    _writeOwnerDispatch(buffer, first, indent: '    ');
    buffer.writeln('  }');
    return buffer.toString();
  }

  String renderRouteMethod() {
    final first = variants.first;
    final buffer = StringBuffer();
    final parameters = [
      ...first.pathParameters.entries,
      ...first.queryParameters.entries,
    ];

    if (parameters.isEmpty) {
      buffer.writeln('  void $routeMethodName(BuildContext context) {');
      buffer.writeln(
        '    WorkingRouter.of(context).routeTo($name);',
      );
      buffer.writeln('  }');
      return buffer.toString();
    }

    buffer.writeln('  void $routeMethodName(');
    buffer.writeln('    BuildContext context, {');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      final typeSource = generatedParameter.optional
          ? _nullableTypeSource(generatedParameter.dartTypeSource)
          : generatedParameter.dartTypeSource;
      final requiredKeyword = generatedParameter.optional ? '' : 'required ';
      buffer.writeln(
        '      $requiredKeyword$typeSource ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('    }');
    buffer.writeln('  ) {');
    buffer.writeln('    WorkingRouter.of(context).routeTo(');
    buffer.writeln('      $name(');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      buffer.writeln(
        '        ${generatedParameter.parameterName}: ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('      ),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    return buffer.toString();
  }

  void _writeOwnerDispatch(
    StringBuffer buffer,
    _GeneratedLocationChildTargetMethodVariant first, {
    required String indent,
  }) {
    final defaultVariant = variants
        .where((variant) => variant.ownerSelectorExpression == null)
        .singleOrNull;
    for (final variant in variants.where(
      (variant) => variant.ownerSelectorExpression != null,
    )) {
      buffer.writeln('$indent if (${variant.ownerSelectorMatchSource}) {');
      variant.writeReturnStatement(buffer, '$indent  ');
      buffer.writeln('$indent }');
    }
    if (defaultVariant != null) {
      defaultVariant.writeReturnStatement(buffer, indent);
      return;
    }
    buffer.writeln(
      "$indent throw StateError('Child target ${first.name} is not "
      "available for \$runtimeType with id \$id.');",
    );
  }
}

class _GeneratedFirstLocationChildRouteMethod {
  final List<_GeneratedLocationChildTargetMethodVariant> variants;

  const _GeneratedFirstLocationChildRouteMethod({
    required this.variants,
  });

  String get ownerTypeSource => variants.first.ownerTypeSource;

  String get name => variants.first.name;

  String get routeMethodName => _firstRouteMethodNameForChildTarget(name);

  String renderRouteMethod() {
    final first = variants.first;
    final buffer = StringBuffer();
    final parameters = [
      ...first.pathParameters.entries,
      ...first.queryParameters.entries,
    ];

    if (parameters.isEmpty) {
      buffer.writeln('  void $routeMethodName(BuildContext context) {');
      _writeOwnerDispatch(buffer, indent: '    ');
      buffer.writeln('  }');
      return buffer.toString();
    }

    buffer.writeln('  void $routeMethodName(');
    buffer.writeln('    BuildContext context, {');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      final typeSource = generatedParameter.optional
          ? _nullableTypeSource(generatedParameter.dartTypeSource)
          : generatedParameter.dartTypeSource;
      final requiredKeyword = generatedParameter.optional ? '' : 'required ';
      buffer.writeln(
        '      $requiredKeyword$typeSource ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('    }');
    buffer.writeln('  ) {');
    _writeOwnerDispatch(buffer, indent: '    ');
    buffer.writeln('  }');
    return buffer.toString();
  }

  void _writeOwnerDispatch(StringBuffer buffer, {required String indent}) {
    final defaultVariant = variants
        .where((variant) => variant.ownerSelectorExpression == null)
        .singleOrNull;
    for (final variant in variants.where(
      (variant) => variant.ownerSelectorExpression != null,
    )) {
      buffer.writeln('$indent if (${variant.ownerSelectorMatchSource}) {');
      variant.writeRouteToFirstStatement(buffer, '$indent  ');
      buffer.writeln('$indent }');
    }
    if (defaultVariant != null) {
      defaultVariant.writeRouteToFirstStatement(buffer, indent);
      return;
    }
    buffer.writeln(
      "$indent throw StateError('First child route helper $routeMethodName is not "
      "available for \$runtimeType with id \$id and localId \$localId.');",
    );
  }
}

class _GeneratedLocationChildTargetMethodVariant {
  final _RouteNode ownerNode;
  final String? ownerSelectorExpression;
  final String? ownerSelectorMatchSource;
  final String ownerTypeSource;
  final String name;
  final String targetTypeSource;
  final bool hasTargetIdentity;
  final String childLocationMatchSource;
  final int relativeDepth;
  final List<String> structuralNameSegments;
  final List<String> identityAwareNameSegments;
  final List<String> relativeNodeMatchSources;
  final bool isOverlay;
  final Map<int, int> exclusiveBranchSelections;
  final List<_GeneratedPathWrite> pathWrites;
  final List<_GeneratedPathWrite> queryWrites;
  final Map<String, _GeneratedRouteParameter> pathParameters;
  final Map<String, _GeneratedRouteParameter> queryParameters;

  const _GeneratedLocationChildTargetMethodVariant({
    required this.ownerNode,
    required this.ownerSelectorExpression,
    required this.ownerSelectorMatchSource,
    required this.ownerTypeSource,
    required this.name,
    required this.targetTypeSource,
    required this.hasTargetIdentity,
    required this.childLocationMatchSource,
    required this.relativeDepth,
    required this.structuralNameSegments,
    required this.identityAwareNameSegments,
    required this.relativeNodeMatchSources,
    required this.isOverlay,
    required this.exclusiveBranchSelections,
    required this.pathWrites,
    required this.queryWrites,
    required this.pathParameters,
    required this.queryParameters,
  });

  bool isEquivalent(_GeneratedLocationChildTargetMethodVariant other) {
    return ownerTypeSource == other.ownerTypeSource &&
        isOverlay == other.isOverlay &&
        relativeDepth == other.relativeDepth &&
        const ListEquality<String>().equals(
          relativeNodeMatchSources,
          other.relativeNodeMatchSources,
        ) &&
        _generatedTargetDefinitionEquivalent(
          name: name,
          targetClassName: '',
          idExpression: null,
          childLocationMatchSource: childLocationMatchSource,
          pathWrites: pathWrites,
          queryWrites: queryWrites,
          pathParameters: pathParameters,
          queryParameters: queryParameters,
          otherName: other.name,
          otherTargetClassName: '',
          otherIdExpression: null,
          otherChildLocationMatchSource: other.childLocationMatchSource,
          otherPathWrites: other.pathWrites,
          otherQueryWrites: other.queryWrites,
          otherPathParameters: other.pathParameters,
          otherQueryParameters: other.queryParameters,
        );
  }

  _GeneratedLocationChildTargetMethodVariant copyWith({
    String? name,
  }) {
    return _GeneratedLocationChildTargetMethodVariant(
      ownerNode: ownerNode,
      ownerSelectorExpression: ownerSelectorExpression,
      ownerSelectorMatchSource: ownerSelectorMatchSource,
      ownerTypeSource: ownerTypeSource,
      name: name ?? this.name,
      targetTypeSource: targetTypeSource,
      hasTargetIdentity: hasTargetIdentity,
      childLocationMatchSource: childLocationMatchSource,
      relativeDepth: relativeDepth,
      structuralNameSegments: structuralNameSegments,
      identityAwareNameSegments: identityAwareNameSegments,
      relativeNodeMatchSources: relativeNodeMatchSources,
      isOverlay: isOverlay,
      exclusiveBranchSelections: exclusiveBranchSelections,
      pathWrites: pathWrites,
      queryWrites: queryWrites,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  bool isOwnerAwareEquivalent(
    _GeneratedLocationChildTargetMethodVariant other,
  ) {
    return ownerSelectorExpression == other.ownerSelectorExpression &&
        ownerSelectorMatchSource == other.ownerSelectorMatchSource &&
        isEquivalent(other);
  }

  String get routeMethodName => _routeMethodNameForChildTarget(name);

  String renderMethod() {
    final buffer = StringBuffer();
    final parameters = [
      ...pathParameters.entries,
      ...queryParameters.entries,
    ];

    if (parameters.isEmpty) {
      final returnType = isOverlay ? 'OverlayRouteTarget' : 'ChildRouteTarget';
      buffer.writeln('  $returnType get $name {');
      writeReturnStatement(buffer, '    ');
      buffer.writeln('  }');
      return buffer.toString();
    }

    final returnType = isOverlay ? 'OverlayRouteTarget' : 'ChildRouteTarget';
    buffer.writeln('  $returnType $name({');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      final typeSource = generatedParameter.optional
          ? _nullableTypeSource(generatedParameter.dartTypeSource)
          : generatedParameter.dartTypeSource;
      final requiredKeyword = generatedParameter.optional ? '' : 'required ';
      buffer.writeln(
        '    $requiredKeyword$typeSource ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('  }) {');
    writeReturnStatement(buffer, '    ');
    buffer.writeln('  }');
    return buffer.toString();
  }

  String renderRouteMethod() {
    final buffer = StringBuffer();
    final parameters = [
      ...pathParameters.entries,
      ...queryParameters.entries,
    ];

    if (parameters.isEmpty) {
      buffer.writeln('  void $routeMethodName(BuildContext context) {');
      buffer.writeln(
        '    WorkingRouter.of(context).routeTo($name);',
      );
      buffer.writeln('  }');
      return buffer.toString();
    }

    buffer.writeln('  void $routeMethodName(');
    buffer.writeln('    BuildContext context, {');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      final typeSource = generatedParameter.optional
          ? _nullableTypeSource(generatedParameter.dartTypeSource)
          : generatedParameter.dartTypeSource;
      final requiredKeyword = generatedParameter.optional ? '' : 'required ';
      buffer.writeln(
        '      $requiredKeyword$typeSource ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('    }');
    buffer.writeln('  ) {');
    buffer.writeln('    WorkingRouter.of(context).routeTo(');
    buffer.writeln('      $name(');
    for (final parameter in parameters) {
      final generatedParameter = parameter.value;
      buffer.writeln(
        '        ${generatedParameter.parameterName}: ${generatedParameter.parameterName},',
      );
    }
    buffer.writeln('      ),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    return buffer.toString();
  }

  void writeReturnStatement(StringBuffer buffer, String indent) {
    if (isOverlay) {
      buffer.writeln('$indent return OverlayRouteTarget(');
      buffer.writeln('$indent   owner: this,');
      buffer.writeln('$indent   overlay: pathRouteOverlays.where((node) {');
      buffer.writeln('$indent     return ${relativeNodeMatchSources.single};');
      buffer.writeln('$indent   }).single,');
      buffer.writeln('$indent);');
      return;
    }

    buffer.writeln('$indent return ChildRouteTarget(');
    buffer.writeln('$indent   start: this,');
    buffer.writeln('$indent   resolveChildPathNodes: () {');
    buffer.writeln('$indent     return resolveExactChildRouteNodes(this, [');
    for (final matchSource in relativeNodeMatchSources) {
      buffer.writeln('$indent       (node) => $matchSource,');
    }
    buffer.writeln('$indent     ]);');
    buffer.writeln('$indent   },');
    _writeConstructorOptions(buffer, indent: '$indent  ');
    buffer.writeln('$indent);');
  }

  void writeRouteToFirstStatement(StringBuffer buffer, String indent) {
    buffer.writeln('$indent WorkingRouter.of(context).routeTo(');
    buffer.writeln('$indent   FirstChildRouteTarget(');
    buffer.writeln('$indent     (location) => $childLocationMatchSource,');
    _writeConstructorOptions(buffer, indent: '$indent    ');
    buffer.writeln('$indent   ),');
    buffer.writeln('$indent );');
  }

  void _writeConstructorOptions(
    StringBuffer buffer, {
    required String indent,
  }) {
    if (pathWrites.isNotEmpty) {
      final pathWritesByLocationType =
          <String, Map<int, List<_GeneratedPathWrite>>>{};
      for (final pathWrite in pathWrites) {
        final byOccurrence = pathWritesByLocationType.putIfAbsent(
          pathWrite.locationMatchDiscriminator,
          () => <int, List<_GeneratedPathWrite>>{},
        );
        byOccurrence
            .putIfAbsent(pathWrite.occurrenceIndex, () => [])
            .add(pathWrite);
      }

      buffer.writeln('$indent writePathParameters: (() {');
      for (final entry in pathWritesByLocationType.entries) {
        final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
        buffer.writeln('$indent   var $counterName = 0;');
      }
      buffer.writeln('$indent   return (node, path) {');
      for (final entry in pathWritesByLocationType.entries) {
        final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
        buffer.writeln(
          '$indent     if '
          '(${entry.value.values.first.first.locationMatchSource}) {',
        );
        buffer.writeln('$indent       switch ($counterName++) {');
        final occurrences = entry.value.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key));
        for (final occurrence in occurrences) {
          buffer.writeln('$indent         case ${occurrence.key}:');
          for (final pathWrite in occurrence.value) {
            buffer.writeln(
              '$indent           path(${pathWrite.parameterAccessorSource}, '
              '${pathWrite.parameterName});',
            );
          }
          buffer.writeln('$indent           break;');
        }
        buffer.writeln('$indent       }');
        buffer.writeln('$indent     }');
      }
      buffer.writeln('$indent   };');
      buffer.writeln('$indent })(),');
    }

    _writeQueryWrites(buffer, indent, queryWrites);
  }
}

class _GeneratedLocationChildTargetMethodsResult {
  final List<_GeneratedLocationChildTargetMethod> methods;
  final List<_GeneratedFirstLocationChildRouteMethod> firstRouteMethods;

  const _GeneratedLocationChildTargetMethodsResult({
    required this.methods,
    required this.firstRouteMethods,
  });
}

void _writeQueryWrites(
  StringBuffer buffer,
  String indent,
  List<_GeneratedPathWrite> queryWrites,
) {
  if (queryWrites.isEmpty) {
    return;
  }

  final queryWritesByLocationType =
      <String, Map<int, List<_GeneratedPathWrite>>>{};
  for (final queryWrite in queryWrites) {
    final byOccurrence = queryWritesByLocationType.putIfAbsent(
      queryWrite.locationMatchDiscriminator,
      () => <int, List<_GeneratedPathWrite>>{},
    );
    byOccurrence
        .putIfAbsent(queryWrite.occurrenceIndex, () => [])
        .add(queryWrite);
  }

  buffer.writeln('${indent}writeQueryParameters: (() {');
  for (final entry in queryWritesByLocationType.entries) {
    final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
    buffer.writeln('$indent  var $counterName = 0;');
  }
  buffer.writeln('$indent  return (node, query) {');
  for (final entry in queryWritesByLocationType.entries) {
    final counterName = '${_toParameterIdentifier(entry.key)}MatchIndex';
    buffer.writeln(
      '$indent    if (${entry.value.values.first.first.locationMatchSource}) {',
    );
    buffer.writeln('$indent      switch ($counterName++) {');
    final occurrences = entry.value.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    for (final occurrence in occurrences) {
      buffer.writeln('$indent        case ${occurrence.key}:');
      for (final queryWrite in occurrence.value) {
        if (queryWrite.parameterIsOptional) {
          buffer.writeln(
            '$indent          if (${queryWrite.parameterName} case final value?) {',
          );
          buffer.writeln(
            '$indent            query(${queryWrite.parameterAccessorSource}, value);',
          );
          buffer.writeln('$indent          }');
        } else {
          buffer.writeln(
            '$indent          query(${queryWrite.parameterAccessorSource}, '
            '${queryWrite.parameterName});',
          );
        }
      }
      buffer.writeln('$indent          break;');
    }
    buffer.writeln('$indent      }');
    buffer.writeln('$indent    }');
  }
  buffer.writeln('$indent  };');
  buffer.writeln('$indent})(),');
}

bool _generatedTargetDefinitionEquivalent({
  required String name,
  required String targetClassName,
  required String? idExpression,
  required String? childLocationMatchSource,
  required List<_GeneratedPathWrite> pathWrites,
  required List<_GeneratedPathWrite> queryWrites,
  required Map<String, _GeneratedRouteParameter> pathParameters,
  required Map<String, _GeneratedRouteParameter> queryParameters,
  required String otherName,
  required String otherTargetClassName,
  required String? otherIdExpression,
  required String? otherChildLocationMatchSource,
  required List<_GeneratedPathWrite> otherPathWrites,
  required List<_GeneratedPathWrite> otherQueryWrites,
  required Map<String, _GeneratedRouteParameter> otherPathParameters,
  required Map<String, _GeneratedRouteParameter> otherQueryParameters,
}) {
  return name == otherName &&
      targetClassName == otherTargetClassName &&
      idExpression == otherIdExpression &&
      childLocationMatchSource == otherChildLocationMatchSource &&
      _pathWritesEquivalent(pathWrites, otherPathWrites) &&
      _pathWritesEquivalent(queryWrites, otherQueryWrites) &&
      _parametersEquivalent(pathParameters, otherPathParameters) &&
      _parametersEquivalent(queryParameters, otherQueryParameters);
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
    if (left.locationMatchDiscriminator != right.locationMatchDiscriminator ||
        left.locationMatchSource != right.locationMatchSource ||
        left.parameterAccessorSource != right.parameterAccessorSource ||
        left.parameterIsOptional != right.parameterIsOptional ||
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

bool _branchSelectionsAreMutuallyExclusive(
  Map<int, int> first,
  Map<int, int> second,
) {
  for (final entry in first.entries) {
    final otherBranchId = second[entry.key];
    if (otherBranchId != null && otherBranchId != entry.value) {
      return true;
    }
  }
  return false;
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
  final int? pathParameterIndex;
  final AstNode? sourceNode;
  final Element? sourceElement;

  const _RoutePathParameterSegmentMetadata({
    required this.key,
    required this.dartTypeSource,
    required this.codecExpressionSource,
    this.memberName,
    this.pathParameterIndex,
    this.sourceNode,
    this.sourceElement,
  });
}

class _DslCodecMetadata {
  final String dartTypeSource;
  final String codecExpressionSource;

  const _DslCodecMetadata({
    required this.dartTypeSource,
    required this.codecExpressionSource,
  });
}

class _DslBoundParamMetadata {
  final bool isPath;
  final String? queryKey;
  final String dartTypeSource;
  final String codecExpressionSource;
  final bool optional;
  final AstNode? sourceNode;
  final Element? sourceElement;

  const _DslBoundParamMetadata({
    required this.isPath,
    this.queryKey,
    required this.dartTypeSource,
    required this.codecExpressionSource,
    required this.optional,
    required this.sourceNode,
    required this.sourceElement,
  });
}

class _RouteQueryParameterMetadata {
  final String key;
  final String dartTypeSource;
  final String codecExpressionSource;
  final bool optional;
  final AstNode? sourceNode;
  final Element? sourceElement;

  const _RouteQueryParameterMetadata({
    required this.key,
    required this.dartTypeSource,
    required this.codecExpressionSource,
    required this.optional,
    this.sourceNode,
    this.sourceElement,
  });

  _RouteQueryParameterMetadata copyWith({
    String? key,
    String? dartTypeSource,
    String? codecExpressionSource,
    bool? optional,
    AstNode? sourceNode,
    Element? sourceElement,
  }) {
    return _RouteQueryParameterMetadata(
      key: key ?? this.key,
      dartTypeSource: dartTypeSource ?? this.dartTypeSource,
      codecExpressionSource:
          codecExpressionSource ?? this.codecExpressionSource,
      optional: optional ?? this.optional,
      sourceNode: sourceNode ?? this.sourceNode,
      sourceElement: sourceElement ?? this.sourceElement,
    );
  }
}

class _GeneratedPathWrite {
  final String locationMatchDiscriminator;
  final String locationMatchSource;
  final int occurrenceIndex;
  final String parameterAccessorSource;
  final bool parameterIsOptional;
  final String parameterName;

  const _GeneratedPathWrite({
    required this.locationMatchDiscriminator,
    required this.locationMatchSource,
    required this.occurrenceIndex,
    required this.parameterAccessorSource,
    required this.parameterIsOptional,
    required this.parameterName,
  });
}

class _GeneratedRouteParameter {
  final String routeKey;
  final String parameterName;
  final String dartTypeSource;
  final String codecExpressionSource;
  final bool optional;
  final AstNode? sourceNode;
  final Element? sourceElement;

  const _GeneratedRouteParameter({
    required this.routeKey,
    required this.parameterName,
    required this.dartTypeSource,
    required this.codecExpressionSource,
    required this.optional,
    this.sourceNode,
    this.sourceElement,
  });

  _GeneratedRouteParameter copyWith({
    String? routeKey,
    String? parameterName,
    String? dartTypeSource,
    String? codecExpressionSource,
    bool? optional,
    AstNode? sourceNode,
    Element? sourceElement,
  }) {
    return _GeneratedRouteParameter(
      routeKey: routeKey ?? this.routeKey,
      parameterName: parameterName ?? this.parameterName,
      dartTypeSource: dartTypeSource ?? this.dartTypeSource,
      codecExpressionSource:
          codecExpressionSource ?? this.codecExpressionSource,
      optional: optional ?? this.optional,
      sourceNode: sourceNode ?? this.sourceNode,
      sourceElement: sourceElement ?? this.sourceElement,
    );
  }
}

String _nullableTypeSource(String typeSource) {
  return typeSource.endsWith('?') ? typeSource : '$typeSource?';
}

String _nonNullableTypeSource(String typeSource) {
  return typeSource.endsWith('?')
      ? typeSource.substring(0, typeSource.length - 1)
      : typeSource;
}

String _quotedDartString(String value) {
  return "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
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
  for (final suffix in const ['Location', 'Overlay', 'Node']) {
    if (locationTypeSource.endsWith(suffix) &&
        locationTypeSource.length > suffix.length) {
      return locationTypeSource.substring(
        0,
        locationTypeSource.length - suffix.length,
      );
    }
  }

  return locationTypeSource;
}

String _identityBaseNameFromExpression(String expression) {
  final token = expression.split('.').last;
  for (final suffix in const ['LocalId', 'NodeId', 'Id']) {
    if (token.endsWith(suffix) && token.length > suffix.length) {
      return token.substring(0, token.length - suffix.length);
    }
  }
  return token;
}

String _routeMethodNameForChildTarget(String childTargetMethodName) {
  const prefix = 'child';
  const suffix = 'Target';
  if (childTargetMethodName.startsWith(prefix) &&
      childTargetMethodName.endsWith(suffix) &&
      childTargetMethodName.length > prefix.length + suffix.length) {
    final middle = childTargetMethodName.substring(
      prefix.length,
      childTargetMethodName.length - suffix.length,
    );
    return 'routeToChild$middle';
  }

  return 'routeTo${_toUpperCamelCase(childTargetMethodName)}';
}

String _firstRouteMethodNameForChildTarget(String childTargetMethodName) {
  const prefix = 'child';
  const suffix = 'Target';
  if (childTargetMethodName.startsWith(prefix) &&
      childTargetMethodName.endsWith(suffix) &&
      childTargetMethodName.length > prefix.length + suffix.length) {
    final middle = childTargetMethodName.substring(
      prefix.length,
      childTargetMethodName.length - suffix.length,
    );
    return 'routeToFirstChild$middle';
  }

  return 'routeToFirst${_toUpperCamelCase(childTargetMethodName)}';
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
