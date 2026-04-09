import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location_tag.dart';
import 'package:working_router/src/location_tree_element.dart';
import 'package:working_router/src/route_builder.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_sailor.dart';

typedef BuildLocation<ID, Self extends AnyLocation<ID>> =
    void Function(LocationBuilder<ID> builder, Self location);

/// Erased router-facing base type for all locations.
///
/// [`Location`] uses a self type so a forwarded `build:` callback can receive
/// the concrete subclass instance:
///
/// ```dart
/// class ALocation extends Location<RouteId, ALocation> { ... }
/// ```
///
/// Router internals, matched location lists, and generic predicates still need
/// a single common type that means "any location in the tree" without exposing
/// that self-type parameter everywhere. This base provides that erased view,
/// while [`Location`] remains the authoring API that route subclasses extend.
abstract class AnyLocation<ID> extends LocationTreeElement<ID> {
  final ID? id;
  final ISet<LocationTag> tags;

  AnyLocation({
    this.id,
    super.parentRouterKey,
    Iterable<LocationTag> tags = const [],
  }) : tags = tags.toISet();

  @protected
  void build(LocationBuilder<ID> builder);

  late final BuiltLocationDefinition<ID> _definition = _buildDefinition();

  BuiltLocationDefinition<ID> _buildDefinition() {
    final builder = LocationBuilder<ID>();
    build(builder);
    final render = builder.resolveRender();
    return BuiltLocationDefinition(
      path: List.unmodifiable(builder.path),
      pathParameters: List.unmodifiable(builder.pathParameters),
      queryParameters: List.unmodifiable(builder.queryParameters),
      children: List.unmodifiable(builder.children),
      buildPageKey: builder.buildPageKey,
      render: render,
    );
  }

  List<PathSegment> get path => _definition.path;

  List<PathParam<dynamic>> get pathParameters => _definition.pathParameters;

  @override
  List<LocationTreeElement<ID>> get children => _definition.children;

  bool get buildsOwnPage =>
      _definition.render is SelfBuiltLocationBuildResult<ID>;

  @override
  LocalKey buildPageKey(WorkingRouterData<ID> data) {
    return _definition.buildPageKey?.call(data) ?? super.buildPageKey(data);
  }

  Widget? buildWidget(BuildContext context, WorkingRouterData<ID> data) {
    final render = _definition.render;
    if (render is! SelfBuiltLocationBuildResult<ID>) {
      return null;
    }
    return render.buildWidget(context, data);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    final render = _definition.render;
    if (render is! SelfBuiltLocationBuildResult<ID>) {
      return MaterialPage<dynamic>(key: key, child: child);
    }
    return render.buildPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }

  bool get shouldBeSkippedOnRouteBack => false;

  bool hasTag(LocationTag tag) => tags.contains(tag);

  IList<LocationTreeElement<ID>> matchRelative(
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

  /// Query parameter definitions associated with this location.
  ///
  /// The final query parameters of the route resulting from [Navigator.pop],
  /// [WorkingRouterSailor.routeBack] or [WorkingRouterSailor.routeBackUntil]
  /// are filtered to the union of the keys declared by the remaining
  /// locations.
  ///
  /// When using `@Locations`, required query parameters are generated as
  /// required `routeToX(...)` arguments. Optional query parameters are
  /// generated as nullable arguments and omitted when null.
  ///
  /// Query parameter names are defined directly on each [QueryParam], so
  /// locations just expose the parameters they use here.
  List<QueryParam<dynamic>> get queryParameters => _definition.queryParameters;

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

abstract class Location<ID, Self extends AnyLocation<ID>>
    extends AnyLocation<ID> {
  final BuildLocation<ID, Self>? _build;

  Location({
    super.id,
    super.parentRouterKey,
    super.tags,
    required BuildLocation<ID, Self> build,
  }) : _build = build;

  @protected
  Location.override({
    super.id,
    super.parentRouterKey,
    super.tags,
  }) : _build = null;

  @override
  void build(LocationBuilder<ID> builder) {
    final callback = _build;
    if (callback == null) {
      throw StateError(
        'Location $runtimeType must either override build(...) or provide '
        'a build callback.',
      );
    }
    callback(builder, this as Self);
  }
}
