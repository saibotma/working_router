import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/route_param_codec.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

sealed class PathSegment {
  const PathSegment();
}

typedef WritePathParameters<ID> =
    void Function(
      AnyLocation<ID> location,
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

class Default<T> {
  final T value;

  const Default(this.value);
}

class QueryParam<T> {
  final String name;
  final RouteParamCodec<T> codec;
  final Default<T>? defaultValue;

  const QueryParam(this.name, this.codec, {this.defaultValue});
}

abstract class LocationTreeElement<ID> {
  final WorkingRouterKey? parentRouterKey;

  LocationTreeElement({
    this.parentRouterKey,
  });

  List<LocationTreeElement<ID>> get children => const [];

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

  IList<LocationTreeElement<ID>> matchId(ID id) {
    return _matchNodeById(this, id);
  }
}

typedef RouteMatch<ID> = ({
  IList<LocationTreeElement<ID>> elements,
  IMap<PathParam<dynamic>, String> pathParameters,
});

RouteMatch<ID> emptyRouteMatch<ID>() => (
  elements: const IListConst([]),
  pathParameters: const IMapConst({}),
);

extension RouteMatchX<ID> on RouteMatch<ID> {
  bool get isEmpty => elements.isEmpty;
}

extension TreeElementsX<ID> on Iterable<LocationTreeElement<ID>> {
  IList<AnyLocation<ID>> get locations =>
      whereType<AnyLocation<ID>>().toIList();

  RouteMatch<ID> match(IList<String> uriPathSegments) {
    for (final node in this) {
      final match = node.match(uriPathSegments);
      if (!match.isEmpty) {
        return match;
      }
    }
    return emptyRouteMatch();
  }

  IList<LocationTreeElement<ID>> matchId(ID id) {
    for (final node in this) {
      final match = node.matchId(id);
      if (match.isNotEmpty) {
        return match;
      }
    }
    return emptyNodeMatch();
  }
}

IList<LocationTreeElement<ID>> emptyNodeMatch<ID>() => const IListConst([]);

RouteMatch<ID> _matchNode<ID>(
  LocationTreeElement<ID> node,
  IList<String> uriPathSegments,
) {
  if (node is Shell<ID>) {
    for (final child in node.children) {
      final childMatch = _matchNode(child, uriPathSegments);
      if (!childMatch.isEmpty) {
        return (
          elements: [node, ...childMatch.elements].toIList(),
          pathParameters: childMatch.pathParameters,
        );
      }
    }
    return emptyRouteMatch();
  }

  if (node is! AnyLocation<ID>) {
    return emptyRouteMatch();
  }

  final matches = <LocationTreeElement<ID>>[];
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
      matches.addAll(childMatch.elements);
      pathParameters.addAll(childMatch.pathParameters.unlock);
      break;
    }
  }

  if (matches.length == 1 && nextPathSegments.isNotEmpty) {
    return emptyRouteMatch();
  }

  return (
    elements: matches.toIList(),
    pathParameters: pathParameters.toIMap(),
  );
}

IList<LocationTreeElement<ID>> _matchNodeById<ID>(
  LocationTreeElement<ID> node,
  ID id,
) {
  if (node is Shell<ID>) {
    for (final child in node.children) {
      final childMatch = _matchNodeById(child, id);
      if (childMatch.isNotEmpty) {
        return [node, ...childMatch].toIList();
      }
    }
    return emptyNodeMatch();
  }

  if (node is! AnyLocation<ID>) {
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

IList<LocationTreeElement<ID>> matchRelativeNode<ID>(
  LocationTreeElement<ID> node,
  bool Function(AnyLocation<ID> location) predicate,
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

  if (node is! AnyLocation<ID>) {
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

extension LocationPathBuilder<ID> on Iterable<AnyLocation<ID>> {
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
