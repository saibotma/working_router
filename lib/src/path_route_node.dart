import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/multi_shell.dart';
import 'package:working_router/src/multi_shell_location.dart';
import 'package:working_router/src/overlay.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/route_param_codec.dart';
import 'package:working_router/src/scope.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/shell_location.dart';
import 'package:working_router/src/working_router_data.dart';

abstract interface class BuildsWithLocationBuilder {
  void build(LocationBuilder builder);
}

abstract interface class BuildsWithScopeBuilder {
  void build(ScopeBuilder builder);
}

abstract interface class BuildsWithShellBuilder {
  void build(ShellBuilder builder);
}

abstract interface class BuildsWithShellLocationBuilder {
  void build(ShellLocationBuilder builder);
}

abstract interface class BuildsWithMultiShellBuilder {
  void build(MultiShellBuilder builder);
}

abstract interface class BuildsWithMultiShellLocationBuilder {
  void build(MultiShellLocationBuilder builder);
}

abstract class PathRouteNodeRenderResult {
  const PathRouteNodeRenderResult();
}

/// Controls whether a route-owned URI part is written into generated URIs.
///
/// This is not a matching or authorization mechanism. Hidden path segments are
/// and query parameters are still accepted when they are present in an incoming
/// URL; the router simply omits them again when it writes its canonical URI.
/// Keep protected state behind normal permission checks instead of relying on
/// URI visibility.
///
/// Path visibility is inherited by descendant route nodes. Query visibility is
/// inherited from ancestor query parameter declarations with the same key. The
/// only explicit override is [hidden]; there is intentionally no visible
/// override.
enum UriVisibility {
  inherit,
  hidden,
}

/// Controls whether a matched route node creates a browser history entry when
/// the router reports its URI.
///
/// [remember] is the normal browser behavior: the URL update can create a new
/// history entry. [replace] keeps the URL in sync but reports the route update
/// as `Router.neglect`, so the browser replaces the current entry instead of
/// creating a forward-routable one.
enum RouteBrowserHistory {
  remember,
  replace,
}

abstract class PathRouteNodeBuilder {
  final List<PathSegment> _path = [];
  final List<PathParam<dynamic>> _pathParameters = [];
  final List<QueryParam<dynamic>> _queryParameters = [];
  final List<DefaultQueryParam<dynamic>> _unboundQueryParameters = [];
  List<AnyOverlay> _overlays = const [];
  bool _overlaysAssigned = false;
  List<RouteNode> _children = const [];
  bool _childrenAssigned = false;
  UriVisibility pathVisibility = UriVisibility.inherit;
  RouteBrowserHistory browserHistory = RouteBrowserHistory.remember;

  /// Configures how this route node builds its [Page] key.
  ///
  /// Defaults to [PageKey.templatePath], so page identity follows the route
  /// shape and ignores hydrated path parameter values. Use [PageKey.path] when
  /// path parameter values or path-like query parameters should create a new
  /// page identity, or [PageKey.custom] for fully custom page identity.
  PageKey pageKey = const PageKey.templatePath();

  List<PathSegment> get path => _path;
  List<PathParam<dynamic>> get pathParameters => _pathParameters;
  List<QueryParam<dynamic>> get queryParameters => _queryParameters;
  List<DefaultQueryParam<dynamic>> get unboundQueryParameters =>
      _unboundQueryParameters;
  List<AnyOverlay> get overlays => _overlays;
  List<RouteNode> get children => _children;

  PathRouteNodeBuilder();

  T pathSegment<T extends PathSegment>(T segment) {
    _path.add(segment);
    if (segment case final PathParam<dynamic> parameter) {
      _pathParameters.add(parameter);
    }
    return segment;
  }

  LiteralPathSegment pathLiteral(String value) {
    return pathSegment(LiteralPathSegment(value));
  }

  /// Declares a non-nullable path parameter.
  ///
  /// Path parameters represent concrete matched URI segments, so they cannot
  /// be nullable. Use query parameters for optional `null`-producing values.
  PathParam<T> pathParam<T>(RouteParamCodec<T> codec) {
    final bound = PathParam<T>(UnboundPathParam<T>(codec));
    return pathSegment<PathParam<T>>(bound);
  }

