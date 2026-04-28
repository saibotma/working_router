import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildMultiShell =
    void Function(
      MultiShellBuilder builder,
      MultiShell node,
    );

typedef MultiShellContentBuilder =
    Widget Function(
      BuildContext context,
      WorkingRouterData data,
      MultiShellSlotChildren slots,
    );

sealed class MultiShellContent {
  const MultiShellContent();

  factory MultiShellContent.builder(MultiShellContentBuilder builder) =
      _BuilderMultiShellContent;

  MultiShellContentBuilder resolveBuilder() {
    return switch (this) {
      final _BuilderMultiShellContent builderContent => builderContent.builder,
    };
  }
}

final class _BuilderMultiShellContent extends MultiShellContent {
  final MultiShellContentBuilder builder;

  const _BuilderMultiShellContent(this.builder);
}

final class MultiShellSlot {
  final WorkingRouterKey routerKey;
  final String? debugLabel;

  MultiShellSlot.internal({
    WorkingRouterKey? routerKey,
    this.debugLabel,
  }) : routerKey = routerKey ?? WorkingRouterKey();

  @override
  String toString() => 'MultiShellSlot(${debugLabel ?? routerKey.hashCode})';
}

final class MultiShellSlotDefinition {
  final MultiShellSlot slot;
  final bool navigatorEnabled;
  final LocationWidgetBuilder? buildDefaultWidget;
  final SelfBuiltLocationPageBuilder? buildDefaultPage;

  const MultiShellSlotDefinition({
    required this.slot,
    required this.navigatorEnabled,
    required this.buildDefaultWidget,
    required this.buildDefaultPage,
  });

  bool get hasDefault => buildDefaultWidget != null;
}

final class MultiShellResolvedSlot {
  final MultiShellSlotDefinition definition;
  final bool isEnabled;
  final bool hasRoutedContent;

  const MultiShellResolvedSlot({
    required this.definition,
    required this.isEnabled,
    required this.hasRoutedContent,
  });

  MultiShellSlot get slot => definition.slot;
}

/// Internal slot rendering state passed into [MultiShellSlotChildren].
///
/// A slot needs more than just an optional widget because `null` would be
/// ambiguous:
/// - disabled slot: valid, `childOrNull` should return `null`
/// - enabled slot with no resolved content: invalid configuration, should
///   throw when accessed
///
/// [isEnabled] separates those cases so `MultiShellSlotChildren` can keep
/// strict semantics for enabled slots while still allowing disabled slots to be
/// omitted from the layout via `childOrNull`.
final class MultiShellResolvedSlotChild {
  final bool isEnabled;
  final Widget? child;

  const MultiShellResolvedSlotChild({
    required this.isEnabled,
    required this.child,
  });
}

final class MultiShellSlotChildren {
  final Map<MultiShellSlot, MultiShellResolvedSlotChild> _children;

  const MultiShellSlotChildren(this._children);

  /// Returns the widget for an enabled slot.
  ///
  /// Throws when the slot is disabled or when an enabled slot has neither
  /// routed content nor default content.
  Widget child(MultiShellSlot slot) {
    final slotChild = _children[slot];
    if (slotChild == null) {
      throw StateError('Unknown slot $slot.');
    }
    if (!slotChild.isEnabled) {
      throw StateError(
        'Slot $slot is disabled. Use childOrNull(slot) for disabled slots.',
      );
    }
    if (slotChild.child == null) {
      throw StateError(
        'Enabled slot $slot has neither routed content nor default content.',
      );
    }
    return slotChild.child!;
  }

  /// Returns `null` only for disabled slots.
  ///
  /// Enabled slots remain strict: they must resolve to routed content or a
  /// configured default page, otherwise this throws.
  Widget? childOrNull(MultiShellSlot slot) {
    final slotChild = _children[slot];
    if (slotChild == null) {
      throw StateError('Unknown slot $slot.');
    }
    if (!slotChild.isEnabled) {
      return null;
    }
    if (slotChild.child == null) {
      throw StateError(
        'Enabled slot $slot has neither routed content nor default content.',
      );
    }
    return slotChild.child;
  }

  bool hasChild(MultiShellSlot slot) {
    final slotChild = _children[slot];
    if (slotChild == null) {
      throw StateError('Unknown slot $slot.');
    }
    return slotChild.child != null;
  }
}

final class MultiShellBuildResult extends PathRouteNodeRenderResult {
  final List<MultiShellSlotDefinition> slots;
  final MultiShellContentBuilder buildContent;
  final ShellPageBuilder? buildPage;

  const MultiShellBuildResult({
    required this.slots,
    required this.buildContent,
    this.buildPage,
  });
}

class MultiShellBuilder extends PathRouteNodeBuilder {
  final List<MultiShellSlotDefinition> _slots = [];
  MultiShellContent? _content;
  ShellPageBuilder? _buildPage;

  MultiShellBuilder();

