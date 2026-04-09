import 'package:flutter/material.dart';
import 'package:working_router/src/location_tree_element.dart';
import 'package:working_router/src/route_builder.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildShell<ID> =
    void Function(ShellBuilder<ID> builder, WorkingRouterKey routerKey);

class Shell<ID> extends LocationTreeElement<ID> {
  final WorkingRouterKey routerKey;
  final BuildShell<ID>? _build;

  Shell({
    WorkingRouterKey? routerKey,
    BuildShell<ID>? build,
    super.parentRouterKey,
  }) : routerKey = routerKey ?? WorkingRouterKey(),
       _build = build;

  @protected
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

  late final BuiltShellDefinition<ID> _definition = _buildDefinition();

  BuiltShellDefinition<ID> _buildDefinition() {
    final builder = ShellBuilder<ID>();
    build(builder);
    final render = builder.resolveRender();
    return BuiltShellDefinition(
      children: List.unmodifiable(builder.children),
      buildPageKey: builder.buildPageKey,
      render: render,
    );
  }

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
