import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import 'location_tag.dart';
import 'working_router_sailor.dart';

abstract class Location<ID> {
  final ID? id;
  final IList<Location<ID>> children;
  final ISet<LocationTag> tags;

  Location({
    this.id,
    Iterable<Location<ID>> children = const [],
    Iterable<LocationTag> tags = const [],
  })  : this.children = children.toIList(),
        this.tags = tags.toISet();

  String get path;

  bool get shouldBeSkippedOnRouteBack => false;

  late final Uri _uri = Uri.parse(path);

  List<String> get pathSegments => _uri.pathSegments;

  bool hasTag(LocationTag tag) => tags.contains(tag);

  (IList<Location<ID>>, IMap<String, String>) match(
      IList<String> pathSegments) {
    final List<Location<ID>> matches = [];
    final Map<String, String> pathParameters = {};

    final thisPathSegments = _uri.pathSegments.toIList();
    final thisPathParameters = startsWith(pathSegments, thisPathSegments);
    if (thisPathParameters != null) {
      matches.add(this);
      pathParameters.addAll(thisPathParameters);

      final nextPathSegments = thisPathSegments.isEmpty
          ? pathSegments
          : pathSegments.sublist(thisPathSegments.length);
      for (final child in children) {
        final childMatches = child.match(nextPathSegments);
        if (childMatches.$1.isNotEmpty) {
          matches.addAll(childMatches.$1);
          pathParameters.addAll(childMatches.$2.unlock);
          break;
        }
      }

      if (matches.length == 1 && nextPathSegments.isNotEmpty) {
        return (IList(), IMap());
      }
    }

    return (matches.toIList(), pathParameters.toIMap());
  }

  IList<Location<ID>> matchId(ID id) {
    final List<Location<ID>> matches = [];
    if (this.id == id) {
      matches.add(this);
    } else {
      for (final child in children) {
        final childMatches = child.matchId(id);
        if (childMatches.isNotEmpty) {
          matches.add(this);
          matches.addAll(childMatches);
          break;
        }
      }
    }

    return matches.toIList();
  }

  IList<Location<ID>> matchRelative(
    bool Function(Location<ID> location) matches,
  ) {
    for (final child in children) {
      final childMatches = child._matchRelative(matches);
      if (childMatches.isNotEmpty) {
        return childMatches;
      }
    }

    return IList();
  }

  IList<Location<ID>> _matchRelative(
    bool Function(Location<ID> location) matches,
  ) {
    if (matches(this)) {
      return [this].toIList();
    }

    for (final child in children) {
      final childMatches = child.matchRelative(matches);
      if (childMatches.isNotEmpty) {
        return [this, ...childMatches].toIList();
      }
    }

    return IList();
  }

  /// Selects the query parameters required by this Location
  /// from [currentQueryParameters].
  ///
  /// The result will be the query parameters of the route resulting from
  /// [Navigator.pop], [WorkingRouterSailor.routeBack]
  /// or [WorkingRouterSailor.routeBackUntil].
  IMap<String, String> selectQueryParameters(
    IMap<String, String> currentQueryParameters,
  ) {
    return IMap();
  }

  /// Selects the query parameters required by this Location
  /// from [currentPathParameters].
  ///
  /// The result will be the path parameters of the route resulting from
  /// [Navigator.pop], [WorkingRouterSailor.routeBack]
  /// or [WorkingRouterSailor.routeBackUntil].
  IMap<String, String> selectPathParameters(
    IMap<String, String> currentPathParameters,
  ) {
    return IMap();
  }

  Location<ID>? pop() {
    return null;
  }

  /// The default equality ensures that a location
  /// can be used as a [Page] key.
  /// Therefore children and tags are not relevant,
  /// because they may change during runtime, and should not
  /// cause a page rebuild.
  /// Two locations with null id are not considered equal, unless
  /// they are the same instance add an id, when they should
  /// be considered equal, because the corresponding pages should
  /// not be recreated.
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Location &&
            runtimeType == other.runtimeType &&
            id != null &&
            other.id != null &&
            id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

Map<String, String>? startsWith(
  IList<String> list,
  IList<String> startsWith,
) {
  if (list.length < startsWith.length) {
    return null;
  }

  final Map<String, String> pathParameters = {};

  for (int i = 0; i < startsWith.length; i++) {
    final listItem = list[i];
    final startsWithItem = startsWith[i];

    if (!startsWithItem.startsWith(":")) {
      if (listItem != startsWithItem) {
        return null;
      }
    } else {
      pathParameters[startsWithItem.replaceRange(0, 1, "")] = listItem;
    }
  }

  return pathParameters;
}
