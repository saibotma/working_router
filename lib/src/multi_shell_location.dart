import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/multi_shell.dart';
import 'package:working_router/src/path_location_tree_element.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildMultiShellLocation<ID, Self extends AnyLocation<ID>> =
    void Function(
      MultiShellLocationBuilder<ID> builder,
      Self location,
      MultiShellSlot contentSlot,
    );

final class MultiShellLocationBuildResult<ID>
    extends SelfBuiltLocationBuildResult<ID> {
  final MultiShellSlot contentSlot;
  final List<MultiShellSlotDefinition<ID>> slots;
  final MultiShellContentBuilder<ID> buildShellContent;
  final ShellPageBuilder? buildShellPage;

  const MultiShellLocationBuildResult({
    required super.buildWidget,
    super.buildPage,
    required this.contentSlot,
    required this.slots,
    required this.buildShellContent,
    this.buildShellPage,
  });
}

class MultiShellLocationBuilder<ID> extends LocationBuilder<ID> {
  final MultiShellSlot _contentSlot = MultiShellSlot.internal(
    debugLabel: 'content',
  );
  final List<MultiShellSlotDefinition<ID>> _slots = [];
  MultiShellContent<ID>? _shellContent;
  ShellPageBuilder? _buildShellPage;

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
    Content<ID>? defaultContent,
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

  @override
  LocationBuildResult<ID>? resolveRender() {
    final locationRender = super.resolveRender();
    if (locationRender is! SelfBuiltLocationBuildResult<ID>) {
      throw StateError(
        'MultiShellLocationBuilder requires rendering content. '
        'A multi shell location always defines an outer shell page and an '
        'inner location page, so Content.none() and the legacy buildPages '
        'fallback are not supported here.',
      );
    }
    if (_shellContent == null) {
      throw StateError(
        'MultiShellLocationBuilder requires shellContent. '
        'Configure shellContent to place the content slot and any extra slot '
        'children.',
      );
    }
    return MultiShellLocationBuildResult(
      buildWidget: locationRender.buildWidget,
      buildPage: locationRender.buildPage,
      contentSlot: _contentSlot,
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
/// The location's own page always renders in [contentSlot]. Extra slots must
/// be created via [MultiShellLocationBuilder.slot] and may define default
/// content/page. Children without an explicit `parentRouterKey` inherit the
/// [contentSlot].
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
  Content<ID>? defaultContent,
) {
  final builder = defaultContent?.resolveWidgetBuilderOrNull();
  if (defaultContent != null && builder == null) {
    throw StateError(
      'MultiShell slot defaultContent may not be Content.none().',
    );
  }
  return builder;
}

SelfBuiltLocationPageBuilder? _resolveDefaultPageBuilder<ID>({
  required Content<ID>? defaultContent,
  required SelfBuiltLocationPageBuilder? defaultPage,
}) {
  if (defaultPage != null && defaultContent == null) {
    throw StateError(
      'MultiShell slot defaultPage was configured without defaultContent.',
    );
  }
  return defaultPage;
}
