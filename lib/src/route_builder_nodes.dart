import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_tag.dart';
import 'package:working_router/src/route_builder.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/shell.dart';

class RouteNodesBuilder<ID> {
  final List<RouteNode<ID>> children = [];

  T child<T extends RouteNode<ID>>(T node) {
    children.add(node);
    return node;
  }
}

class InlineLocationBuilder<ID> extends LocationBuilder<ID> {
  ID? _id;
  final List<LocationTag> _tags = [];
  GlobalKey<NavigatorState>? _parentNavigatorKey;
  bool? _buildsOwnPage;

  ID? get configuredId => _id;
  List<LocationTag> get configuredTags => _tags;
  GlobalKey<NavigatorState>? get configuredParentNavigatorKey =>
      _parentNavigatorKey;
  bool? get configuredBuildsOwnPage => _buildsOwnPage;

  void id(ID id) {
    if (_id != null) {
      throw StateError('Inline location id was already configured.');
    }
    _id = id;
  }

  void tag(LocationTag tag) {
    _tags.add(tag);
  }

  void tags(Iterable<LocationTag> tags) {
    _tags.addAll(tags);
  }

  void parentNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    if (_parentNavigatorKey != null) {
      throw StateError(
        'Inline location parentNavigatorKey was already configured.',
      );
    }
    _parentNavigatorKey = navigatorKey;
  }

  void buildsOwnPage(bool value) {
    if (_buildsOwnPage != null) {
      throw StateError(
        'Inline location buildsOwnPage was already configured.',
      );
    }
    _buildsOwnPage = value;
  }
}

class InlineShellBuilder<ID> extends ShellBuilder<ID> {
  GlobalKey<NavigatorState>? _navigatorKey;
  GlobalKey<NavigatorState>? _parentNavigatorKey;

  GlobalKey<NavigatorState>? get configuredNavigatorKey => _navigatorKey;
  GlobalKey<NavigatorState>? get configuredParentNavigatorKey =>
      _parentNavigatorKey;

  void navigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    if (_navigatorKey != null) {
      throw StateError('Inline shell navigatorKey was already configured.');
    }
    _navigatorKey = navigatorKey;
  }

  void parentNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    if (_parentNavigatorKey != null) {
      throw StateError(
        'Inline shell parentNavigatorKey was already configured.',
      );
    }
    _parentNavigatorKey = navigatorKey;
  }
}

extension LocationBuilderNodeDsl<ID> on LocationBuilder<ID> {
  Location<ID> location(
    void Function(InlineLocationBuilder<ID> builder) build,
  ) {
    final builder = InlineLocationBuilder<ID>();
    build(builder);
    final node = Location<ID>(
      id: builder.configuredId,
      parentNavigatorKey: builder.configuredParentNavigatorKey,
      tags: builder.configuredTags,
      build: (runtimeBuilder) {
        _copyLocationBuilder(builder, runtimeBuilder);
      },
      buildsOwnPage: builder.configuredBuildsOwnPage,
    );
    child(node);
    return node;
  }

  Shell<ID> shell(void Function(InlineShellBuilder<ID> builder) build) {
    final builder = InlineShellBuilder<ID>();
    build(builder);
    final navigatorKey = builder.configuredNavigatorKey;
    if (navigatorKey == null) {
      throw StateError(
        'Inline shell must configure navigatorKey(...) before it can be used.',
      );
    }
    final node = Shell<ID>(
      navigatorKey: navigatorKey,
      parentNavigatorKey: builder.configuredParentNavigatorKey,
      build: (runtimeBuilder) {
        _copyShellBuilder(builder, runtimeBuilder);
      },
    );
    child(node);
    return node;
  }
}

extension ShellBuilderNodeDsl<ID> on ShellBuilder<ID> {
  Location<ID> location(
    void Function(InlineLocationBuilder<ID> builder) build,
  ) {
    final builder = InlineLocationBuilder<ID>();
    build(builder);
    final node = Location<ID>(
      id: builder.configuredId,
      parentNavigatorKey: builder.configuredParentNavigatorKey,
      tags: builder.configuredTags,
      build: (runtimeBuilder) {
        _copyLocationBuilder(builder, runtimeBuilder);
      },
      buildsOwnPage: builder.configuredBuildsOwnPage,
    );
    child(node);
    return node;
  }

  Shell<ID> shell(void Function(InlineShellBuilder<ID> builder) build) {
    final builder = InlineShellBuilder<ID>();
    build(builder);
    final navigatorKey = builder.configuredNavigatorKey;
    if (navigatorKey == null) {
      throw StateError(
        'Inline shell must configure navigatorKey(...) before it can be used.',
      );
    }
    final node = Shell<ID>(
      navigatorKey: navigatorKey,
      parentNavigatorKey: builder.configuredParentNavigatorKey,
      build: (runtimeBuilder) {
        _copyShellBuilder(builder, runtimeBuilder);
      },
    );
    child(node);
    return node;
  }
}

extension RouteNodesBuilderNodeDsl<ID> on RouteNodesBuilder<ID> {
  Location<ID> location(
    void Function(InlineLocationBuilder<ID> builder) build,
  ) {
    final builder = InlineLocationBuilder<ID>();
    build(builder);
    final node = Location<ID>(
      id: builder.configuredId,
      parentNavigatorKey: builder.configuredParentNavigatorKey,
      tags: builder.configuredTags,
      build: (runtimeBuilder) {
        _copyLocationBuilder(builder, runtimeBuilder);
      },
      buildsOwnPage: builder.configuredBuildsOwnPage,
    );
    child(node);
    return node;
  }

  Shell<ID> shell(void Function(InlineShellBuilder<ID> builder) build) {
    final builder = InlineShellBuilder<ID>();
    build(builder);
    final navigatorKey = builder.configuredNavigatorKey;
    if (navigatorKey == null) {
      throw StateError(
        'Inline shell must configure navigatorKey(...) before it can be used.',
      );
    }
    final node = Shell<ID>(
      navigatorKey: navigatorKey,
      parentNavigatorKey: builder.configuredParentNavigatorKey,
      build: (runtimeBuilder) {
        _copyShellBuilder(builder, runtimeBuilder);
      },
    );
    child(node);
    return node;
  }
}

void _copyLocationBuilder<ID>(
  LocationBuilder<ID> source,
  LocationBuilder<ID> target,
) {
  for (final pathSegment in source.path) {
    target.pathSegment(pathSegment);
  }
  for (final queryParameter in source.queryParameters) {
    target.query(queryParameter);
  }
  for (final child in source.children) {
    target.child(child);
  }
  final buildPageKey = source.buildPageKey;
  if (buildPageKey != null) {
    target.pageKey(buildPageKey);
  }
  final render = source.render;
  switch (render) {
    case LegacyLocationBuildResult<ID>():
      target.legacy();
    case SelfBuiltLocationBuildResult<ID>():
      target.buildPage(
        buildWidget: render.buildWidget,
        buildPage: render.buildPage,
      );
    case null:
      break;
  }
}

void _copyShellBuilder<ID>(
  ShellBuilder<ID> source,
  ShellBuilder<ID> target,
) {
  for (final child in source.children) {
    target.child(child);
  }
  final buildPageKey = source.buildPageKey;
  if (buildPageKey != null) {
    target.pageKey(buildPageKey);
  }
  final render = source.render;
  if (render != null) {
    target.buildWidget(
      render.buildWidget,
      buildPage: render.buildPage,
    );
  }
}
