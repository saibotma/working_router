import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_tree_element.dart';
import 'package:working_router/src/path_location_tree_element.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildMultiShell<ID> =
    void Function(
      MultiShellBuilder<ID> builder,
      MultiShell<ID> shell,
    );

typedef BuildMultiShellLocation<ID, Self extends AnyLocation<ID>> =
    void Function(
      MultiShellLocationBuilder<ID> builder,
      Self location,
      MultiShellSlot contentSlot,
    );

typedef MultiShellContentBuilder<ID> =
    Widget Function(
      BuildContext context,
      WorkingRouterData<ID> data,
      MultiShellSlotChildren<ID> slots,
    );

sealed class MultiShellContent<ID> {
  const MultiShellContent();

  factory MultiShellContent.builder(MultiShellContentBuilder<ID> builder) =
      _BuilderMultiShellContent<ID>;

  MultiShellContentBuilder<ID> resolveBuilder() {
    return switch (this) {
      final _BuilderMultiShellContent<ID> builderContent =>
        builderContent.builder,
    };
  }
}

final class _BuilderMultiShellContent<ID> extends MultiShellContent<ID> {
  final MultiShellContentBuilder<ID> builder;

  const _BuilderMultiShellContent(this.builder);
}

final class MultiShellSlot {
  final WorkingRouterKey routerKey;
  final String? debugLabel;

  MultiShellSlot._({
    WorkingRouterKey? routerKey,
    this.debugLabel,
  }) : routerKey = routerKey ?? WorkingRouterKey();

  @override
  String toString() => 'MultiShellSlot(${debugLabel ?? routerKey.hashCode})';
}

final class MultiShellSlotChildren<ID> {
  final Map<MultiShellSlot, Widget> _children;

  const MultiShellSlotChildren(this._children);

  Widget child(MultiShellSlot slot) =>
      _children[slot] ?? const SizedBox.shrink();

  bool hasChild(MultiShellSlot slot) => _children.containsKey(slot);
}

final class MultiShellBuildResult<ID>
    extends PathLocationTreeElementRenderResult<ID> {
  final List<MultiShellSlot> slots;
  final MultiShellContentBuilder<ID> buildContent;
  final ShellPageBuilder? buildPage;

  const MultiShellBuildResult({
    required this.slots,
    required this.buildContent,
    this.buildPage,
  });
}

final class MultiShellLocationBuildResult<ID>
    extends SelfBuiltLocationBuildResult<ID> {
  final MultiShellSlot contentSlot;
  final List<MultiShellSlot> slots;
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

class MultiShellBuilder<ID> extends PathLocationTreeElementBuilder<ID> {
  final List<MultiShellSlot> _slots = [];
  MultiShellContent<ID>? _content;
  ShellPageBuilder? _buildPage;

  MultiShellBuilder();

  MultiShellSlot slot({String? debugLabel}) {
    final slot = MultiShellSlot._(debugLabel: debugLabel);
    _slots.add(slot);
    return slot;
  }

  set content(MultiShellContent<ID> content) {
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

  MultiShellBuildResult<ID> resolveRender() {
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

class MultiShellLocationBuilder<ID> extends LocationBuilder<ID> {
  final MultiShellSlot _contentSlot = MultiShellSlot._(debugLabel: 'content');
  final List<MultiShellSlot> _slots = [];
  MultiShellContent<ID>? _shellContent;
  ShellPageBuilder? _buildShellPage;

  MultiShellLocationBuilder();

  MultiShellSlot slot({String? debugLabel}) {
    final slot = MultiShellSlot._(debugLabel: debugLabel);
    _slots.add(slot);
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

abstract class AbstractMultiShell<ID> extends PathLocationTreeElement<ID>
    implements BuildsWithMultiShellBuilder<ID> {
  final bool navigatorEnabled;

  AbstractMultiShell({
    super.parentRouterKey,
    this.navigatorEnabled = true,
  });

  @override
  MultiShellBuilder<ID> createBuilder() => MultiShellBuilder<ID>();

  late final BuiltLocationDefinition<ID> _definition = _buildDefinition();

  BuiltLocationDefinition<ID> _buildDefinition() {
    final builder = MultiShellBuilder<ID>();
    build(builder);
    final render = builder.resolveRender();
    return BuiltLocationDefinition(
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

  MultiShellBuildResult<ID> get _multiShellRender {
    final render = _definition.render;
    if (render is! MultiShellBuildResult<ID>) {
      throw StateError(
        'MultiShell $runtimeType did not resolve a multi shell render. '
        'This indicates a framework bug.',
      );
    }
    return render;
  }

  List<MultiShellSlot> get slots => _multiShellRender.slots;

  Widget buildContent(
    BuildContext context,
    WorkingRouterData<ID> data,
    MultiShellSlotChildren<ID> slots,
  ) {
    return _multiShellRender.buildContent(context, data, slots);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return _multiShellRender.buildPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }
}

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
  }) : contentSlot = MultiShellSlot._(
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

  List<MultiShellSlot> get slots => _multiShellRender.slots;

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

class MultiShell<ID> extends AbstractMultiShell<ID> {
  final BuildMultiShell<ID> _build;

  MultiShell({
    super.parentRouterKey,
    super.navigatorEnabled,
    required BuildMultiShell<ID> build,
  }) : _build = build;

  @override
  void build(MultiShellBuilder<ID> builder) {
    _build(builder, this);
  }
}
