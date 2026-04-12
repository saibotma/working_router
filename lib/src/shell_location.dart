import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildShellLocation<ID, Self extends AnyLocation<ID>> =
    void Function(
      ShellLocationBuilder<ID> builder,
      Self location,
      WorkingRouterKey routerKey,
    );

final class ShellLocationBuildResult<ID>
    extends SelfBuiltLocationBuildResult<ID> {
  final ShellWidgetBuilder<ID> buildShellWidget;
  final ShellPageBuilder? buildShellPage;

  const ShellLocationBuildResult({
    required super.buildWidget,
    super.buildPage,
    required this.buildShellWidget,
    this.buildShellPage,
  });
}

class ShellLocationBuilder<ID> extends LocationBuilder<ID> {
  ShellWidgetBuilder<ID>? _buildShellWidget;
  ShellPageBuilder? _buildShellPage;

  ShellLocationBuilder();

  void shellWidgetBuilder(ShellWidgetBuilder<ID> widget) {
    if (_buildShellWidget != null) {
      throw StateError(
        'ShellLocationBuilder shellWidgetBuilder was already configured. '
        'shellWidgetBuilder(...) may only be called once.',
      );
    }
    _buildShellWidget = widget;
  }

  void shellPage(ShellPageBuilder page) {
    if (_buildShellPage != null) {
      throw StateError(
        'ShellLocationBuilder shellPage was already configured. '
        'shellPage(...) may only be called once.',
      );
    }
    _buildShellPage = page;
  }

  @override
  LocationBuildResult<ID>? resolveRender() {
    final locationRender = super.resolveRender();
    if (locationRender == null) {
      throw StateError(
        'ShellLocationBuilder requires widget(...) or widgetBuilder(...). '
        'A shell location always defines both an outer shell page and an '
        'inner location page.',
      );
    }

    final selfBuiltRender = locationRender as SelfBuiltLocationBuildResult<ID>;
    return ShellLocationBuildResult(
      buildWidget: selfBuiltRender.buildWidget,
      buildPage: selfBuiltRender.buildPage,
      buildShellWidget: _buildShellWidget ?? (_, _, child) => child,
      buildShellPage: _buildShellPage,
    );
  }
}

/// A semantic location that also owns a nested navigator boundary.
///
/// Use a shell location when a route behaves like a normal location with its
/// own `id`, path, widget, page, and children, but also needs an outer shell
/// wrapper on the parent navigator.
///
/// Conceptually this is shorthand for:
/// - an outer [Shell]
/// - with exactly one implicit inner [Location] child
///
/// The location's `widget(...)`, `widgetBuilder(...)`, and `page(...)` define
/// that implicit inner location page rendered inside the nested navigator.
/// `shellWidgetBuilder(...)` and `shellPage(...)` define the outer shell page
/// rendered on the parent navigator.
///
/// Setting [navigatorEnabled] to false disables the nested navigator. The
/// shell location then behaves like a normal [Location] for rendering, while
/// descendants that would normally inherit or explicitly target this shell
/// location's [routerKey] are routed to its parent navigator instead.
abstract class AbstractShellLocation<ID, Self extends AnyLocation<ID>>
    extends AbstractLocation<ID, Self> {
  final WorkingRouterKey routerKey;
  final bool navigatorEnabled;

  /// Override-based base class for reusable shell location subclasses.
  ///
  /// Use this when a shell location is implemented by subclassing and
  /// overriding [buildShellLocation] directly.
  AbstractShellLocation({
    super.id,
    super.parentRouterKey,
    super.tags,
    WorkingRouterKey? routerKey,
    this.navigatorEnabled = true,
  }) : routerKey = routerKey ?? WorkingRouterKey();

  @override
  ShellLocationBuilder<ID> createBuilder() => ShellLocationBuilder<ID>();

  @protected
  void buildShellLocation(ShellLocationBuilder<ID> builder);

  @override
  void build(LocationBuilder<ID> builder) {
    buildShellLocation(builder as ShellLocationBuilder<ID>);
  }

  ShellLocationBuildResult<ID> get _shellLocationRender {
    final render = definition.render;
    if (render is! ShellLocationBuildResult<ID>) {
      throw StateError(
        'ShellLocation $runtimeType did not resolve a shell render. '
        'This indicates a framework bug.',
      );
    }
    return render;
  }

  Widget buildShellWidget(
    BuildContext context,
    WorkingRouterData<ID> data,
    Widget child,
  ) {
    return _shellLocationRender.buildShellWidget(context, data, child);
  }

  Page<dynamic> buildShellPage(LocalKey? key, Widget child) {
    return _shellLocationRender.buildShellPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }
}

/// Callback-based convenience shell location.
///
/// Use this when the shell location is defined inline with a `build:` callback.
class ShellLocation<ID, Self extends AnyLocation<ID>>
    extends AbstractShellLocation<ID, Self> {
  final BuildShellLocation<ID, Self> _build;

  ShellLocation({
    super.id,
    super.parentRouterKey,
    super.tags,
    super.routerKey,
    super.navigatorEnabled,
    required BuildShellLocation<ID, Self> build,
  }) : _build = build;

  @override
  void buildShellLocation(ShellLocationBuilder<ID> builder) {
    _build(builder, this as Self, routerKey);
  }
}
