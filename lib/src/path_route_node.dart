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

abstract class PathRouteNodeBuilder {
  final List<PathSegment> _path = [];
  final List<PathParam<dynamic>> _pathParameters = [];
  final List<QueryParam<dynamic>> _queryParameters = [];
  List<RouteNode> _children = const [];
  bool _childrenAssigned = false;
  PageKey? _pageKey;

  List<PathSegment> get path => _path;
  List<PathParam<dynamic>> get pathParameters => _pathParameters;
  List<QueryParam<dynamic>> get queryParameters => _queryParameters;
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
      final UnboundQueryParam<T> queryParameter => query(
        QueryParam<T>(queryParameter),
      ),
    };
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

  QueryParam<T> query<T>(QueryParam<T> parameter) {
    _queryParameters.add(parameter);
    return parameter;
  }

  QueryParam<T> queryParam<T>(
    String name,
    RouteParamCodec<T> codec, {
    Default<T>? defaultValue,
  }) {
    return query(
      QueryParam<T>(
        UnboundQueryParam<T>(name, codec, defaultValue: defaultValue),
      ),
    );
  }

  QueryParam<String> stringQueryParam(
    String name, {
    Default<String>? defaultValue,
  }) {
    return queryParam(
      name,
      const StringRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  QueryParam<String?> nullableStringQueryParam(String name) {
    return queryParam<String?>(
      name,
      const StringRouteParamCodec(),
      defaultValue: const Default<String?>(null),
    );
  }

  QueryParam<int> intQueryParam(
    String name, {
    Default<int>? defaultValue,
  }) {
    return queryParam(
      name,
      const IntRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  QueryParam<int?> nullableIntQueryParam(String name) {
    return queryParam<int?>(
      name,
      const IntRouteParamCodec(),
      defaultValue: const Default<int?>(null),
    );
  }

  QueryParam<double> doubleQueryParam(
    String name, {
    Default<double>? defaultValue,
  }) {
    return queryParam(
      name,
      const DoubleRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  QueryParam<double?> nullableDoubleQueryParam(String name) {
    return queryParam<double?>(
      name,
      const DoubleRouteParamCodec(),
      defaultValue: const Default<double?>(null),
    );
  }

  QueryParam<bool> boolQueryParam(
    String name, {
    Default<bool>? defaultValue,
  }) {
    return queryParam(
      name,
      const BoolRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  QueryParam<bool?> nullableBoolQueryParam(String name) {
    return queryParam<bool?>(
      name,
      const BoolRouteParamCodec(),
      defaultValue: const Default<bool?>(null),
    );
  }

  QueryParam<DateTime> dateTimeQueryParam(
    String name, {
    Default<DateTime>? defaultValue,
  }) {
    return queryParam(
      name,
      const DateTimeIsoRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  QueryParam<DateTime?> nullableDateTimeQueryParam(String name) {
    return queryParam<DateTime?>(
      name,
      const DateTimeIsoRouteParamCodec(),
      defaultValue: const Default<DateTime?>(null),
    );
  }

  QueryParam<Uri> uriQueryParam(
    String name, {
    Default<Uri>? defaultValue,
  }) {
    return queryParam(
      name,
      const UriRouteParamCodec(),
      defaultValue: defaultValue,
    );
  }

  QueryParam<Uri?> nullableUriQueryParam(String name) {
    return queryParam<Uri?>(
      name,
      const UriRouteParamCodec(),
      defaultValue: const Default<Uri?>(null),
    );
  }

  QueryParam<T> enumQueryParam<T extends Enum>(
    String name,
    List<T> values, {
    Default<T>? defaultValue,
  }) {
    return queryParam(
      name,
      EnumRouteParamCodec(values),
      defaultValue: defaultValue,
    );
  }

  QueryParam<T?> nullableEnumQueryParam<T extends Enum>(
    String name,
    List<T> values,
  ) {
    return queryParam<T?>(
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
          return locationBuilder.resolveRender();
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
          return shellLocationBuilder.resolveRender();
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
          return multiShellLocationBuilder.resolveRender();
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
      children: List.unmodifiable(builder.children),
      pageKey: builder.configuredPageKey,
      render: render,
    );
  }

  List<PathSegment> get path => _definition.path;

  List<PathParam<dynamic>> get pathParameters => _definition.pathParameters;

  List<QueryParam<dynamic>> get queryParameters => _definition.queryParameters;

  @override
  List<RouteNode> get children => _definition.children;

  @override
  LocalKey buildPageKey(WorkingRouterData data) {
    return _definition.pageKey?.build(this, data) ?? super.buildPageKey(data);
  }
}
