import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef ShellContentBuilder<ID> =
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

sealed class ShellContent<ID> {
  const ShellContent();

  factory ShellContent.builder(ShellContentBuilder<ID> builder) =
      _BuilderShellContent<ID>;

  const factory ShellContent.child() = _ChildShellContent<ID>;

  ShellContentBuilder<ID> resolveBuilder() {
    return switch (this) {
      final _BuilderShellContent<ID> builderContent => builderContent.builder,
      _ => (_, _, child) => child,
    };
  }
}

final class _BuilderShellContent<ID> extends ShellContent<ID> {
  final ShellContentBuilder<ID> builder;

  const _BuilderShellContent(this.builder);
}

final class _ChildShellContent<ID> extends ShellContent<ID> {
  const _ChildShellContent();
}

final class ShellBuildResult<ID> extends PathRouteNodeRenderResult<ID> {
  final ShellContentBuilder<ID> buildContent;
  final ShellPageBuilder? buildPage;
  final LocationWidgetBuilder<ID>? buildDefaultWidget;
  final SelfBuiltLocationPageBuilder? buildDefaultPage;

  const ShellBuildResult({
    required this.buildContent,
    this.buildPage,
    required this.buildDefaultWidget,
    required this.buildDefaultPage,
  });
}

class ShellBuilder<ID> extends PathRouteNodeBuilder<ID> {
  ShellContent<ID>? _content;
  ShellPageBuilder? _buildPage;
  DefaultContent<ID>? _defaultContent;
  SelfBuiltLocationPageBuilder? _buildDefaultPage;

  ShellBuilder();

  set content(ShellContent<ID> content) {
    if (_content != null) {
      throw StateError(
        'ShellBuilder content was already configured. '
        'content may only be configured once.',
      );
    }
    _content = content;
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

  /// Configures the root page of the shell's implicit nested slot.
  ///
  /// The default page is built inside the shell navigator and stays beneath
  /// deeper routed shell pages. It does not make the shell terminal by itself;
  /// some descendant route still has to match for the shell to render.
  set defaultContent(DefaultContent<ID> content) {
    if (_defaultContent != null) {
      throw StateError(
        'ShellBuilder defaultContent was already configured. '
        'defaultContent may only be configured once.',
      );
    }
    _defaultContent = content;
  }

  set defaultPage(SelfBuiltLocationPageBuilder page) {
    if (_buildDefaultPage != null) {
      throw StateError(
        'ShellBuilder defaultPage was already configured. '
        'defaultPage may only be configured once.',
      );
    }
    _buildDefaultPage = page;
  }

  ShellBuildResult<ID> resolveRender() {
    return ShellBuildResult(
      buildContent: (_content ?? ShellContent<ID>.child()).resolveBuilder(),
      buildPage: _buildPage,
      buildDefaultWidget: _resolveDefaultWidgetBuilder(_defaultContent),
      buildDefaultPage: _resolveDefaultPageBuilder(
        defaultContent: _defaultContent,
        defaultPage: _buildDefaultPage,
      ),
    );
  }
}

class BuiltShellDefinition<ID> {
  final List<PathSegment> path;
  final List<PathParam<dynamic>> pathParameters;
  final List<QueryParam<dynamic>> queryParameters;
  final List<RouteNode<ID>> children;
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
/// [Scope], it also renders a wrapper widget/page and hosts a nested navigator
/// for its matched child subtree.
///
/// If no later matched descendant is actually assigned to the shell's
/// [routerKey], the shell does not contribute a page and instead behaves like
/// a [Scope] for that match. This makes it possible to keep a shell in the
/// route tree for shared path/query scope while routing descendants to an
/// ancestor navigator on smaller layouts. When [ShellBuilder.defaultContent]
/// is configured, that implicit nested-slot default page keeps the shell
/// renderable even if the matched descendants are all routed elsewhere.
///
/// Setting [navigatorEnabled] to false disables the nested navigator
/// completely. The shell then always behaves like a [Scope] for rendering,
/// and descendants that would normally inherit or explicitly target this
/// shell's [routerKey] are routed to the shell's parent navigator instead.
///
/// Use a shell when a part of the route tree should stay visible while child
/// locations change inside it, such as a sidebar layout, tab scaffold, or
/// nested flow container.
abstract class AbstractShell<ID> extends PathRouteNode<ID>
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
  List<RouteNode<ID>> get children => _definition.children;

  @override
  LocalKey buildPageKey(WorkingRouterData<ID> data) {
    return _definition.pageKey?.build(this, data) ?? super.buildPageKey(data);
  }

  Widget buildContent(
    BuildContext context,
    WorkingRouterData<ID> data,
    Widget child,
  ) {
    return _definition.render.buildContent(context, data, child);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return _definition.render.buildPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }

  bool get hasDefaultPage => _definition.render.buildDefaultWidget != null;

  List<Page<dynamic>> buildDefaultPages(WorkingRouterData<ID> data) {
    return buildDefaultPagesForSlot(
      data: data,
      routerKey: routerKey,
      buildDefaultWidget: _definition.render.buildDefaultWidget,
      buildDefaultPage: _definition.render.buildDefaultPage,
    );
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

LocationWidgetBuilder<ID>? _resolveDefaultWidgetBuilder<ID>(
  DefaultContent<ID>? defaultContent,
) {
  return defaultContent?.resolveWidgetBuilder();
}

SelfBuiltLocationPageBuilder? _resolveDefaultPageBuilder<ID>({
  required DefaultContent<ID>? defaultContent,
  required SelfBuiltLocationPageBuilder? defaultPage,
}) {
  if (defaultPage != null && defaultContent == null) {
    throw StateError(
      'Shell defaultPage was configured without defaultContent.',
    );
  }
  return defaultPage;
}
