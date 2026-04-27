import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location_tag.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/route_node.dart'
    show
        PageKey,
        PathParam,
        PathSegment,
        QueryFilter,
        QueryParam,
        RouteNode,
        emptyNodeMatch,
        matchRelativeNode;
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildLocation<Self extends AnyLocation<Self>> =
    void Function(LocationBuilder builder, Self node);
typedef BuildAnonymousLocation =
    void Function(LocationBuilder builder, AnonymousLocation node);
typedef LocationWidgetBuilder =
    Widget Function(BuildContext context, WorkingRouterData data);
typedef SelfBuiltLocationPageBuilder =
    Page<dynamic> Function(LocalKey? key, Widget child);

sealed class Content {
  const Content();

  factory Content.widget(Widget widget) = _StaticContent;

  factory Content.builder(LocationWidgetBuilder builder) = _BuilderContent;

  const factory Content.none() = _NoContent;

  LocationWidgetBuilder? resolveWidgetBuilderOrNull() {
    return switch (this) {
      final _StaticContent staticContent => (_, _) => staticContent.widget,
      final _BuilderContent builderContent => builderContent.builder,
      _NoContent() => null,
    };
  }
}

sealed class DefaultContent {
  const DefaultContent();

  factory DefaultContent.widget(Widget widget) = _StaticDefaultContent;

  factory DefaultContent.builder(LocationWidgetBuilder builder) =
      _BuilderDefaultContent;

  LocationWidgetBuilder resolveWidgetBuilder() {
    return switch (this) {
      final _StaticDefaultContent staticContent =>
        (_, _) => staticContent.widget,
      final _BuilderDefaultContent builderContent => builderContent.builder,
    };
  }
}

final class _StaticContent extends Content {
  final Widget widget;

  const _StaticContent(this.widget);
}

final class _BuilderContent extends Content {
  final LocationWidgetBuilder builder;

  const _BuilderContent(this.builder);
}

final class _NoContent extends Content {
  const _NoContent();
}

final class _StaticDefaultContent extends DefaultContent {
  final Widget widget;

  const _StaticDefaultContent(this.widget);
}

final class _BuilderDefaultContent extends DefaultContent {
  final LocationWidgetBuilder builder;

  const _BuilderDefaultContent(this.builder);
}

abstract class LocationBuildResult extends PathRouteNodeRenderResult {
  const LocationBuildResult();

  LocationWidgetBuilder? get buildWidgetOrNull;

  SelfBuiltLocationPageBuilder? get buildPageOrNull;
}

final class SelfBuiltLocationBuildResult extends LocationBuildResult {
  final LocationWidgetBuilder buildWidget;
  final SelfBuiltLocationPageBuilder? buildPage;

  const SelfBuiltLocationBuildResult({
    required this.buildWidget,
    this.buildPage,
  });

  @override
  LocationWidgetBuilder? get buildWidgetOrNull => buildWidget;

  @override
  SelfBuiltLocationPageBuilder? get buildPageOrNull => buildPage;
}

final class NonRenderingLocationBuildResult extends LocationBuildResult {
  const NonRenderingLocationBuildResult();

  @override
  LocationWidgetBuilder? get buildWidgetOrNull => null;

  @override
  SelfBuiltLocationPageBuilder? get buildPageOrNull => null;
}

class LocationBuilder extends PathRouteNodeBuilder {
  Content? _content;
  SelfBuiltLocationPageBuilder? _buildPage;
  StackTrace? _buildPageConfiguredStackTrace;

  LocationBuilder();

  set content(Content content) {
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
    _buildPageConfiguredStackTrace = StackTrace.current;
  }

  LocationBuildResult? resolveRender({String? debugContext}) {
    if (_content == null) {
      if (_buildPage != null) {
        _throwPageConfigurationError(
          'LocationBuilder page was configured without content. '
          'Configure content before setting page.',
          debugContext: debugContext,
        );
      }
      return null;
    }

    return switch (_content!) {
      final _StaticContent staticContent => SelfBuiltLocationBuildResult(
        buildWidget: (_, _) => staticContent.widget,
        buildPage: _buildPage,
      ),
      final _BuilderContent builderContent => SelfBuiltLocationBuildResult(
        buildWidget: builderContent.builder,
        buildPage: _buildPage,
      ),
      _NoContent() => const NonRenderingLocationBuildResult(),
    };
  }

  Never _throwPageConfigurationError(
    String message, {
    required String? debugContext,
  }) {
    final contextMessage = debugContext == null
        ? ''
        : '\n\nRoute configuration:\n$debugContext';
    final fullMessage =
        '$message'
        '$contextMessage'
        '\n\nThe stack trace points to the `builder.page = ...` assignment '
        'that made this configuration invalid. Use rendering content with '
        '`builder.content = Content.widget(...)` or '
        '`builder.content = Content.builder(...)`, explicitly use '
        '`builder.content = const Content.none()`, or remove `builder.page`.';

    final stackTrace = _buildPageConfiguredStackTrace;
    if (stackTrace == null) {
      throw StateError(fullMessage);
    }
    Error.throwWithStackTrace(StateError(fullMessage), stackTrace);
  }
}

