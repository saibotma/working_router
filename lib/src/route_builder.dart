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
  LocationWidgetBuilder<ID>? _buildWidget;
  SelfBuiltLocationPageBuilder? _buildPage;

  List<PathSegment> get path => _path;
  List<PathParam<dynamic>> get pathParameters => _pathParameters;
  List<QueryParam<dynamic>> get queryParameters => _queryParameters;
  List<LocationTreeElement<ID>> get children => _children;
  RouteNodePageKeyBuilder<ID>? get buildPageKey => _buildPageKey;

  LocationBuilder();

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

  QueryParam<Uri> uriQueryParam(
    String name, {
    bool optional = false,
  }) {
    return queryParam(name, const UriRouteParamCodec(), optional: optional);
  }

  QueryParam<T> enumQueryParam<T extends Enum>(
    String name,
    List<T> values, {
    bool optional = false,
  }) {
    return queryParam(
      name,
      EnumRouteParamCodec(values),
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
    if (_buildWidget != null) {
      throw StateError(
        'LocationBuilder widget was already configured. '
        'widget(...) may only be called once.',
      );
    }
    _buildWidget = widget;
  }

  void page(SelfBuiltLocationPageBuilder page) {
    if (_buildPage != null) {
      throw StateError(
        'LocationBuilder page was already configured. '
        'page(...) may only be called once.',
      );
    }
    _buildPage = page;
  }

  LocationBuildResult<ID>? resolveRender() {
    if (_buildWidget == null) {
      if (_buildPage != null) {
        throw StateError(
          'LocationBuilder page was configured without widget(...). '
          'Call widget(...) before page(...).',
        );
      }
      return null;
    }
    return SelfBuiltLocationBuildResult(
      buildWidget: _buildWidget!,
      buildPage: _buildPage,
    );
  }
}

class ShellBuilder<ID> {
  List<LocationTreeElement<ID>> _children = const [];
  bool _childrenAssigned = false;
  RouteNodePageKeyBuilder<ID>? buildPageKey;
  ShellWidgetBuilder<ID>? _buildWidget;
  ShellPageBuilder? _buildPage;

  List<LocationTreeElement<ID>> get children => _children;

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

  void widget(ShellWidgetBuilder<ID> widget) {
    if (_buildWidget != null) {
      throw StateError(
        'ShellBuilder widget was already configured. '
        'widget(...) may only be called once.',
      );
    }
    _buildWidget = widget;
  }

  void page(ShellPageBuilder page) {
    if (_buildPage != null) {
      throw StateError(
        'ShellBuilder page was already configured. '
        'page(...) may only be called once.',
      );
    }
    _buildPage = page;
  }

  ShellBuildResult<ID> resolveRender() {
    if (_buildWidget == null) {
      if (_buildPage != null) {
        throw StateError(
          'ShellBuilder page was configured without widget(...). '
          'Call widget(...) before page(...).',
        );
      }
      throw StateError(
        'ShellBuilder must configure its render with widget(...).',
      );
    }
    return ShellBuildResult(buildWidget: _buildWidget!, buildPage: _buildPage);
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
