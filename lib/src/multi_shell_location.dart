import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/multi_shell.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildMultiShellLocation<ID, Self extends AnyLocation<ID>> =
    void Function(
      MultiShellLocationBuilder<ID> builder,
      Self node,
      MultiShellSlot contentSlot,
    );

final class MultiShellLocationBuildResult<ID> extends LocationBuildResult<ID> {
  final LocationWidgetBuilder<ID>? buildWidget;
  final SelfBuiltLocationPageBuilder? buildPage;
  final MultiShellSlot contentSlot;
  final LocationWidgetBuilder<ID>? buildContentDefaultWidget;
  final SelfBuiltLocationPageBuilder? buildContentDefaultPage;
  final List<MultiShellSlotDefinition<ID>> slots;
  final MultiShellContentBuilder<ID> buildShellContent;
  final ShellPageBuilder? buildShellPage;

  const MultiShellLocationBuildResult({
    required this.buildWidget,
    required this.buildPage,
    required this.contentSlot,
    required this.buildContentDefaultWidget,
    required this.buildContentDefaultPage,
    required this.slots,
    required this.buildShellContent,
    this.buildShellPage,
  });

  @override
  LocationWidgetBuilder<ID>? get buildWidgetOrNull => buildWidget;

  @override
  SelfBuiltLocationPageBuilder? get buildPageOrNull => buildPage;
}

class MultiShellLocationBuilder<ID> extends LocationBuilder<ID> {
  final MultiShellSlot _contentSlot = MultiShellSlot.internal(
    debugLabel: 'content',
  );
  final List<MultiShellSlotDefinition<ID>> _slots = [];
  MultiShellContent<ID>? _shellContent;
  ShellPageBuilder? _buildShellPage;
  DefaultContent<ID>? _defaultContent;
  SelfBuiltLocationPageBuilder? _buildDefaultPage;

  MultiShellLocationBuilder();

