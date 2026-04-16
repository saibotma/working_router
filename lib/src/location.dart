import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location_tag.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildLocation<ID, Self extends AnyLocation<ID>> =
    void Function(LocationBuilder<ID> builder, Self location);
typedef LocationWidgetBuilder<ID> =
    Widget Function(BuildContext context, WorkingRouterData<ID> data);
typedef SelfBuiltLocationPageBuilder =
    Page<dynamic> Function(LocalKey? key, Widget child);

sealed class Content<ID> {
  const Content();

  factory Content.widget(Widget widget) = _StaticContent<ID>;

  factory Content.builder(LocationWidgetBuilder<ID> builder) =
      _BuilderContent<ID>;

  const factory Content.none() = _NoContent<ID>;

  LocationWidgetBuilder<ID>? resolveWidgetBuilderOrNull() {
    return switch (this) {
      final _StaticContent<ID> staticContent => (_, _) => staticContent.widget,
      final _BuilderContent<ID> builderContent => builderContent.builder,
      _NoContent<ID>() => null,
    };
  }
}

sealed class DefaultContent<ID> {
  const DefaultContent();

  factory DefaultContent.widget(Widget widget) = _StaticDefaultContent<ID>;

  factory DefaultContent.builder(LocationWidgetBuilder<ID> builder) =
      _BuilderDefaultContent<ID>;

  LocationWidgetBuilder<ID> resolveWidgetBuilder() {
    return switch (this) {
      final _StaticDefaultContent<ID> staticContent =>
        (_, _) => staticContent.widget,
      final _BuilderDefaultContent<ID> builderContent => builderContent.builder,
    };
  }
}

final class _StaticContent<ID> extends Content<ID> {
  final Widget widget;

  const _StaticContent(this.widget);
}

final class _BuilderContent<ID> extends Content<ID> {
  final LocationWidgetBuilder<ID> builder;

  const _BuilderContent(this.builder);
}

final class _NoContent<ID> extends Content<ID> {
  const _NoContent();
}

final class _StaticDefaultContent<ID> extends DefaultContent<ID> {
  final Widget widget;

  const _StaticDefaultContent(this.widget);
}

final class _BuilderDefaultContent<ID> extends DefaultContent<ID> {
  final LocationWidgetBuilder<ID> builder;

  const _BuilderDefaultContent(this.builder);
}

abstract class LocationBuildResult<ID> extends PathRouteNodeRenderResult<ID> {
  const LocationBuildResult();

  LocationWidgetBuilder<ID>? get buildWidgetOrNull;

  SelfBuiltLocationPageBuilder? get buildPageOrNull;
}

final class SelfBuiltLocationBuildResult<ID> extends LocationBuildResult<ID> {
  final LocationWidgetBuilder<ID> buildWidget;
  final SelfBuiltLocationPageBuilder? buildPage;

  const SelfBuiltLocationBuildResult({
    required this.buildWidget,
    this.buildPage,
  });

  @override
  LocationWidgetBuilder<ID>? get buildWidgetOrNull => buildWidget;

  @override
  SelfBuiltLocationPageBuilder? get buildPageOrNull => buildPage;
}

final class NonRenderingLocationBuildResult<ID>
    extends LocationBuildResult<ID> {
  const NonRenderingLocationBuildResult();

  @override
  LocationWidgetBuilder<ID>? get buildWidgetOrNull => null;

  @override
  SelfBuiltLocationPageBuilder? get buildPageOrNull => null;
}

class LocationBuilder<ID> extends PathRouteNodeBuilder<ID> {
  Content<ID>? _content;
  SelfBuiltLocationPageBuilder? _buildPage;

  LocationBuilder();

  set content(Content<ID> content) {
    if (_content != null) {
      throw StateError(
        'LocationBuilder content was already configured. '
        'content may only be configured once.',
      );
    }
    _content = content;
  }

  set page(SelfBuiltLocationPageBuilder page) {
    if (_buildPage != null) {
      throw StateError(
        'LocationBuilder page was already configured. '
        'page may only be configured once.',
      );
    }
    _buildPage = page;
  }

  LocationBuildResult<ID>? resolveRender() {
    if (_content == null) {
      if (_buildPage != null) {
        throw StateError(
          'LocationBuilder page was configured without content. '
          'Configure content before setting page.',
        );
      }
      return null;
    }

    return switch (_content!) {
      final _StaticContent<ID> staticContent => SelfBuiltLocationBuildResult(
        buildWidget: (_, _) => staticContent.widget,
        buildPage: _buildPage,
      ),
      final _BuilderContent<ID> builderContent => SelfBuiltLocationBuildResult(
        buildWidget: builderContent.builder,
        buildPage: _buildPage,
      ),
      _NoContent<ID>() => () {
        if (_buildPage != null) {
          throw StateError(
            'LocationBuilder page was configured for Content.none(). '
            'Non-rendering locations may not configure page.',
          );
        }
        return NonRenderingLocationBuildResult<ID>();
      }(),
    };
  }
}