  /// Binds a reusable unbound path or query parameter definition to this node.
  ///
  /// This is primarily intended for rare shared/global parameter definitions
  /// that need nullable lookup from outer code via `data.paramOrNull(...)`.
  Param<T> bindParam<T>(UnboundParam<T> parameter) {
    return switch (parameter) {
      final UnboundPathParam<T> pathParameter => pathSegment<PathParam<T>>(
        PathParam<T>(pathParameter),
      ),
      final RequiredUnboundQueryParam<T> queryParameter => _bindQueryParam(
        queryParameter,
      ),
      final DefaultUnboundQueryParam<T> queryParameter =>
        _bindDefaultQueryParam(queryParameter),
    };
  }

  RequiredQueryParam<T> bindQueryParam<T>(
    RequiredUnboundQueryParam<T> parameter, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return _bindQueryParam(
      parameter,
      visibility: visibility,
      identity: identity,
    );
  }

  RequiredQueryParam<T> _bindQueryParam<T>(
    RequiredUnboundQueryParam<T> parameter, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    final queryParameter = RequiredQueryParam<T>(
      parameter,
      uriVisibility: visibility,
      identity: identity,
    );
    _queryParameters.add(queryParameter);
    return queryParameter;
  }

  DefaultQueryParam<T> bindDefaultQueryParam<T>(
    DefaultUnboundQueryParam<T> parameter, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return _bindDefaultQueryParam(
      parameter,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  PathParam<String> stringPathParam() {
    return pathParam(const StringRouteParamCodec());
  }

  PathParam<int> intPathParam() {
    return pathParam(const IntRouteParamCodec());
  }

  PathParam<double> doublePathParam() {
    return pathParam(const DoubleRouteParamCodec());
  }

  PathParam<bool> boolPathParam() {
    return pathParam(const BoolRouteParamCodec());
  }

  PathParam<DateTime> dateTimePathParam() {
    return pathParam(const DateTimeIsoRouteParamCodec());
  }

  PathParam<Uri> uriPathParam() {
    return pathParam(const UriRouteParamCodec());
  }

  PathParam<T> enumPathParam<T extends Enum>(List<T> values) {
    return pathParam(EnumRouteParamCodec(values));
  }

  DefaultQueryParam<T> _bindDefaultQueryParam<T>(
    DefaultUnboundQueryParam<T> parameter, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    final queryParameter = DefaultQueryParam<T>(
      parameter,
      uriVisibility: visibility,
      identity: identity,
      scope: scope,
    );
    _queryParameters.add(queryParameter);
    return queryParameter;
  }

  RequiredQueryParam<T> queryParam<T>(
    String name,
    RouteParamCodec<T> codec, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    final queryParameter = RequiredQueryParam<T>(
      RequiredUnboundQueryParam<T>(name, codec),
      uriVisibility: visibility,
      identity: identity,
    );
    _queryParameters.add(queryParameter);
    return queryParameter;
  }

  DefaultQueryParam<T> defaultQueryParam<T>(
    String name,
    RouteParamCodec<T> codec, {
    required T defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return _bindDefaultQueryParam(
      DefaultUnboundQueryParam<T>(
        name,
        codec,
        defaultValue: defaultValue,
      ),
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  RequiredQueryParam<String> stringQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return queryParam(
      name,
      const StringRouteParamCodec(),
      visibility: visibility,
      identity: identity,
    );
  }

  DefaultQueryParam<String> defaultStringQueryParam(
    String name, {
    required String defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam(
      name,
      const StringRouteParamCodec(),
      defaultValue: defaultValue,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  DefaultQueryParam<String?> nullableStringQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam<String?>(
      name,
      const StringRouteParamCodec(),
      defaultValue: null,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  RequiredQueryParam<int> intQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return queryParam(
      name,
      const IntRouteParamCodec(),
      visibility: visibility,
      identity: identity,
    );
  }

  DefaultQueryParam<int> defaultIntQueryParam(
    String name, {
    required int defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam(
      name,
      const IntRouteParamCodec(),
      defaultValue: defaultValue,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  DefaultQueryParam<int?> nullableIntQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam<int?>(
      name,
      const IntRouteParamCodec(),
      defaultValue: null,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  RequiredQueryParam<double> doubleQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return queryParam(
      name,
      const DoubleRouteParamCodec(),
      visibility: visibility,
      identity: identity,
    );
  }

  DefaultQueryParam<double> defaultDoubleQueryParam(
    String name, {
    required double defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam(
      name,
      const DoubleRouteParamCodec(),
      defaultValue: defaultValue,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  DefaultQueryParam<double?> nullableDoubleQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam<double?>(
      name,
      const DoubleRouteParamCodec(),
      defaultValue: null,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  RequiredQueryParam<bool> boolQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return queryParam(
      name,
      const BoolRouteParamCodec(),
      visibility: visibility,
      identity: identity,
    );
  }

  DefaultQueryParam<bool> defaultBoolQueryParam(
    String name, {
    required bool defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam(
      name,
      const BoolRouteParamCodec(),
      defaultValue: defaultValue,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  DefaultQueryParam<bool?> nullableBoolQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam<bool?>(
      name,
      const BoolRouteParamCodec(),
      defaultValue: null,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  RequiredQueryParam<DateTime> dateTimeQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return queryParam(
      name,
      const DateTimeIsoRouteParamCodec(),
      visibility: visibility,
      identity: identity,
    );
  }

  DefaultQueryParam<DateTime> defaultDateTimeQueryParam(
    String name, {
    required DateTime defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam(
      name,
      const DateTimeIsoRouteParamCodec(),
      defaultValue: defaultValue,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  DefaultQueryParam<DateTime?> nullableDateTimeQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam<DateTime?>(
      name,
      const DateTimeIsoRouteParamCodec(),
      defaultValue: null,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  RequiredQueryParam<Uri> uriQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return queryParam(
      name,
      const UriRouteParamCodec(),
      visibility: visibility,
      identity: identity,
    );
  }

  DefaultQueryParam<Uri> defaultUriQueryParam(
    String name, {
    required Uri defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam(
      name,
      const UriRouteParamCodec(),
      defaultValue: defaultValue,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  DefaultQueryParam<Uri?> nullableUriQueryParam(
    String name, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam<Uri?>(
      name,
      const UriRouteParamCodec(),
      defaultValue: null,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  RequiredQueryParam<T> enumQueryParam<T extends Enum>(
    String name,
    List<T> values, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
  }) {
    return queryParam(
      name,
      EnumRouteParamCodec(values),
      visibility: visibility,
      identity: identity,
    );
  }

  DefaultQueryParam<T> defaultEnumQueryParam<T extends Enum>(
    String name,
    List<T> values, {
    required T defaultValue,
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam(
      name,
      EnumRouteParamCodec(values),
      defaultValue: defaultValue,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  DefaultQueryParam<T?> nullableEnumQueryParam<T extends Enum>(
    String name,
    List<T> values, {
    UriVisibility visibility = UriVisibility.inherit,
    QueryParamIdentity identity = QueryParamIdentity.state,
    QueryParamScope scope = QueryParamScope.branch,
  }) {
    return defaultQueryParam<T?>(
      name,
      EnumRouteParamCodec(values),
      defaultValue: null,
      visibility: visibility,
      identity: identity,
      scope: scope,
    );
  }

  /// Stops inheriting [parameter] from this route node downward.
  ///
  /// When this route is matched, the parameter is reset to its default value
  /// and omitted from generated URIs for this route and its descendants.
  void unbindQueryParam<T>(DefaultQueryParam<T> parameter) {
    _unboundQueryParameters.add(parameter);
  }

  set children(List<RouteNode> children) {
    if (_childrenAssigned) {
      throw StateError(
        'PathRouteNodeBuilder children were already configured. '
        'children may only be assigned once.',
      );
    }
    _children = List.unmodifiable(children);
    _childrenAssigned = true;
  }

  set overlays(List<AnyOverlay> overlays) {
    if (_overlaysAssigned) {
      throw StateError(
        'PathRouteNodeBuilder overlays were already configured. '
        'overlays may only be assigned once.',
      );
    }
    _overlays = List.unmodifiable(overlays);
    _overlaysAssigned = true;
  }
}

abstract class PathRouteNode<Self extends PathRouteNode<Self>>
    extends RouteNode<Self> {
  PathRouteNode({
    super.id,
    super.localId,
    super.parentRouterKey,
  });

  @protected
  PathRouteNodeBuilder createBuilder();

  late final BuiltLocationDefinition _definition = _buildDefinition();

  @protected
  BuiltLocationDefinition get definition => _definition;

  BuiltLocationDefinition _buildDefinition() {
    final builder = createBuilder();
    final render = switch ((this, builder)) {
      (
        final BuildsWithLocationBuilder element,
        final LocationBuilder locationBuilder,
      ) =>
        () {
          element.build(locationBuilder);
          return locationBuilder.resolveRender(
            debugContext: _debugConfigurationContext(locationBuilder),
          );
        }(),
      (
        final BuildsWithScopeBuilder element,
        final ScopeBuilder scopeBuilder,
      ) =>
        () {
          element.build(scopeBuilder);
          return null;
        }(),
      (
        final BuildsWithShellBuilder element,
        final ShellBuilder shellBuilder,
      ) =>
        () {
          element.build(shellBuilder);
          return shellBuilder.resolveRender();
        }(),
      (
        final BuildsWithShellLocationBuilder element,
        final ShellLocationBuilder shellLocationBuilder,
      ) =>
        () {
          element.build(shellLocationBuilder);
          return shellLocationBuilder.resolveRender(
            debugContext: _debugConfigurationContext(shellLocationBuilder),
          );
        }(),
      (
        final BuildsWithMultiShellBuilder element,
        final MultiShellBuilder multiShellBuilder,
      ) =>
        () {
          element.build(multiShellBuilder);
          return multiShellBuilder.resolveRender();
        }(),
      (
        final BuildsWithMultiShellLocationBuilder element,
        final MultiShellLocationBuilder multiShellLocationBuilder,
      ) =>
        () {
          element.build(multiShellLocationBuilder);
          return multiShellLocationBuilder.resolveRender(
            debugContext: _debugConfigurationContext(
              multiShellLocationBuilder,
            ),
          );
        }(),
      _ => throw StateError(
        'Unsupported PathRouteNode/Builder combination: '
        '$runtimeType/${builder.runtimeType}.',
      ),
    };
    return BuiltLocationDefinition(
      path: List.unmodifiable(builder.path),
      pathParameters: List.unmodifiable(builder.pathParameters),
      queryParameters: List.unmodifiable(builder.queryParameters),
      unboundQueryParameters: List.unmodifiable(
        builder.unboundQueryParameters,
      ),
      overlays: List.unmodifiable(builder.overlays),
      children: List.unmodifiable(builder.children),
      pageKey: builder.pageKey,
      pathVisibility: builder.pathVisibility,
      browserHistory: builder.browserHistory,
      render: render,
    );
  }

  List<PathSegment> get path => _definition.path;

  List<PathParam<dynamic>> get pathParameters => _definition.pathParameters;

  List<QueryParam<dynamic>> get queryParameters => _definition.queryParameters;

  List<DefaultQueryParam<dynamic>> get unboundQueryParameters =>
      _definition.unboundQueryParameters;

  List<AnyOverlay> get pathRouteOverlays => _definition.overlays;

  UriVisibility get pathVisibility => _definition.pathVisibility;

  RouteBrowserHistory get browserHistory => _definition.browserHistory;

  @override
  List<RouteNode> get resolvedChildren => _definition.children;

  @override
  LocalKey buildPageKey(WorkingRouterData data) {
    return _definition.pageKey.build(this, data);
  }

  String _debugConfigurationContext(PathRouteNodeBuilder builder) {
    final buffer = StringBuffer()
      ..writeln('  node: $runtimeType')
      ..writeln('  builder: ${builder.runtimeType}')
      ..writeln('  node-local path: ${_debugPathTemplate(builder.path)}');

    if (builder.queryParameters.isNotEmpty) {
      buffer.writeln(
        '  query parameters: '
        '${builder.queryParameters.map((it) => it.name).join(', ')}',
      );
    }
    if (id != null) {
      buffer.writeln('  id: ${id.runtimeType}#${identityHashCode(id)}');
    }
    if (localId != null) {
      buffer.writeln(
        '  localId: ${localId.runtimeType}#${identityHashCode(localId)}',
      );
    }
    if (builder.children.isNotEmpty) {
      buffer.writeln(
        '  children: ${builder.children.map((it) => it.runtimeType).join(', ')}',
      );
    }
    if (builder.overlays.isNotEmpty) {
      buffer.writeln(
        '  overlays: ${builder.overlays.map((it) => it.runtimeType).join(', ')}',
      );
    }

    return buffer.toString().trimRight();
  }
}

String _debugPathTemplate(List<PathSegment> path) {
  if (path.isEmpty) {
    return '/';
  }

  final segments = path.map((segment) {
    return switch (segment) {
      final LiteralPathSegment literal => literal.value,
      PathParam() => '*',
    };
  });

  return '/${segments.join('/')}';
}