  /// Creates an extra sibling slot navigator owned by this multi-shell.
  ///
  /// Enabled slots must either receive routed content from child locations or
  /// define [defaultContent]. When [navigatorEnabled] is `false`, routes
  /// targeted at this slot alias back to the parent navigator.
  MultiShellSlot slot({
    String? debugLabel,
    bool navigatorEnabled = true,
    DefaultContent? defaultContent,
    SelfBuiltLocationPageBuilder? defaultPage,
  }) {
    final slot = MultiShellSlot.internal(debugLabel: debugLabel);
    _slots.add(
      MultiShellSlotDefinition(
        slot: slot,
        navigatorEnabled: navigatorEnabled,
        buildDefaultWidget: _resolveDefaultWidgetBuilder(defaultContent),
        buildDefaultPage: _resolveDefaultPageBuilder(
          defaultContent: defaultContent,
          defaultPage: defaultPage,
        ),
      ),
    );
    return slot;
  }

  set content(MultiShellContent content) {
    if (_content != null) {
      throw StateError(
        'MultiShellBuilder content was already configured. '
        'content may only be configured once.',
      );
    }
    _content = content;
  }

  set page(ShellPageBuilder page) {
    if (_buildPage != null) {
      throw StateError(
        'MultiShellBuilder page was already configured. '
        'page may only be configured once.',
      );
    }
    _buildPage = page;
  }

  MultiShellBuildResult resolveRender() {
    if (_content == null) {
      throw StateError(
        'MultiShellBuilder requires content. '
        'Configure content to place the slot children.',
      );
    }
    return MultiShellBuildResult(
      slots: List.unmodifiable(_slots),
      buildContent: _content!.resolveBuilder(),
      buildPage: _buildPage,
    );
  }
}

/// A structural shell with multiple sibling nested navigators.
///
/// Use a [MultiShell] when one wrapper needs to place several independent
/// routed panes, such as a split view with separate left and right stacks.
/// Unlike [MultiShellLocation], this type is structural only:
/// - it is not terminal on its own
/// - every rendered nested navigator comes from an explicit slot created via
///   [MultiShellBuilder.slot]
///
/// Each enabled slot must resolve to routed content or define default content.
/// Disabled slots alias targeted child routes back to the parent navigator.
abstract class AbstractMultiShell<Self extends AbstractMultiShell<Self>>
    extends PathRouteNode<Self>
    implements BuildsWithMultiShellBuilder {
  final bool navigatorEnabled;

  AbstractMultiShell({
    super.id,
    super.localId,
    super.parentRouterKey,
    this.navigatorEnabled = true,
  });

  @override
  MultiShellBuilder createBuilder() => MultiShellBuilder();

  late final BuiltLocationDefinition _definition = _buildDefinition();

  BuiltLocationDefinition _buildDefinition() {
    final builder = MultiShellBuilder();
    build(builder);
    final render = builder.resolveRender();
    return BuiltLocationDefinition(
      path: List.unmodifiable(builder.path),
      pathParameters: List.unmodifiable(builder.pathParameters),
      queryParameters: List.unmodifiable(builder.queryParameters),
      overlays: List.unmodifiable(builder.overlays),
      children: List.unmodifiable(builder.children),
      pageKey: builder.configuredPageKey,
      pathVisibility: builder.pathVisibility,
      browserHistory: builder.browserHistory,
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
  RoutePathVisibility get pathVisibility => _definition.pathVisibility;

  @override
  RouteBrowserHistory get browserHistory => _definition.browserHistory;

  @override
  List<RouteNode> get children => _definition.children;

  @override
  LocalKey buildPageKey(WorkingRouterData data) {
    return _definition.pageKey?.build(this, data) ?? super.buildPageKey(data);
  }

  MultiShellBuildResult get _multiShellRender {
    final render = _definition.render;
    if (render is! MultiShellBuildResult) {
      throw StateError(
        'MultiShell $runtimeType did not resolve a multi shell render. '
        'This indicates a framework bug.',
      );
    }
    return render;
  }

  List<MultiShellSlot> get slots =>
      _multiShellRender.slots.map((it) => it.slot).toList(growable: false);

  List<MultiShellSlotDefinition> get slotDefinitions => _multiShellRender.slots;

  Widget buildContent(
    BuildContext context,
    WorkingRouterData data,
    MultiShellSlotChildren slots,
  ) {
    return _multiShellRender.buildContent(context, data, slots);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return _multiShellRender.buildPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }
}

/// Callback-based [AbstractMultiShell].
///
/// Use this when defining a structural multi-shell inline instead of
/// subclassing [AbstractMultiShell].
class MultiShell extends AbstractMultiShell<MultiShell> {
  final BuildMultiShell _build;

  MultiShell({
    super.id,
    super.localId,
    super.parentRouterKey,
    super.navigatorEnabled,
    required BuildMultiShell build,
  }) : _build = build;

  @override
  void build(MultiShellBuilder builder) {
    _build(builder, this);
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
      'MultiShell slot defaultPage was configured without defaultContent.',
    );
  }
  return defaultPage;
}
