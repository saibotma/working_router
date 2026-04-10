import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/path_location_tree_element.dart';
import 'package:working_router/src/route_param_codec.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

sealed class PathSegment {
  const PathSegment();
}

typedef WritePathParameters<ID> =
    void Function(
      PathLocationTreeElement<ID> location,
      void Function<T extends Object>(PathParam<T> parameter, T value) path,
    );

class LiteralPathSegment extends PathSegment {
  final String value;

  const LiteralPathSegment(this.value);
}

/// A non-nullable path parameter segment.
///
/// Path parameters are always matched from an existing URI segment, so this
/// package intentionally models them as non-nullable values. If a segment is
/// missing, the route does not match instead of producing `null`.
class PathParam<T extends Object> extends PathSegment {
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

  String? encodeValueOrNull(T value) {
    return encodeQueryParamValueOrNull(codec, value);
  }

  T? decodeValueOrNull(String? value) {
    return decodeQueryParamValueOrNull(codec, value);
  }
}

typedef CustomPageKeyBuilder<ID> =
    LocalKey Function(WorkingRouterData<ID> data);

/// Describes how a [LocationTreeElement] builds its [Page] key.
///
/// Use [PageKey.templatePath] for the default route-template-based behavior:
/// `/lesson/1` and `/lesson/2` reuse the same page, while
/// `/lesson/1/edit` becomes a different page.
/// In practice this means a detail page can swap from lesson `1` to lesson
/// `2` without replacing the page itself.
///
/// Use [PageKey.path] when hydrated path parameter values should produce
/// different pages, so `/lesson/1` and `/lesson/2` no longer reuse the same
/// page identity. In practice this means navigating from lesson `1` to
/// lesson `2` behaves like a page replacement and resets page-level state.
///
/// Use [PageKey.custom] for fully custom behavior.
sealed class PageKey<ID> {
  const PageKey();

  /// Keys the page by `runtimeType` plus `data.pathTemplateUpToNode(node)`.
  ///
  /// This is the default and is usually what routes should use when page
  /// identity should follow the route shape rather than the hydrated path
  /// parameter values. Use it when `/item/1` -> `/item/2` should keep the same
  /// page alive and just rebuild its contents.
  const factory PageKey.templatePath() = _TemplatePathPageKey<ID>;

  /// Keys the page by `runtimeType` plus `data.pathUpToNode(node)`.
  ///
  /// Use this when page identity should change together with hydrated path
  /// parameter values, such as when `/item/1` and `/item/2` should become
  /// distinct pages instead of reusing the same page. This is useful when the
  /// route parameter should reset page-level state or animate like a new page.
  const factory PageKey.path() = _PathPageKey<ID>;

  /// Builds the page key from custom router data.
  const factory PageKey.custom(CustomPageKeyBuilder<ID> build) =
      _CustomPageKey<ID>;

  LocalKey build(LocationTreeElement<ID> node, WorkingRouterData<ID> data);
}

final class _TemplatePathPageKey<ID> extends PageKey<ID> {
  const _TemplatePathPageKey();

  @override
  LocalKey build(LocationTreeElement<ID> node, WorkingRouterData<ID> data) {
    return ValueKey((node.runtimeType, data.pathTemplateUpToNode(node)));
  }
}

final class _PathPageKey<ID> extends PageKey<ID> {
  const _PathPageKey();

  @override
  LocalKey build(LocationTreeElement<ID> node, WorkingRouterData<ID> data) {
    return ValueKey((node.runtimeType, data.pathUpToNode(node)));
  }
}

final class _CustomPageKey<ID> extends PageKey<ID> {
  final CustomPageKeyBuilder<ID> _build;

  const _CustomPageKey(this._build);

  @override
  LocalKey build(LocationTreeElement<ID> node, WorkingRouterData<ID> data) {
    return _build(data);
  }
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
  ///
  /// We intentionally key by `runtimeType` plus the structural path template,
  /// not by the node itself. If the same logical location class appears
  /// multiple times in one branch, or is nested inside itself, page identity
  /// must still follow the concrete tree position rather than node equality.
  LocalKey buildPageKey(WorkingRouterData<ID> data) {
    return PageKey<ID>.templatePath().build(this, data);
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

  IList<PathLocationTreeElement<ID>> get pathElements =>
      whereType<PathLocationTreeElement<ID>>().toIList();

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
  if (node is! PathLocationTreeElement<ID>) {
    return emptyRouteMatch();
  }

  final matches = <LocationTreeElement<ID>>[];
  final Map<PathParam<dynamic>, String> pathParameters =
      <PathParam<dynamic>, String>{};

  final thisPathParameters = startsWith(uriPathSegments, node.path);
  if (thisPathParameters == null) {
    return emptyRouteMatch();
  }

  matches.add(node);
  _mergePathParameters(pathParameters, thisPathParameters);

  final nextPathSegments = node.path.isEmpty
      ? uriPathSegments
      : uriPathSegments.sublist(node.path.length);
  for (final child in node.children) {
    final childMatch = _matchNode(child, nextPathSegments);
    if (!childMatch.isEmpty) {
      matches.addAll(childMatch.elements);
      _mergePathParameters(pathParameters, childMatch.pathParameters.unlock);
      break;
    }
  }

  if (matches.length == 1 &&
      (nextPathSegments.isNotEmpty || node is! AnyLocation<ID>)) {
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
  if (node is! PathLocationTreeElement<ID>) {
    return emptyNodeMatch();
  }

  if (node case final AnyLocation<ID> location when location.id == id) {
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
  if (node is! PathLocationTreeElement<ID>) {
    return emptyNodeMatch();
  }

  if (node case final AnyLocation<ID> location when predicate(location)) {
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

void _mergePathParameters(
  Map<PathParam<dynamic>, String> target,
  Map<PathParam<dynamic>, String> source,
) {
  // PathParam is generic and non-nullable (`T extends Object`), so runtime map
  // key types can become `PathParam<String>`, `PathParam<Object>`, and so on.
  // `Map.addAll` checks the whole source map type at runtime and can throw
  // even though each entry is individually valid here.
  for (final entry in source.entries) {
    target[entry.key] = entry.value;
  }
}

Map<PathParam<dynamic>, String>? startsWith(
  IList<String> uriPathSegments,
  List<PathSegment> startsWithSegments,
) {
  if (uriPathSegments.length < startsWithSegments.length) {
    return null;
  }

  final Map<PathParam<dynamic>, String> pathParameters =
      <PathParam<dynamic>, String>{};

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

extension LocationPathBuilder<ID> on Iterable<PathLocationTreeElement<ID>> {
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
