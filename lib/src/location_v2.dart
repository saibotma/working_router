import 'package:working_router/src/working_router.dart';

/// Base class for all v2 location nodes.
sealed class LocationV2<ScopeKey, RouteId> {
  final String path;
  final List<LocationV2<ScopeKey, RouteId>> children;

  const LocationV2({
    required this.path,
    this.children = const [],
  });

  List<String> get pathSegments => Uri(path: path).pathSegments;
}

/// Root container for v2 location trees.
class ScopeRootLocationV2<ScopeKey, RouteId>
    extends LocationV2<ScopeKey, RouteId> {
  const ScopeRootLocationV2({
    super.children = const [],
  }) : super(path: '');
}

/// Regular route node rendered by a scope-local [WorkingRouter].
class RouteLocationV2<ScopeKey, RouteId> extends LocationV2<ScopeKey, RouteId> {
  final RouteId? id;

  const RouteLocationV2({
    required super.path,
    this.id,
    super.children = const [],
  });
}

/// Route subtree passed to a scope router builder.
class ScopeRouteSubtree<ScopeKey, RouteId> {
  final List<LocationV2<ScopeKey, RouteId>> children;

  const ScopeRouteSubtree({
    required this.children,
  });
}

typedef BuildScopeRouterV2<ScopeKey, RouteId> =
    WorkingRouter<RouteId> Function(
      ScopeKey scope,
      ScopeRouteSubtree<ScopeKey, RouteId> subtree,
      Uri? initialScopedUri,
    );

/// Base class for nodes that define scope boundaries.
abstract class ScopeBoundaryLocationV2<ScopeKey, RouteId>
    extends LocationV2<ScopeKey, RouteId> {
  const ScopeBoundaryLocationV2({
    required super.path,
    super.children = const [],
  });

  ScopeKey resolveScope(Map<String, String> pathParameters);

  Map<String, String>? trySerializeScopeParams(ScopeKey scope);

  WorkingRouter<RouteId> buildScopeRouterFor(
    ScopeKey scope,
    ScopeRouteSubtree<ScopeKey, RouteId> subtree,
    Uri? initialScopedUri,
  );
}

/// Dynamic scope boundary.
class ScopeLocationV2<ScopeKey, Scoped extends ScopeKey, RouteId>
    extends ScopeBoundaryLocationV2<ScopeKey, RouteId> {
  final Scoped Function(Map<String, String> params) _resolveScope;
  final Map<String, String> Function(Scoped scope) _serializeScopeParams;
  final WorkingRouter<RouteId> Function(
    Scoped scope,
    ScopeRouteSubtree<ScopeKey, RouteId> subtree,
    Uri? initialScopedUri,
  )
  _buildScopeRouter;

  const ScopeLocationV2({
    required super.path,
    required Scoped Function(Map<String, String> params) resolveScope,
    required Map<String, String> Function(Scoped scope) serializeScopeParams,
    required WorkingRouter<RouteId> Function(
      Scoped scope,
      ScopeRouteSubtree<ScopeKey, RouteId> subtree,
      Uri? initialScopedUri,
    )
    buildScopeRouter,
    super.children = const [],
  }) : _resolveScope = resolveScope,
       _serializeScopeParams = serializeScopeParams,
       _buildScopeRouter = buildScopeRouter;

  @override
  ScopeKey resolveScope(Map<String, String> pathParameters) {
    return _resolveScope(pathParameters);
  }

  @override
  Map<String, String>? trySerializeScopeParams(ScopeKey scope) {
    if (scope is! Scoped) {
      return null;
    }
    return _serializeScopeParams(scope);
  }

  @override
  WorkingRouter<RouteId> buildScopeRouterFor(
    ScopeKey scope,
    ScopeRouteSubtree<ScopeKey, RouteId> subtree,
    Uri? initialScopedUri,
  ) {
    if (scope is! Scoped) {
      throw ArgumentError(
        'Unsupported scope type ${scope.runtimeType} for '
        '$ScopeLocationV2<$ScopeKey, $Scoped, $RouteId>.',
      );
    }
    return _buildScopeRouter(scope, subtree, initialScopedUri);
  }
}

/// Static scope boundary.
class StaticScopeLocationV2<ScopeKey, Scoped extends ScopeKey, RouteId>
    extends ScopeBoundaryLocationV2<ScopeKey, RouteId> {
  final Scoped scope;
  final WorkingRouter<RouteId> Function(
    Scoped scope,
    ScopeRouteSubtree<ScopeKey, RouteId> subtree,
    Uri? initialScopedUri,
  )
  _buildScopeRouter;

  const StaticScopeLocationV2({
    required super.path,
    required this.scope,
    required WorkingRouter<RouteId> Function(
      Scoped scope,
      ScopeRouteSubtree<ScopeKey, RouteId> subtree,
      Uri? initialScopedUri,
    )
    buildScopeRouter,
    super.children = const [],
  }) : _buildScopeRouter = buildScopeRouter;

  @override
  ScopeKey resolveScope(Map<String, String> pathParameters) => scope;

  @override
  Map<String, String>? trySerializeScopeParams(ScopeKey scope) {
    if (scope != this.scope) {
      return null;
    }
    return const <String, String>{};
  }

  @override
  WorkingRouter<RouteId> buildScopeRouterFor(
    ScopeKey scope,
    ScopeRouteSubtree<ScopeKey, RouteId> subtree,
    Uri? initialScopedUri,
  ) {
    if (scope != this.scope) {
      throw ArgumentError(
        'Unsupported scope $scope for static scope location ${this.scope}.',
      );
    }
    return _buildScopeRouter(this.scope, subtree, initialScopedUri);
  }
}
