import 'package:flutter/material.dart';
import 'package:working_router/src/route_node.dart';
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

final class LegacyLocationBuildResult<ID> extends LocationBuildResult<ID> {
  const LegacyLocationBuildResult();
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
  final List<RouteNode<ID>> _children = [];
  RouteNodePageKeyBuilder<ID>? _buildPageKey;
  LocationBuildResult<ID>? _render;

  List<PathSegment> get path => _path;
  List<PathParam<dynamic>> get pathParameters => _pathParameters;
  List<QueryParam<dynamic>> get queryParameters => _queryParameters;
  List<RouteNode<ID>> get children => _children;
  RouteNodePageKeyBuilder<ID>? get buildPageKey => _buildPageKey;
  LocationBuildResult<ID>? get render => _render;

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

  T child<T extends RouteNode<ID>>(T node) {
    _children.add(node);
    return node;
  }

  void pageKey(RouteNodePageKeyBuilder<ID> buildPageKey) {
    _buildPageKey = buildPageKey;
  }

  void buildWidget(
    LocationWidgetBuilder<ID> buildWidget,
  ) {
    _setRender(SelfBuiltLocationBuildResult(buildWidget: buildWidget));
  }

  void buildPage({
    required LocationWidgetBuilder<ID> buildWidget,
    SelfBuiltLocationPageBuilder? buildPage,
  }) {
    _setRender(SelfBuiltLocationBuildResult(
      buildWidget: buildWidget,
      buildPage: buildPage,
    ));
  }

  void legacy() {
    _setRender(const LegacyLocationBuildResult());
  }

  void _setRender(LocationBuildResult<ID> render) {
    if (_render != null) {
      throw StateError(
        'LocationBuilder render was already configured. Only one of '
        'buildWidget(...), buildPage(...), or legacy() may be used.',
      );
    }
    _render = render;
  }
}

class ShellBuilder<ID> {
  final List<RouteNode<ID>> children = [];
  RouteNodePageKeyBuilder<ID>? buildPageKey;
  ShellBuildResult<ID>? _render;

  ShellBuildResult<ID>? get render => _render;

  T child<T extends RouteNode<ID>>(T node) {
    children.add(node);
    return node;
  }

  void pageKey(RouteNodePageKeyBuilder<ID> buildPageKey) {
    this.buildPageKey = buildPageKey;
  }

  void buildWidget(
    ShellWidgetBuilder<ID> buildWidget, {
    ShellPageBuilder? buildPage,
  }) {
    if (_render != null) {
      throw StateError(
        'ShellBuilder render was already configured. '
        'buildWidget(...) may only be called once.',
      );
    }
    _render = ShellBuildResult(buildWidget: buildWidget, buildPage: buildPage);
  }
}

class BuiltLocationDefinition<ID> {
  final List<PathSegment> path;
  final List<PathParam<dynamic>> pathParameters;
  final List<QueryParam<dynamic>> queryParameters;
  final List<RouteNode<ID>> children;
  final RouteNodePageKeyBuilder<ID>? buildPageKey;
  final LocationBuildResult<ID> render;

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
  final List<RouteNode<ID>> children;
  final RouteNodePageKeyBuilder<ID>? buildPageKey;
  final ShellBuildResult<ID> render;

  const BuiltShellDefinition({
    required this.children,
    required this.buildPageKey,
    required this.render,
  });
}
