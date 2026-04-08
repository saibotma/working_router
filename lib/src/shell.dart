import 'package:flutter/material.dart';
import 'package:working_router/src/route_builder.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';

typedef BuildShell<ID> =
    void Function(ShellBuilder<ID> builder);

class Shell<ID> extends RouteNode<ID> {
  final GlobalKey<NavigatorState> navigatorKey;
  final BuildShell<ID>? _build;

  Shell({
    required this.navigatorKey,
    BuildShell<ID>? build,
    super.parentNavigatorKey,
  }) : _build = build;

  @protected
  void build(ShellBuilder<ID> builder) {
    final callback = _build;
    if (callback == null) {
      throw StateError(
        'Shell $runtimeType must either override build(...) or provide '
        'a build callback.',
      );
    }
    return callback(builder);
  }

  late final BuiltShellDefinition<ID> _definition = _buildDefinition();

  BuiltShellDefinition<ID> _buildDefinition() {
    final builder = ShellBuilder<ID>();
    build(builder);
    final render = builder.render;
    if (render == null) {
      throw StateError(
        'Shell $runtimeType must configure its render with '
        'buildWidget(...).',
      );
    }
    return BuiltShellDefinition(
      children: List.unmodifiable(builder.children),
      buildPageKey: builder.buildPageKey,
      render: render,
    );
  }

  @override
  List<RouteNode<ID>> get children => _definition.children;

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
