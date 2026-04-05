import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location_tag.dart';
import 'package:working_router/src/route_param_codec.dart';
import 'package:working_router/src/working_router_sailor.dart';

sealed class PathSegment {
  const PathSegment();

  const factory PathSegment.literal(String value) = LiteralPathSegment;

  static ParamPathSegment<T> param<T>(
    String key, {
    required RouteParamCodec<T> codec,
  }) => ParamPathSegment<T>(key, codec: codec);
}

class LiteralPathSegment extends PathSegment {
  final String value;

  const LiteralPathSegment(this.value);
}

class ParamPathSegment<T> extends PathSegment {
  final String key;
  final RouteParamCodec<T> codec;

  const ParamPathSegment(
    this.key, {
    required this.codec,
  });
}

class QueryParamConfig<T> {
  final RouteParamCodec<T> codec;
  final bool optional;

  const QueryParamConfig(this.codec, {this.optional = false});
}

abstract class Location<ID> {
  final ID? id;
  final IList<Location<ID>> children;
  final ISet<LocationTag> tags;

  Location({
    this.id,
    Iterable<Location<ID>> children = const [],
    Iterable<LocationTag> tags = const [],
  }) : children = children.toIList(),
       tags = tags.toISet();

  List<PathSegment> get path;

  bool get shouldBeSkippedOnRouteBack => false;

  bool hasTag(LocationTag tag) => tags.contains(tag);

  (IList<Location<ID>>, IMap<String, String>) match(
    IList<String> uriPathSegments,
  ) {
    final List<Location<ID>> matches = [];
    final Map<String, String> pathParameters = {};

    final thisPathParameters = startsWith(uriPathSegments, path);
    if (thisPathParameters != null) {
      matches.add(this);
      pathParameters.addAll(thisPathParameters);

      final nextPathSegments = path.isEmpty
          ? uriPathSegments
          : uriPathSegments.sublist(path.length);
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
    // todo: improve this by making id breadth-first instead of depth-first
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

  /// Query parameter definitions associated with this location.
  ///
  /// The final query parameters of the route resulting from [Navigator.pop],
  /// [WorkingRouterSailor.routeBack] or [WorkingRouterSailor.routeBackUntil]
  /// are filtered to the union of the keys declared by the remaining
  /// locations.
  ///
  /// When using `@WorkingRouterLocationTree`, required query parameters are
  /// generated as required `routeToX(...)` arguments. Optional query
  /// parameters are generated as nullable arguments and omitted when null.
  Map<String, QueryParamConfig<dynamic>> get queryParameters => const {};

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

Map<String, String>? startsWith(
  IList<String> uriPathSegments,
  List<PathSegment> startsWithSegments,
) {
  if (uriPathSegments.length < startsWithSegments.length) {
    return null;
  }

  final Map<String, String> pathParameters = {};

  for (int i = 0; i < startsWithSegments.length; i++) {
    final uriSegment = uriPathSegments[i];
    final pathSegment = startsWithSegments[i];

    switch (pathSegment) {
      case LiteralPathSegment():
        if (uriSegment != pathSegment.value) {
          return null;
        }
      case ParamPathSegment():
        final parameterSegment = pathSegment;
        pathParameters[parameterSegment.key] = uriSegment;
    }
  }

  return pathParameters;
}

extension LocationPathBuilder<ID> on Iterable<Location<ID>> {
  String buildPath(IMap<String, String> pathParameters) {
    final uriPathSegments = expand((location) => location.path)
        .map((
          pathSegment,
        ) {
          return switch (pathSegment) {
            LiteralPathSegment() => pathSegment.value,
            ParamPathSegment() => pathParameters[pathSegment.key]!,
          };
        })
        .join('/');

    return '/$uriPathSegments';
  }
}