class BuiltLocationDefinition<ID> {
  final List<PathSegment> path;
  final List<PathParam<dynamic>> pathParameters;
  final List<QueryParam<dynamic>> queryParameters;
  final List<RouteNode<ID>> children;
  final PageKey<ID>? pageKey;
  final PathRouteNodeRenderResult<ID>? render;

  const BuiltLocationDefinition({
    required this.path,
    required this.pathParameters,
    required this.queryParameters,
    required this.children,
    required this.pageKey,
    required this.render,
  });
}

/// Erased router-facing base type for all locations.
///
/// [`Location`] is the callback-based convenience type, while
/// [`AbstractLocation`] is the override-based base for custom subclasses:
///
/// ```dart
/// class ALocation extends AbstractLocation<RouteId, ALocation> { ... }
/// ```
///
/// Router internals, matched location lists, and generic predicates still need
/// a single common type that means "any location in the tree" without exposing
/// that self-type parameter everywhere. This base provides that erased view,
/// while the public location types remain the authoring APIs.
abstract class AnyLocation<ID> extends PathRouteNode<ID> {
  final ID? id;
  final ISet<LocationTag> tags;

  AnyLocation({
    this.id,
    super.parentRouterKey,
    Iterable<LocationTag> tags = const [],
  }) : tags = tags.toISet();

  bool get contributesPage => switch (definition.render) {
    final LocationBuildResult<ID> render => render.buildWidgetOrNull != null,
    null => true,
    _ => false,
  };

  bool get buildsOwnPage => switch (definition.render) {
    final LocationBuildResult<ID> render => render.buildWidgetOrNull != null,
    _ => false,
  };

  Widget? buildWidget(BuildContext context, WorkingRouterData<ID> data) {
    final render = definition.render;
    final buildWidget = switch (render) {
      final LocationBuildResult<ID> locationRender =>
        locationRender.buildWidgetOrNull,
      _ => null,
    };
    if (buildWidget == null) {
      return null;
    }
    return buildWidget(context, data);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    final render = definition.render;
    final buildPage = switch (render) {
      final LocationBuildResult<ID> locationRender =>
        locationRender.buildPageOrNull,
      _ => null,
    };
    if (buildPage == null) {
      return MaterialPage<dynamic>(key: key, child: child);
    }
    return buildPage(key, child);
  }

  bool get shouldBeSkippedOnRouteBack => false;

  bool hasTag(LocationTag tag) => tags.contains(tag);

  IList<RouteNode<ID>> matchRelative(
    bool Function(AnyLocation<ID> location) predicate,
  ) {
    for (final child in children) {
      final childMatch = matchRelativeNode(child, predicate);
      if (childMatch.isNotEmpty) {
        return childMatch;
      }
    }

    return emptyNodeMatch();
  }

  AnyLocation<ID>? pop() {
    return null;
  }

  /// The default equality ensures that a location
  /// can be used as a [Page] key.
  /// Therefore children and tags are not relevant,
  /// because they may change during runtime, and should not
  /// cause a page rebuild.
  /// Two locations are considered equal if they have the same type
  /// and the same id (including both having null id).
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AnyLocation<dynamic> &&
            runtimeType == other.runtimeType &&
            id == other.id;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

abstract class AbstractLocation<ID, Self extends AnyLocation<ID>>
    extends AnyLocation<ID>
    implements BuildsWithLocationBuilder<ID> {
  /// Override-based base class for reusable location subclasses.
  ///
  /// Use this when a location is implemented by subclassing and overriding
  /// [build] directly.
  AbstractLocation({
    super.id,
    super.parentRouterKey,
    super.tags,
  });

  @override
  LocationBuilder<ID> createBuilder() => LocationBuilder<ID>();
}

class Location<ID, Self extends AnyLocation<ID>>
    extends AbstractLocation<ID, Self> {
  final BuildLocation<ID, Self> _build;

  /// Callback-based convenience location.
  ///
  /// Use this when the location is defined inline with a `build:` callback.
  Location({
    super.id,
    super.parentRouterKey,
    super.tags,
    required BuildLocation<ID, Self> build,
  }) : _build = build;

  @override
  void build(LocationBuilder<ID> builder) {
    _build(builder, this as Self);
  }
}

List<Page<dynamic>> buildDefaultPagesForSlot<ID>({
  required WorkingRouterData<ID> data,
  required WorkingRouterKey routerKey,
  required LocationWidgetBuilder<ID>? buildDefaultWidget,
  required SelfBuiltLocationPageBuilder? buildDefaultPage,
}) {
  if (buildDefaultWidget == null) {
    return const [];
  }

  final defaultChild = InheritedWorkingRouterData(
    data: data,
    child: Builder(
      builder: (context) {
        return buildDefaultWidget(context, data);
      },
    ),
  );
  final key = ValueKey((routerKey, 'default'));
  return [
    buildDefaultPage?.call(key, defaultChild) ??
        MaterialPage<dynamic>(key: key, child: defaultChild),
  ];
}