  /// Creates an extra sibling slot navigator beside the built-in content slot.
  ///
  /// The location's own page always renders in the implicit `contentSlot`;
  /// extra slots created here are for additional panes. Enabled slots must
  /// either receive routed content from child locations or define
  /// [defaultContent]. When [navigatorEnabled] is `false`, routes targeted at
  /// this slot alias back to the parent navigator.
  MultiShellSlot slot({
    String? debugLabel,
    bool navigatorEnabled = true,
    DefaultContent<ID>? defaultContent,
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

  set shellContent(MultiShellContent<ID> shellContent) {
    if (_shellContent != null) {
      throw StateError(
        'MultiShellLocationBuilder shellContent was already configured. '
        'shellContent may only be configured once.',
      );
    }
    _shellContent = shellContent;
  }

  set shellPage(ShellPageBuilder page) {
    if (_buildShellPage != null) {
      throw StateError(
        'MultiShellLocationBuilder shellPage was already configured. '
        'shellPage may only be configured once.',
      );
    }
    _buildShellPage = page;
  }

  /// Configures the root page of the implicit `contentSlot`.
  ///
  /// This is most useful when `content = const Content.none()` should suppress
  /// the location-owned page while the content slot still keeps a default page
  /// beneath deeper routed pages.
  set defaultContent(DefaultContent<ID> content) {
    if (_defaultContent != null) {
      throw StateError(
        'MultiShellLocationBuilder defaultContent was already configured. '
        'defaultContent may only be configured once.',
      );
    }
    _defaultContent = content;
  }

  set defaultPage(SelfBuiltLocationPageBuilder page) {
    if (_buildDefaultPage != null) {
      throw StateError(
        'MultiShellLocationBuilder defaultPage was already configured. '
        'defaultPage may only be configured once.',
      );
    }
    _buildDefaultPage = page;
  }

  @override
  LocationBuildResult<ID>? resolveRender() {
    final locationRender = super.resolveRender();
    if (locationRender == null) {
      throw StateError(
        'MultiShellLocationBuilder requires content. '
        'A multi shell location does not support the legacy buildPages '
        'fallback.',
      );
    }
    if (_shellContent == null) {
      throw StateError(
        'MultiShellLocationBuilder requires shellContent. '
        'Configure shellContent to place the content slot and any extra slot '
        'children.',
      );
    }
    final buildContentDefaultWidget = _resolveDefaultWidgetBuilder(
      _defaultContent,
    );
    final buildContentDefaultPage = _resolveDefaultPageBuilder(
      defaultContent: _defaultContent,
      defaultPage: _buildDefaultPage,
    );
    if (locationRender.buildWidgetOrNull == null &&
        buildContentDefaultWidget == null) {
      throw StateError(
        'MultiShellLocationBuilder requires rendering content or '
        'defaultContent. Use content, or configure defaultContent/defaultPage '
        'for the implicit content slot when content is Content.none().',
      );
    }
    return MultiShellLocationBuildResult(
      buildWidget: locationRender.buildWidgetOrNull,
      buildPage: locationRender.buildPageOrNull,
      contentSlot: _contentSlot,
      buildContentDefaultWidget: buildContentDefaultWidget,
      buildContentDefaultPage: buildContentDefaultPage,
      slots: List.unmodifiable(_slots),
      buildShellContent: _shellContent!.resolveBuilder(),
      buildShellPage: _buildShellPage,
    );
  }
}

/// A semantic location that also owns multiple sibling nested navigators.
///
/// A multi shell location combines:
/// - a normal location `id`, path, params, content, and page
/// - an outer shell wrapper/page rendered on the parent navigator
/// - extra sibling slot navigators for parallel routed panes
///
/// The location's own page renders in [contentSlot]. `defaultContent` and
/// `defaultPage` configure that implicit slot's root page beneath routed child
/// pages. Extra slots must be created via [MultiShellLocationBuilder.slot] and
/// may define their own default content/page. Children without an explicit
/// `parentRouterKey` inherit the [contentSlot].
abstract class AbstractMultiShellLocation<ID, Self extends AnyLocation<ID>>
    extends AnyLocation<ID>
    implements BuildsWithMultiShellLocationBuilder<ID> {
  final MultiShellSlot contentSlot;
  final bool navigatorEnabled;

  AbstractMultiShellLocation({
    super.id,
    super.parentRouterKey,
    super.tags,
    WorkingRouterKey? contentRouterKey,
    this.navigatorEnabled = true,
  }) : contentSlot = MultiShellSlot.internal(
         routerKey: contentRouterKey,
         debugLabel: 'content',
       );

  @override
  MultiShellLocationBuilder<ID> createBuilder() => MultiShellLocationBuilder();

  MultiShellLocationBuildResult<ID> get _multiShellRender {
    final render = definition.render;
    if (render is! MultiShellLocationBuildResult<ID>) {
      throw StateError(
        'MultiShellLocation $runtimeType did not resolve a multi shell render. '
        'This indicates a framework bug.',
      );
    }
    return render;
  }

  WorkingRouterKey get contentRouterKey => contentSlot.routerKey;

  List<MultiShellSlot> get allSlots => [contentSlot, ...slots];

  List<MultiShellSlot> get slots =>
      _multiShellRender.slots.map((it) => it.slot).toList(growable: false);

  List<MultiShellSlotDefinition<ID>> get slotDefinitions =>
      _multiShellRender.slots;

  MultiShellSlotDefinition<ID> get contentSlotDefinition =>
      MultiShellSlotDefinition(
        slot: contentSlot,
        navigatorEnabled: true,
        buildDefaultWidget: _multiShellRender.buildContentDefaultWidget,
        buildDefaultPage: _multiShellRender.buildContentDefaultPage,
      );

  Widget buildShellContent(
    BuildContext context,
    WorkingRouterData<ID> data,
    MultiShellSlotChildren<ID> slots,
  ) {
    return _multiShellRender.buildShellContent(context, data, slots);
  }

  Page<dynamic> buildShellPage(LocalKey? key, Widget child) {
    return _multiShellRender.buildShellPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }
}

/// Callback-based [AbstractMultiShellLocation].
///
/// Use this when defining a multi shell location inline instead of subclassing
/// [AbstractMultiShellLocation]. The `build` callback receives the built-in
/// `contentSlot` explicitly.
class MultiShellLocation<ID, Self extends AnyLocation<ID>>
    extends AbstractMultiShellLocation<ID, Self> {
  final BuildMultiShellLocation<ID, Self> _build;

  MultiShellLocation({
    super.id,
    super.parentRouterKey,
    super.tags,
    super.contentRouterKey,
    super.navigatorEnabled,
    required BuildMultiShellLocation<ID, Self> build,
  }) : _build = build;

  @override
  void build(MultiShellLocationBuilder<ID> builder) {
    _build(builder, this as Self, contentSlot);
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
      'MultiShell slot defaultPage was configured without defaultContent.',
    );
  }
  return defaultPage;
}
