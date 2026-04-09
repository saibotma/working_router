import 'package:flutter/material.dart';
import 'package:working_router/src/location_tree_element.dart';
import 'package:working_router/src/route_param_codec.dart';
import 'package:working_router/src/working_router_data.dart';

typedef LocationWidgetBuilder<ID> =
    Widget Function(BuildContext context, WorkingRouterData<ID> data);
typedef SelfBuiltLocationPageBuilder =
    Page<dynamic> Function(LocalKey? key, Widget child);
typedef RouteNodePageKeyBuilder<ID> =
    LocalKey Function(WorkingRouterData<ID> data);
typedef ShellWidgetBuilder<ID> =
    Widget Function(
      BuildContext context,
      WorkingRouterData<ID> data,
      Widget child,
    );
typedef ShellPageBuilder = Page<dynamic> Function(LocalKey? key, Widget child);

sealed class LocationBuildResult<ID> {
  const LocationBuildResult();
}

final class SelfBuiltLocationBuildResult<ID> extends LocationBuildResult<ID> {
  final LocationWidgetBuilder<ID> buildWidget;
  final SelfBuiltLocationPageBuilder? buildPage;

  const SelfBuiltLocationBuildResult({
    required this.buildWidget,
    this.buildPage,
  });
}

final class ShellBuildResult<ID> {
  final ShellWidgetBuilder<ID> buildWidget;
  final ShellPageBuilder? buildPage;

  const ShellBuildResult({
    required this.buildWidget,
    this.buildPage,
  });
}

class LocationBuilder<ID> {
  final List<PathSegment> _path = [];
  final List<PathParam<dynamic>> _pathParameters = [];
  final List<QueryParam<dynamic>> _queryParameters = [];
  List<LocationTreeElement<ID>> _children = const [];
  bool _childrenAssigned = false;
  RouteNodePageKeyBuilder<ID>? _buildPageKey;
  LocationBuildResult<ID>? _render;

  List<PathSegment> get path => _path;
  List<PathParam<dynamic>> get pathParameters => _pathParameters;
  List<QueryParam<dynamic>> get queryParameters => _queryParameters;
  List<LocationTreeElement<ID>> get children => _children;
  RouteNodePageKeyBuilder<ID>? get buildPageKey => _buildPageKey;
  LocationBuildResult<ID>? get render => _render;

  LocationBuilder();

  T pathSegment<T extends PathSegment>(T segment) {
    _path.add(segment);
    if (segment case final PathParam<dynamic> parameter) {
      _pathParameters.add(parameter);
    }
    return segment;
  }

  LiteralPathSegment pathLiteral(String value) {
    return pathSegment(literal(value));
  }

  PathParam<T> pathParam<T>(RouteParamCodec<T> codec) {
    return pathSegment(PathParam<T>(codec));
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

  QueryParam<T> query<T>(QueryParam<T> parameter) {
    _queryParameters.add(parameter);
    return parameter;
  }

  QueryParam<T> queryParam<T>(
    String name,
    RouteParamCodec<T> codec, {
    bool optional = false,
  }) {
    return query(QueryParam<T>(name, codec, optional: optional));
  }

  QueryParam<String> stringQueryParam(
    String name, {
    bool optional = false,
  }) {
    return queryParam(name, const StringRouteParamCodec(), optional: optional);
  }

  QueryParam<int> intQueryParam(
    String name, {
    bool optional = false,
  }) {
    return queryParam(name, const IntRouteParamCodec(), optional: optional);
  }

  QueryParam<double> doubleQueryParam(
    String name, {
    bool optional = false,
  }) {
    return queryParam(name, const DoubleRouteParamCodec(), optional: optional);
  }

  QueryParam<bool> boolQueryParam(
    String name, {
    bool optional = false,
  }) {
    return queryParam(name, const BoolRouteParamCodec(), optional: optional);
  }

  QueryParam<DateTime> dateTimeQueryParam(
    String name, {
    bool optional = false,
  }) {
    return queryParam(
      name,
      const DateTimeIsoRouteParamCodec(),
      optional: optional,
    );
  }

  set children(List<LocationTreeElement<ID>> children) {
    if (_childrenAssigned) {
      throw StateError(
        'LocationBuilder children were already configured. '
        'children may only be assigned once.',
      );
    }
    _children = List.unmodifiable(children);
    _childrenAssigned = true;
  }

  set pageKey(RouteNodePageKeyBuilder<ID> buildPageKey) {
    _buildPageKey = buildPageKey;
  }

  void widget(
    LocationWidgetBuilder<ID> widget,
  ) {
    _setRender(SelfBuiltLocationBuildResult(buildWidget: widget));
  }

  void page({
    required LocationWidgetBuilder<ID> widget,
    SelfBuiltLocationPageBuilder? page,
  }) {
    _setRender(
      SelfBuiltLocationBuildResult(
        buildWidget: widget,
        buildPage: page,
      ),
    );
  }

  void _setRender(LocationBuildResult<ID> render) {
    if (_render != null) {
      throw StateError(
        'LocationBuilder render was already configured. Only one of '
        'widget(...) or page(...) may be used.',
      );
    }
    _render = render;
  }
}

class ShellBuilder<ID> {
  List<LocationTreeElement<ID>> _children = const [];
  bool _childrenAssigned = false;
  RouteNodePageKeyBuilder<ID>? buildPageKey;
  ShellBuildResult<ID>? _render;

  List<LocationTreeElement<ID>> get children => _children;
  ShellBuildResult<ID>? get render => _render;

  ShellBuilder();

  set children(List<LocationTreeElement<ID>> children) {
    if (_childrenAssigned) {
      throw StateError(
        'ShellBuilder children were already configured. '
        'children may only be assigned once.',
      );
    }
    _children = List.unmodifiable(children);
    _childrenAssigned = true;
  }

  set pageKey(RouteNodePageKeyBuilder<ID> buildPageKey) {
    this.buildPageKey = buildPageKey;
  }

  void widget(
    ShellWidgetBuilder<ID> widget, {
    ShellPageBuilder? page,
  }) {
    if (_render != null) {
      throw StateError(
        'ShellBuilder render was already configured. '
        'widget(...) may only be called once.',
      );
    }
    _render = ShellBuildResult(buildWidget: widget, buildPage: page);
  }
}

class BuiltLocationDefinition<ID> {
  final List<PathSegment> path;
  final List<PathParam<dynamic>> pathParameters;
  final List<QueryParam<dynamic>> queryParameters;
  final List<LocationTreeElement<ID>> children;
  final RouteNodePageKeyBuilder<ID>? buildPageKey;
  final LocationBuildResult<ID>? render;

  const BuiltLocationDefinition({
    required this.path,
    required this.pathParameters,
    required this.queryParameters,
    required this.children,
    required this.buildPageKey,
    required this.render,
  });
}

class BuiltShellDefinition<ID> {
  final List<LocationTreeElement<ID>> children;
  final RouteNodePageKeyBuilder<ID>? buildPageKey;
  final ShellBuildResult<ID> render;

  const BuiltShellDefinition({
    required this.children,
    required this.buildPageKey,
    required this.render,
  });
}
