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
    void Function(
      ShellBuilder<ID> builder,
      Shell<ID> shell,
      WorkingRouterKey routerKey,
    );

final class ShellBuildResult<ID>
    extends PathLocationTreeElementRenderResult<ID> {
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

  set page(ShellPageBuilder page) {
    if (_buildPage != null) {
      throw StateError(
        'ShellBuilder page was already configured. '
        'page may only be configured once.',
      );
    }
    _buildPage = page;
  }

  ShellBuildResult<ID> resolveRender() {
    return ShellBuildResult(
      buildWidget: _buildWidget ?? (_, _, child) => child,
      buildPage: _buildPage,
    );
  }
}

class BuiltShellDefinition<ID> {
  final List<PathSegment> path;
  final List<PathParam<dynamic>> pathParameters;
  final List<QueryParam<dynamic>> queryParameters;
  final List<LocationTreeElement<ID>> children;
  final PageKey<ID>? pageKey;
  final ShellBuildResult<ID> render;

  const BuiltShellDefinition({
    required this.path,
    required this.pathParameters,
    required this.queryParameters,
    required this.children,
    required this.pageKey,
    required this.render,
  });
}

/// A rendering route scope that owns a nested navigator boundary.
///
/// A shell can share path and query definitions with its children, but unlike a
/// [Group], it also renders a wrapper widget/page and hosts a nested navigator
/// for its matched child subtree.
///
/// If no later matched descendant is actually assigned to the shell's
/// [routerKey], the shell does not contribute a page and instead behaves like
/// a [Group] for that match. This makes it possible to keep a shell in the
/// route tree for shared path/query scope while routing descendants to an
/// ancestor navigator on smaller layouts.
///
/// Setting [navigatorEnabled] to false disables the nested navigator
/// completely. The shell then always behaves like a [Group] for rendering,
/// and descendants that would normally inherit or explicitly target this
/// shell's [routerKey] are routed to the shell's parent navigator instead.
///
/// Use a shell when a part of the route tree should stay visible while child
/// locations change inside it, such as a sidebar layout, tab scaffold, or
/// nested flow container.
abstract class AbstractShell<ID> extends PathLocationTreeElement<ID>
    implements BuildsWithShellBuilder<ID> {
  final WorkingRouterKey routerKey;
  final bool navigatorEnabled;

  /// Override-based base class for reusable shell subclasses.
  ///
  /// Use this when a shell is implemented by subclassing and overriding
  /// [build], for example to package a shared navigator boundary into a named
  /// type.
  AbstractShell({
    WorkingRouterKey? routerKey,
    this.navigatorEnabled = true,
    super.parentRouterKey,
  }) : routerKey = routerKey ?? WorkingRouterKey();

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
      pageKey: builder.configuredPageKey,
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
    return _definition.pageKey?.build(this, data) ?? super.buildPageKey(data);
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

/// Callback-based convenience shell.
///
/// Use this when the shell is defined inline with a `build:` callback.
class Shell<ID> extends AbstractShell<ID> {
  final BuildShell<ID> _build;

  Shell({
    super.routerKey,
    super.navigatorEnabled,
    required BuildShell<ID> build,
    super.parentRouterKey,
  }) : _build = build;

  @override
  void build(ShellBuilder<ID> builder) {
    _build(builder, this, routerKey);
  }
}
