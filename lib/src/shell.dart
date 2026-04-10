import 'package:flutter/material.dart';
import 'package:working_router/src/location_tree_element.dart';
import 'package:working_router/src/path_location_tree_element.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef ShellWidgetBuilder<ID> =
    Widget Function(
      BuildContext context,
      WorkingRouterData<ID> data,
      Widget child,
    );
typedef ShellPageBuilder = Page<dynamic> Function(LocalKey? key, Widget child);
typedef BuildShell<ID> =
    void Function(ShellBuilder<ID> builder, WorkingRouterKey routerKey);

final class ShellBuildResult<ID> extends PathLocationTreeElementRenderResult<ID> {
  final ShellWidgetBuilder<ID> buildWidget;
  final ShellPageBuilder? buildPage;

  const ShellBuildResult({
    required this.buildWidget,
    this.buildPage,
  });
}

class ShellBuilder<ID> extends PathLocationTreeElementBuilder<ID> {
  ShellWidgetBuilder<ID>? _buildWidget;
  ShellPageBuilder? _buildPage;

  ShellBuilder();

  void widgetBuilder(ShellWidgetBuilder<ID> widget) {
    if (_buildWidget != null) {
      throw StateError(
        'ShellBuilder widget was already configured. '
        'widgetBuilder(...) may only be called once.',
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
          'ShellBuilder page was configured without widgetBuilder(...). '
          'Call widgetBuilder(...) before page(...).',
        );
      }
      throw StateError(
        'ShellBuilder must configure its render with widgetBuilder(...).',
      );
    }
    return ShellBuildResult(buildWidget: _buildWidget!, buildPage: _buildPage);
  }
}

class BuiltShellDefinition<ID> {
  final List<PathSegment> path;
  final List<PathParam<dynamic>> pathParameters;
  final List<QueryParam<dynamic>> queryParameters;
  final List<LocationTreeElement<ID>> children;
  final LocationTreeElementPageKeyBuilder<ID>? buildPageKey;
  final ShellBuildResult<ID> render;

  const BuiltShellDefinition({
    required this.path,
    required this.pathParameters,
    required this.queryParameters,
    required this.children,
    required this.buildPageKey,
    required this.render,
  });
}

class Shell<ID> extends PathLocationTreeElement<ID>
    implements BuildsWithShellBuilder<ID> {
  final WorkingRouterKey routerKey;
  final BuildShell<ID>? _build;

  Shell({
    WorkingRouterKey? routerKey,
    BuildShell<ID>? build,
    super.parentRouterKey,
  }) : routerKey = routerKey ?? WorkingRouterKey(),
       _build = build;

  @protected
  @override
  void build(ShellBuilder<ID> builder) {
    final callback = _build;
    if (callback == null) {
      throw StateError(
        'Shell $runtimeType must either override build(...) or provide '
        'a build callback.',
      );
    }
    callback(builder, routerKey);
  }

  @override
  ShellBuilder<ID> createBuilder() => ShellBuilder<ID>();

  late final BuiltShellDefinition<ID> _definition = _buildDefinition();

  BuiltShellDefinition<ID> _buildDefinition() {
    final builder = ShellBuilder<ID>();
    build(builder);
    final render = builder.resolveRender();
    return BuiltShellDefinition(
      path: List.unmodifiable(builder.path),
      pathParameters: List.unmodifiable(builder.pathParameters),
      queryParameters: List.unmodifiable(builder.queryParameters),
      children: List.unmodifiable(builder.children),
      buildPageKey: builder.buildPageKey,
      render: render,
    );
  }

  @override
  List<PathSegment> get path => _definition.path;

  @override
  List<PathParam<dynamic>> get pathParameters => _definition.pathParameters;

  @override
  List<QueryParam<dynamic>> get queryParameters => _definition.queryParameters;

  @override
  List<LocationTreeElement<ID>> get children => _definition.children;

  @override
  LocalKey buildPageKey(WorkingRouterData<ID> data) {
    return _definition.buildPageKey?.call(data) ?? super.buildPageKey(data);
  }

  Widget buildWidget(
    BuildContext context,
    WorkingRouterData<ID> data,
    Widget child,
  ) {
    return _definition.render.buildWidget(context, data, child);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return _definition.render.buildPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }
}
