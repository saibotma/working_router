import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location_tag.dart';
import 'package:working_router/src/route_builder.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_sailor.dart';

typedef BuildLocation<ID> =
    void Function(LocationBuilder<ID> builder);

class Location<ID> extends RouteNode<ID> {
  final ID? id;
  final ISet<LocationTag> tags;
  final BuildLocation<ID>? _build;
  final bool? _buildsOwnPage;

  Location({
    this.id,
    super.parentNavigatorKey,
    Iterable<LocationTag> tags = const [],
    BuildLocation<ID>? build,
    bool? buildsOwnPage,
  }) : tags = tags.toISet(),
       _build = build,
       _buildsOwnPage = buildsOwnPage;

  @protected
  void build(LocationBuilder<ID> builder) {
    final callback = _build;
    if (callback == null) {
      throw StateError(
        'Location $runtimeType must either override build(...) or provide '
        'a build callback.',
      );
    }
    return callback(builder);
  }

  late final BuiltLocationDefinition<ID> _definition = _buildDefinition();

  BuiltLocationDefinition<ID> _buildDefinition() {
    final builder = LocationBuilder<ID>();
    build(builder);
    final render = builder.render;
    if (render == null) {
      throw StateError(
        'Location $runtimeType must configure its render with '
        'buildWidget(...), buildPage(...), or legacy().',
      );
    }
    if (_buildsOwnPage == true && render is LegacyLocationBuildResult<ID>) {
      throw StateError(
        'Location $runtimeType has buildsOwnPage == true but configured '
        'legacy() from build(...).',
      );
    }
    if (_buildsOwnPage == false && render is! LegacyLocationBuildResult<ID>) {
      throw StateError(
        'Location $runtimeType has buildsOwnPage == false but configured '
        'a self-built page from build(...).',
      );
    }
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
  List<RouteNode<ID>> get children => _definition.children;

  bool get buildsOwnPage =>
      _buildsOwnPage ??
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

  IList<RouteNode<ID>> matchRelative(
    bool Function(Location<ID> location) predicate,
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
  /// When using `@RouteNodes`, required query parameters are generated as
  /// required `routeToX(...)` arguments. Optional query parameters are
  /// generated as nullable arguments and omitted when null.
  ///
  /// Query parameter names are defined directly on each [QueryParam], so
  /// locations just expose the parameters they use here.
  List<QueryParam<dynamic>> get queryParameters => _definition.queryParameters;

  Location<ID>? pop() {
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
        other is Location && runtimeType == other.runtimeType && id == other.id;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id);
}
