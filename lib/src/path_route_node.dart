import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/multi_shell.dart';
import 'package:working_router/src/multi_shell_location.dart';
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

/// Controls whether a matched route node contributes its path segments when
/// the router generates a URI from the active route chain.
///
/// This is not a matching or authorization mechanism. Hidden path segments are
/// still accepted when they are present in an incoming URL; the router simply
/// omits them again when it writes its canonical URI. Keep protected screens
/// behind normal permission checks instead of relying on path visibility.
///
/// Visibility is inherited by descendants. The only explicit override is
/// [hidden]; there is intentionally no visible override.
enum RoutePathVisibility {
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
  List<QueryFilter<dynamic>> _queryFilters = const [];
  bool _queryFiltersAssigned = false;
  List<RouteNode> _children = const [];
  bool _childrenAssigned = false;
  PageKey? _pageKey;
  RoutePathVisibility pathVisibility = RoutePathVisibility.inherit;
  RouteBrowserHistory browserHistory = RouteBrowserHistory.remember;

  List<PathSegment> get path => _path;
  List<PathParam<dynamic>> get pathParameters => _pathParameters;
  List<QueryParam<dynamic>> get queryParameters => _queryParameters;
  List<QueryFilter<dynamic>> get queryFilters => _queryFilters;
  List<RouteNode> get children => _children;
  PageKey? get configuredPageKey => _pageKey;

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
      final UnboundQueryParam<T> queryParameter =>
        queryParameter.defaultValue == null
            ? _bindQueryParam(queryParameter)
            : _bindDefaultQueryParam(queryParameter),
    };
  }

  RequiredQueryParam<T> bindQueryParam<T>(
    RequiredUnboundQueryParam<T> parameter,
  ) {
    return _bindQueryParam(parameter);
  }

  RequiredQueryParam<T> _bindQueryParam<T>(UnboundQueryParam<T> parameter) {
    final queryParameter = RequiredQueryParam<T>(parameter);
    _queryParameters.add(queryParameter);
    return queryParameter;
  }

  DefaultQueryParam<T> bindDefaultQueryParam<T>(
    DefaultUnboundQueryParam<T> parameter,
  ) {
    return _bindDefaultQueryParam(parameter);
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
    UnboundQueryParam<T> parameter,
  ) {
    final queryParameter = DefaultQueryParam<T>(parameter);
    _queryParameters.add(queryParameter);
    return queryParameter;
  }

  RequiredQueryParam<T> queryParam<T>(
    String name,
    RouteParamCodec<T> codec,
  ) {
    final queryParameter = RequiredQueryParam<T>(
      RequiredUnboundQueryParam<T>(name, codec),
    );
    _queryParameters.add(queryParameter);
    return queryParameter;
  }

  DefaultQueryParam<T> defaultQueryParam<T>(
    String name,
    RouteParamCodec<T> codec, {
    required Default<T> defaultValue,
  }) {
    return _bindDefaultQueryParam(
      DefaultUnboundQueryParam<T>(
        name,
        codec,
        defaultValue: defaultValue,
      ),
    );
  }

  set queryFilters(List<QueryFilter<dynamic>> filters) {
    if (_queryFiltersAssigned) {
      throw StateError(
        'PathRouteNodeBuilder queryFilters were already configured. '
        'queryFilters may only be assigned once.',
      );
    }
    _queryFilters = List.unmodifiable(filters);
    _queryFiltersAssigned = true;
  }

  RequiredQueryParam<String> stringQueryParam(String name) {
    return queryParam(
      name,
      const StringRouteParamCodec(),
    );
  }

  DefaultQueryParam<String> defaultStringQueryParam(
    String name, {
    required Default<String> defaultValue,
  }) {
    return defaultQueryParam(
      name,
      const StringRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  DefaultQueryParam<String?> nullableStringQueryParam(String name) {
    return defaultQueryParam<String?>(
      name,
      const StringRouteParamCodec(),
      defaultValue: const Default<String?>(null),
    );
  }

  RequiredQueryParam<int> intQueryParam(String name) {
    return queryParam(
      name,
      const IntRouteParamCodec(),
    );
  }

  DefaultQueryParam<int> defaultIntQueryParam(
    String name, {
    required Default<int> defaultValue,
  }) {
    return defaultQueryParam(
      name,
      const IntRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  DefaultQueryParam<int?> nullableIntQueryParam(String name) {
    return defaultQueryParam<int?>(
      name,
      const IntRouteParamCodec(),
      defaultValue: const Default<int?>(null),
    );
  }

  RequiredQueryParam<double> doubleQueryParam(String name) {
    return queryParam(
      name,
      const DoubleRouteParamCodec(),
    );
  }

  DefaultQueryParam<double> defaultDoubleQueryParam(
    String name, {
    required Default<double> defaultValue,
  }) {
    return defaultQueryParam(
      name,
      const DoubleRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  DefaultQueryParam<double?> nullableDoubleQueryParam(String name) {
    return defaultQueryParam<double?>(
      name,
      const DoubleRouteParamCodec(),
      defaultValue: const Default<double?>(null),
    );
  }

  RequiredQueryParam<bool> boolQueryParam(String name) {
    return queryParam(
      name,
      const BoolRouteParamCodec(),
    );
  }

  DefaultQueryParam<bool> defaultBoolQueryParam(
    String name, {
    required Default<bool> defaultValue,
  }) {
    return defaultQueryParam(
      name,
      const BoolRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  DefaultQueryParam<bool?> nullableBoolQueryParam(String name) {
    return defaultQueryParam<bool?>(
      name,
      const BoolRouteParamCodec(),
      defaultValue: const Default<bool?>(null),
    );
  }

  RequiredQueryParam<DateTime> dateTimeQueryParam(String name) {
    return queryParam(
      name,
      const DateTimeIsoRouteParamCodec(),
    );
  }

  DefaultQueryParam<DateTime> defaultDateTimeQueryParam(
    String name, {
    required Default<DateTime> defaultValue,
  }) {
    return defaultQueryParam(
      name,
      const DateTimeIsoRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  DefaultQueryParam<DateTime?> nullableDateTimeQueryParam(String name) {
    return defaultQueryParam<DateTime?>(
      name,
      const DateTimeIsoRouteParamCodec(),
      defaultValue: const Default<DateTime?>(null),
    );
  }

  RequiredQueryParam<Uri> uriQueryParam(String name) {
    return queryParam(
      name,
      const UriRouteParamCodec(),
    );
  }

  DefaultQueryParam<Uri> defaultUriQueryParam(
    String name, {
    required Default<Uri> defaultValue,
  }) {
    return defaultQueryParam(
      name,
      const UriRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  DefaultQueryParam<Uri?> nullableUriQueryParam(String name) {
    return defaultQueryParam<Uri?>(
      name,
      const UriRouteParamCodec(),
      defaultValue: const Default<Uri?>(null),
    );
  }

  RequiredQueryParam<T> enumQueryParam<T extends Enum>(
    String name,
    List<T> values,
  ) {
    return queryParam(
      name,
      EnumRouteParamCodec(values),
    );
  }

  DefaultQueryParam<T> defaultEnumQueryParam<T extends Enum>(
    String name,
    List<T> values, {
    required Default<T> defaultValue,
  }) {
    return defaultQueryParam(
      name,
      EnumRouteParamCodec(values),
      defaultValue: defaultValue,
    );
  }

  DefaultQueryParam<T?> nullableEnumQueryParam<T extends Enum>(
    String name,
    List<T> values,
  ) {
    return defaultQueryParam<T?>(
      name,
      EnumRouteParamCodec(values),
      defaultValue: Default<T?>(null),
    );
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

  set pageKey(PageKey pageKey) {
    _pageKey = pageKey;
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
      queryFilters: List.unmodifiable(builder.queryFilters),
      children: List.unmodifiable(builder.children),
      pageKey: builder.configuredPageKey,
      pathVisibility: builder.pathVisibility,
      browserHistory: builder.browserHistory,
      render: render,
    );
  }

  List<PathSegment> get path => _definition.path;

  List<PathParam<dynamic>> get pathParameters => _definition.pathParameters;

  List<QueryParam<dynamic>> get queryParameters => _definition.queryParameters;

  List<QueryFilter<dynamic>> get queryFilters => _definition.queryFilters;

  RoutePathVisibility get pathVisibility => _definition.pathVisibility;

  RouteBrowserHistory get browserHistory => _definition.browserHistory;

  @override
  List<RouteNode> get children => _definition.children;

  @override
  LocalKey buildPageKey(WorkingRouterData data) {
    return _definition.pageKey?.build(this, data) ?? super.buildPageKey(data);
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
