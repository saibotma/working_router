import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/route_param_codec.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';

sealed class PathSegment {
  const PathSegment();

  const factory PathSegment.literal(String value) = LiteralPathSegment;
}

LiteralPathSegment literal(String value) => LiteralPathSegment(value);

PathParam<T> pathParam<T>(RouteParamCodec<T> codec) => PathParam<T>(codec);

QueryParam<T> queryParam<T>(
  RouteParamCodec<T> codec, {
  bool optional = false,
}) => QueryParam<T>(codec, optional: optional);

typedef WritePathParameters<ID> =
    void Function(
      Location<ID> location,
      void Function<T>(PathParam<T> parameter, T value) path,
    );

class LiteralPathSegment extends PathSegment {
  final String value;

  const LiteralPathSegment(this.value);
}

class PathParam<T> extends PathSegment {
  final RouteParamCodec<T> codec;

  const PathParam(this.codec);
}

class QueryParam<T> {
  final RouteParamCodec<T> codec;
  final bool optional;

  const QueryParam(this.codec, {this.optional = false});
}

abstract class RouteNode<ID> {
  final IList<RouteNode<ID>> children;
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  RouteNode({
    Iterable<RouteNode<ID>> children = const [],
    this.parentNavigatorKey,
  }) : children = children.toIList();

  /// Builds the default [Page] key for this node.
  ///
  /// The key is based on the route template up to this node rather than the
  /// hydrated parameter values, so `/lesson/1` and `/lesson/2` reuse the same
  /// page and do not animate like a page replacement, while
  /// `/lesson/1/edit` still becomes a different page.
  LocalKey buildPageKey(WorkingRouterData<ID> data) {
    return ValueKey((runtimeType, data.pathTemplateUpToNode(this)));
  }

  RouteMatch<ID> match(IList<String> uriPathSegments) {
    return _matchNode(this, uriPathSegments);
  }

  IList<RouteNode<ID>> matchId(ID id) {
    return _matchNodeById(this, id);
  }
}

typedef RouteMatch<ID> =
    ({
      IList<RouteNode<ID>> nodes,
      IMap<PathParam<dynamic>, String> pathParameters,
    });

RouteMatch<ID> emptyRouteMatch<ID>() => (
  nodes: const IListConst([]),
  pathParameters: const IMapConst({}),
);

extension RouteMatchX<ID> on RouteMatch<ID> {
  bool get isEmpty => nodes.isEmpty;
}

extension RouteNodesX<ID> on Iterable<RouteNode<ID>> {
  IList<Location<ID>> get locations => whereType<Location<ID>>().toIList();
}

IList<RouteNode<ID>> emptyNodeMatch<ID>() => const IListConst([]);

RouteMatch<ID> _matchNode<ID>(
  RouteNode<ID> node,
  IList<String> uriPathSegments,
) {
  if (node is Shell<ID>) {
    for (final child in node.children) {
      final childMatch = _matchNode(child, uriPathSegments);
      if (!childMatch.isEmpty) {
        return (
          nodes: [node, ...childMatch.nodes].toIList(),
          pathParameters: childMatch.pathParameters,
        );
      }
    }
    return emptyRouteMatch();
  }

  if (node is! Location<ID>) {
    return emptyRouteMatch();
  }

  final matches = <RouteNode<ID>>[];
  final pathParameters = <PathParam<dynamic>, String>{};

  final thisPathParameters = startsWith(uriPathSegments, node.path);
  if (thisPathParameters == null) {
    return emptyRouteMatch();
  }

  matches.add(node);
  pathParameters.addAll(thisPathParameters);

  final nextPathSegments = node.path.isEmpty
      ? uriPathSegments
      : uriPathSegments.sublist(node.path.length);
  for (final child in node.children) {
    final childMatch = _matchNode(child, nextPathSegments);
    if (!childMatch.isEmpty) {
      matches.addAll(childMatch.nodes);
      pathParameters.addAll(childMatch.pathParameters.unlock);
      break;
    }
  }

  if (matches.length == 1 && nextPathSegments.isNotEmpty) {
    return emptyRouteMatch();
  }

  return (
    nodes: matches.toIList(),
    pathParameters: pathParameters.toIMap(),
  );
}

IList<RouteNode<ID>> _matchNodeById<ID>(RouteNode<ID> node, ID id) {
  if (node is Shell<ID>) {
    for (final child in node.children) {
      final childMatch = _matchNodeById(child, id);
      if (childMatch.isNotEmpty) {
        return [node, ...childMatch].toIList();
      }
    }
    return emptyNodeMatch();
  }

  if (node is! Location<ID>) {
    return emptyNodeMatch();
  }

  if (node.id == id) {
    return [node].toIList();
  }

  for (final child in node.children) {
    final childMatch = _matchNodeById(child, id);
    if (childMatch.isNotEmpty) {
      return [node, ...childMatch].toIList();
    }
  }

  return emptyNodeMatch();
}

IList<RouteNode<ID>> matchRelativeNode<ID>(
  RouteNode<ID> node,
  bool Function(Location<ID> location) predicate,
) {
  if (node is Shell<ID>) {
    for (final child in node.children) {
      final childMatch = matchRelativeNode(child, predicate);
      if (childMatch.isNotEmpty) {
        return [node, ...childMatch].toIList();
      }
    }
    return emptyNodeMatch();
  }

  if (node is! Location<ID>) {
    return emptyNodeMatch();
  }

  if (predicate(node)) {
    return [node].toIList();
  }

  for (final child in node.children) {
    final childMatch = matchRelativeNode(child, predicate);
    if (childMatch.isNotEmpty) {
      return [node, ...childMatch].toIList();
    }
  }

  return emptyNodeMatch();
}

Map<PathParam<dynamic>, String>? startsWith(
  IList<String> uriPathSegments,
  List<PathSegment> startsWithSegments,
) {
  if (uriPathSegments.length < startsWithSegments.length) {
    return null;
  }

  final pathParameters = <PathParam<dynamic>, String>{};

  for (var i = 0; i < startsWithSegments.length; i++) {
    final uriSegment = uriPathSegments[i];
    final pathSegment = startsWithSegments[i];

    switch (pathSegment) {
      case LiteralPathSegment():
        if (uriSegment != pathSegment.value) {
          return null;
        }
      case PathParam():
        pathParameters[pathSegment] = uriSegment;
    }
  }

  return pathParameters;
}

extension LocationPathBuilder<ID> on Iterable<Location<ID>> {
  String buildPath(IMap<PathParam<dynamic>, String> pathParameters) {
    final uriPathSegments = <String>[];
    for (final location in this) {
      for (final pathSegment in location.path) {
        switch (pathSegment) {
          case LiteralPathSegment():
            uriPathSegments.add(pathSegment.value);
          case PathParam():
            final rawValue = pathParameters[pathSegment];
            if (rawValue == null) {
              throw StateError(
                'Missing value for path parameter `$pathSegment` on '
                '${location.runtimeType}.',
              );
            }
            uriPathSegments.add(rawValue);
        }
      }
    }

    return '/${uriPathSegments.join('/')}';
  }

  String buildPathTemplate() {
    final uriPathSegments = <String>[];
    for (final location in this) {
      for (final pathSegment in location.path) {
        switch (pathSegment) {
          case LiteralPathSegment():
            uriPathSegments.add(pathSegment.value);
          case PathParam():
            uriPathSegments.add('*');
        }
      }
    }

    return '/${uriPathSegments.join('/')}';
  }
}
