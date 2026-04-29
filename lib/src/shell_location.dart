import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

final class ShellLocationBuildResult extends LocationBuildResult {
  final LocationWidgetBuilder? buildWidget;
  final SelfBuiltLocationPageBuilder? buildPage;
  final ShellContentBuilder buildShellContent;
  final ShellPageBuilder? buildShellPage;
  final LocationWidgetBuilder? buildDefaultWidget;
  final SelfBuiltLocationPageBuilder? buildDefaultPage;

  const ShellLocationBuildResult({
    required this.buildWidget,
    required this.buildPage,
    required this.buildShellContent,
    this.buildShellPage,
    required this.buildDefaultWidget,
    required this.buildDefaultPage,
  });

  @override
  LocationWidgetBuilder? get buildWidgetOrNull => buildWidget;

  @override
  SelfBuiltLocationPageBuilder? get buildPageOrNull => buildPage;
}

class ShellLocationBuilder extends LocationBuilder {
  ShellContent? _shellContent;
  ShellPageBuilder? _buildShellPage;
  DefaultContent? _defaultContent;
  SelfBuiltLocationPageBuilder? _buildDefaultPage;

  ShellLocationBuilder();

  set shellContent(ShellContent shellContent) {
    if (_shellContent != null) {
      throw StateError(
        'ShellLocationBuilder shellContent was already configured. '
        'shellContent may only be configured once.',
      );
    }
    _shellContent = shellContent;
  }

  set shellPage(ShellPageBuilder page) {
    if (_buildShellPage != null) {
      throw StateError(
        'ShellLocationBuilder shellPage was already configured. '
        'shellPage may only be configured once.',
      );
    }
    _buildShellPage = page;
  }

  /// Configures the root page of the implicit nested slot owned by the shell
  /// location.
  ///
  /// This is most useful when `content = const Content.none()` should suppress
  /// the location's own page while still keeping a default nested page alive.
  set defaultContent(DefaultContent content) {
    if (_defaultContent != null) {
      throw StateError(
        'ShellLocationBuilder defaultContent was already configured. '
        'defaultContent may only be configured once.',
      );
    }
    _defaultContent = content;
  }

  set defaultPage(SelfBuiltLocationPageBuilder page) {
    if (_buildDefaultPage != null) {
      throw StateError(
        'ShellLocationBuilder defaultPage was already configured. '
        'defaultPage may only be configured once.',
      );
    }
    _buildDefaultPage = page;
  }

  @override
  LocationBuildResult? resolveRender({String? debugContext}) {
    final locationRender = super.resolveRender(debugContext: debugContext);
    if (locationRender == null) {
      throw StateError(
        'ShellLocationBuilder requires content. '
        'A shell location does not support the legacy buildPages fallback.',
      );
    }
    final buildDefaultWidget = _resolveDefaultWidgetBuilder(_defaultContent);
    final buildDefaultPage = _resolveDefaultPageBuilder(
      defaultContent: _defaultContent,
      defaultPage: _buildDefaultPage,
    );
    if (locationRender.buildWidgetOrNull == null &&
        buildDefaultWidget == null) {
      throw StateError(
        'ShellLocationBuilder requires rendering content or defaultContent. '
        'Use content, or configure defaultContent/defaultPage for the nested '
        'shell slot when content is Content.none().',
      );
    }
    return ShellLocationBuildResult(
      buildWidget: locationRender.buildWidgetOrNull,
      buildPage: locationRender.buildPageOrNull,
      buildShellContent: (_shellContent ?? const ShellContent.child())
          .resolveBuilder(),
      buildShellPage: _buildShellPage,
      buildDefaultWidget: buildDefaultWidget,
      buildDefaultPage: buildDefaultPage,
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
/// The location's `content` and `page` define the location-owned page rendered
/// inside the nested navigator. `defaultContent` and `defaultPage` define the
/// implicit nested slot's root page beneath routed child pages. `shellContent`
/// and `shellPage` define the outer shell page rendered on the parent
/// navigator.
///
/// Setting [navigatorEnabled] to false disables the nested navigator. The
/// shell location then behaves like a normal [Location] for rendering, while
/// descendants that would normally inherit or explicitly target this shell
/// location's [routerKey] are routed to its parent navigator instead.
abstract class ShellLocation<Self extends AnyLocation<Self>>
    extends AnyLocation<Self>
    implements BuildsWithShellLocationBuilder {
  final WorkingRouterKey routerKey;
  final bool navigatorEnabled;

  ShellLocation({
    super.id,
    super.localId,
    super.parentRouterKey,
    super.tags,
    WorkingRouterKey? routerKey,
    this.navigatorEnabled = true,
  }) : routerKey = routerKey ?? WorkingRouterKey();

  /// A typed reference to this node for child-factory code.
  Self get node => this as Self;

  @override
  ShellLocationBuilder createBuilder() => ShellLocationBuilder();

  ShellLocationBuildResult get _shellLocationRender {
    final render = definition.render;
    if (render is! ShellLocationBuildResult) {
      throw StateError(
        'ShellLocation $runtimeType did not resolve a shell render. '
        'This indicates a framework bug.',
      );
    }
    return render;
  }

  Widget buildShellContent(
    BuildContext context,
    WorkingRouterData data,
    Widget child,
  ) {
    return _shellLocationRender.buildShellContent(context, data, child);
  }

  Page<dynamic> buildShellPage(LocalKey? key, Widget child) {
    return _shellLocationRender.buildShellPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }

  bool get hasDefaultPage => _shellLocationRender.buildDefaultWidget != null;

  List<Page<dynamic>> buildDefaultPages(WorkingRouterData data) {
    return buildDefaultPagesForSlot(
      data: data,
      routerKey: routerKey,
      buildDefaultWidget: _shellLocationRender.buildDefaultWidget,
      buildDefaultPage: _shellLocationRender.buildDefaultPage,
    );
  }
}

LocationWidgetBuilder? _resolveDefaultWidgetBuilder(
  DefaultContent? defaultContent,
) {
  return defaultContent?.resolveWidgetBuilder();
}

SelfBuiltLocationPageBuilder? _resolveDefaultPageBuilder({
  required DefaultContent? defaultContent,
  required SelfBuiltLocationPageBuilder? defaultPage,
}) {
  if (defaultPage != null && defaultContent == null) {
    throw StateError(
      'ShellLocation defaultPage was configured without defaultContent.',
    );
  }
  return defaultPage;
}
