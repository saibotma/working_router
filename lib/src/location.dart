import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location_tag.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_sailor.dart';

abstract class Location<ID> extends RouteNode<ID> {
  final ID? id;
  final ISet<LocationTag> tags;

  Location({
    this.id,
    super.parentNavigatorKey,
    Iterable<LocationTag> tags = const [],
  }) : tags = tags.toISet();

  List<PathSegment> get path;

  bool get buildsOwnPage => false;

  Widget? buildWidget(BuildContext context, WorkingRouterData<ID> data) {
    return null;
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return MaterialPage<dynamic>(key: key, child: child);
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
  /// When using `@RouteNodes`, required query parameters are
  /// generated as required `routeToX(...)` arguments. Optional query
  /// parameters are generated as nullable arguments and omitted when null.
  ///
  /// When a location instead declares `final foo = queryParam(...)` fields,
  /// mix in the generated `LocationNameGenerated` mixin so those field
  /// names become the runtime query parameter keys.
  Map<String, QueryParam<dynamic>> get queryParameters => const {};

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