class BuiltLocationDefinition {
  final List<PathSegment> path;
  final List<PathParam<dynamic>> pathParameters;
  final List<QueryParam<dynamic>> queryParameters;
  final List<QueryFilter<dynamic>> queryFilters;
  final List<RouteNode> children;
  final PageKey? pageKey;
  final RoutePathVisibility pathVisibility;
  final PathRouteNodeRenderResult? render;

  const BuiltLocationDefinition({
    required this.path,
    required this.pathParameters,
    required this.queryParameters,
    required this.queryFilters,
    required this.children,
    required this.pageKey,
    required this.pathVisibility,
    required this.render,
  });
}

/// Erased router-facing base type for all locations.
///
/// [`Location`] is the main typed callback-based convenience type, while
/// [`AbstractLocation`] is the override-based base for custom subclasses:
///
/// ```dart
/// class ALocation extends AbstractLocation<ALocation> { ... }
/// ```
///
/// Router internals, matched location lists, and generic predicates still need
/// a single common type that means "any location in the tree" without exposing
/// that self-type parameter everywhere. This base provides that erased view,
/// while the public location types remain the authoring APIs.
abstract class AnyLocation<Self extends AnyLocation<Self>>
    extends PathRouteNode<Self> {
  final ISet<LocationTag> tags;

  AnyLocation({
    super.id,
    super.localId,
    super.parentRouterKey,
    Iterable<LocationTag> tags = const [],
  }) : tags = tags.toISet();

  bool get contributesPage => switch (definition.render) {
    final LocationBuildResult render => render.buildWidgetOrNull != null,
    null => true,
    _ => false,
  };

  bool get buildsOwnPage => switch (definition.render) {
    final LocationBuildResult render => render.buildWidgetOrNull != null,
    _ => false,
  };

  Widget? buildWidget(BuildContext context, WorkingRouterData data) {
    final render = definition.render;
    final buildWidget = switch (render) {
      final LocationBuildResult locationRender =>
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
      final LocationBuildResult locationRender =>
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

  IList<RouteNode> matchRelative(
    bool Function(AnyLocation location) predicate,
  ) {
    for (final child in children) {
      final childMatch = matchRelativeNode(child, predicate);
      if (childMatch.isNotEmpty) {
        return childMatch;
      }
    }

    return emptyNodeMatch();
  }

  AnyLocation? pop() {
    return null;
  }

  /// The default equality ensures that a location
  /// can be used as a [Page] key.
  /// Therefore children and tags are not relevant,
  /// because they may change during runtime, and should not
  /// cause a page rebuild.
  /// Two locations are considered equal if they have the same type
  /// and the same ids (including both having null ids).
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AnyLocation &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            localId == other.localId;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, localId);
}

abstract class AbstractLocation<Self extends AnyLocation<Self>>
    extends AnyLocation<Self>
    implements BuildsWithLocationBuilder {
  /// Override-based base class for reusable location subclasses.
  ///
  /// Use this when a location is implemented by subclassing and overriding
  /// [build] directly.
  AbstractLocation({
    super.id,
    super.localId,
    super.parentRouterKey,
    super.tags,
  });

  /// Mirrors the `node` callback parameter used by callback-based locations.
  ///
  /// This makes override-based locations easier to keep in sync with inline
  /// callback-based locations when moving builder code between the two forms.
  Self get node => this as Self;

  @override
  LocationBuilder createBuilder() => LocationBuilder();
}

class Location<Self extends AnyLocation<Self>> extends AbstractLocation<Self> {
  final BuildLocation<Self> _build;

  /// Main typed callback-based location API.
  ///
  /// Use this for lightweight named route-node subclasses that simply forward a
  /// `build:` callback.
  Location({
    super.id,
    super.localId,
    super.parentRouterKey,
    super.tags,
    required BuildLocation<Self> build,
  }) : _build = build;

  @override
  void build(LocationBuilder builder) {
    _build(builder, this as Self);
  }
}

/// Callback-based convenience location for anonymous inline route nodes.
///
/// This intentionally does not expose a self generic parameter. Use
/// [Location] for the main typed callback-based API.
class AnonymousLocation extends AbstractLocation<AnonymousLocation> {
  final BuildAnonymousLocation _build;

  AnonymousLocation({
    super.id,
    super.localId,
    super.parentRouterKey,
    super.tags,
    required BuildAnonymousLocation build,
  }) : _build = build;

  @override
  void build(LocationBuilder builder) {
    _build(builder, this);
  }
}

List<Page<dynamic>> buildDefaultPagesForSlot({
  required WorkingRouterData data,
  required WorkingRouterKey routerKey,
  required LocationWidgetBuilder? buildDefaultWidget,
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
