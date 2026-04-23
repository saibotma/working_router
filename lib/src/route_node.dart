import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/route_param_codec.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

abstract interface class AnyNodeId {
  const AnyNodeId();
}

abstract interface class AnyLocalNodeId {
  const AnyLocalNodeId();
}

/// Typed global route-node identity token.
///
/// This is intentionally non-const. Route ids are identity tokens, and the
/// same route-node type may legitimately appear multiple times with different
/// ids. Requiring a normal object instance avoids const canonicalization and
/// keeps distinct declarations distinct even when they use the same `T`.
final class NodeId<T extends RouteNode<T>> implements AnyNodeId {
  NodeId();
}

/// Typed subtree-local route-node identity token.
///
/// This is intentionally non-const for the same reason as [NodeId]: local ids
/// are identity tokens and must remain distinct across repeated occurrences of
/// the same route-node type.
final class LocalNodeId<T extends RouteNode<T>>
    implements AnyLocalNodeId {
  LocalNodeId();
}

sealed class PathSegment {
  const PathSegment();
}

typedef WritePathParameters =
    void Function(
      PathRouteNode location,
      void Function<T>(PathParam<T> parameter, T value) path,
    );

class LiteralPathSegment extends PathSegment {
  final String value;

  const LiteralPathSegment(this.value);
}

sealed class Param<T> {
  const Param();

  RouteParamCodec<T> get codec;
}

/// Reusable parameter definition that is not yet declared on a route node.
///
/// Bind an unbound parameter with `builder.bindParam(...)` before using the
/// resulting [Param] with `data.param(...)`.
sealed class UnboundParam<T> {
  const UnboundParam();

  RouteParamCodec<T> get codec;
}

final class UnboundPathParam<T> extends UnboundParam<T> {
  @override
  final RouteParamCodec<T> codec;

  const UnboundPathParam(this.codec);
}

/// A non-nullable path parameter segment.
///
/// Path parameters are always matched from an existing URI segment, so this
/// package intentionally models them as non-nullable values. If a segment is
/// missing, the route does not match instead of producing `null`.
class PathParam<T> extends PathSegment implements Param<T> {
  final UnboundPathParam<T> unboundParam;
  @override
  RouteParamCodec<T> get codec => unboundParam.codec;

  @internal
  PathParam(this.unboundParam);
}

class Default<T> {
  final T value;

  const Default(this.value);
}

final class UnboundQueryParam<T> extends UnboundParam<T> {
  final String name;
  @override
  final RouteParamCodec<T> codec;
  final Default<T>? defaultValue;

  const UnboundQueryParam(this.name, this.codec, {this.defaultValue});
}

class QueryParam<T> implements Param<T> {
  final UnboundQueryParam<T> unboundParam;
  @override
  RouteParamCodec<T> get codec => unboundParam.codec;
  String get name => unboundParam.name;
  Default<T>? get defaultValue => unboundParam.defaultValue;

  @internal
  QueryParam(this.unboundParam);
}

typedef CustomPageKeyBuilder =
    LocalKey Function(WorkingRouterData data);

/// Describes how a [RouteNode] builds its [Page] key.
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
sealed class PageKey {
  const PageKey();

  /// Keys the page by `runtimeType` plus `data.pathTemplateUpToNode(node)`.
  ///
  /// This is the default and is usually what routes should use when page
  /// identity should follow the route shape rather than the hydrated path
  /// parameter values. Use it when `/item/1` -> `/item/2` should keep the same
  /// page alive and just rebuild its contents.
  const factory PageKey.templatePath() = _TemplatePathPageKey;

  /// Keys the page by `runtimeType` plus `data.pathUpToNode(node)`.
  ///
  /// Use this when page identity should change together with hydrated path
  /// parameter values, such as when `/item/1` and `/item/2` should become
  /// distinct pages instead of reusing the same page. This is useful when the
  /// route parameter should reset page-level state or animate like a new page.
  const factory PageKey.path() = _PathPageKey;

  /// Builds the page key from custom router data.
  const factory PageKey.custom(CustomPageKeyBuilder build) =
      _CustomPageKey;

  LocalKey build(RouteNode node, WorkingRouterData data);
}

final class _TemplatePathPageKey extends PageKey {
  const _TemplatePathPageKey();

  @override
  LocalKey build(RouteNode node, WorkingRouterData data) {
    return ValueKey((node.runtimeType, data.pathTemplateUpToNode(node)));
  }
}

final class _PathPageKey extends PageKey {
  const _PathPageKey();

  @override
  LocalKey build(RouteNode node, WorkingRouterData data) {
    return ValueKey((node.runtimeType, data.pathUpToNode(node)));
  }
}

final class _CustomPageKey extends PageKey {
  final CustomPageKeyBuilder _build;

  const _CustomPageKey(this._build);

  @override
  LocalKey build(RouteNode node, WorkingRouterData data) {
    return _build(data);
  }
}

abstract class RouteNode<Self extends RouteNode<Self>> {
  final NodeId<Self>? id;
  /// Optional subtree-local identity used only for start-anchored child routing.
  ///
  /// Unlike [id], a [localId] only needs to be meaningful within the current
  /// start subtree. Generated `childXTarget(...)` helpers prefer this over the
  /// route type name when it is available.
  final LocalNodeId<Self>? localId;
  final WorkingRouterKey? parentRouterKey;

  RouteNode({
    this.id,
    this.localId,
    this.parentRouterKey,
  });

  List<RouteNode> get children => const [];

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
  LocalKey buildPageKey(WorkingRouterData data) {
    return const PageKey.templatePath().build(this, data);
  }

  RouteMatch match(IList<String> uriPathSegments) {
    return _matchNode(this, uriPathSegments);
  }

  IList<RouteNode> matchId(AnyNodeId id) {
    return _matchNodeById(this, id);
  }
}

typedef RouteMatch = ({
  IList<RouteNode> routeNodes,
  IMap<UnboundPathParam<dynamic>, String> pathParameters,
});

RouteMatch emptyRouteMatch() => (
  routeNodes: const IListConst([]),
  pathParameters: const IMapConst({}),
);

extension RouteMatchX on RouteMatch {
  bool get isEmpty => routeNodes.isEmpty;
}

extension TreeElementsX on Iterable<RouteNode> {
  IList<AnyLocation> get locations =>
      whereType<AnyLocation>().toIList();

  IList<PathRouteNode> get pathRouteNodes =>
      whereType<PathRouteNode>().toIList();

  RouteMatch match(IList<String> uriPathSegments) {
    for (final node in this) {
      final match = node.match(uriPathSegments);
      if (!match.isEmpty) {
        return match;
      }
    }
    return emptyRouteMatch();
  }

  IList<RouteNode> matchId(AnyNodeId id) {
    for (final node in this) {
      final match = node.matchId(id);
      if (match.isNotEmpty) {
        return match;
      }
    }
    return emptyNodeMatch();
  }
}

IList<RouteNode> emptyNodeMatch() => const IListConst([]);

RouteMatch _matchNode(
  RouteNode node,
  IList<String> uriPathSegments,
) {
  if (node is! PathRouteNode) {
    return emptyRouteMatch();
  }

  final matches = <RouteNode>[];
  final Map<UnboundPathParam<dynamic>, String> pathParameters =
      <UnboundPathParam<dynamic>, String>{};

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
      matches.addAll(childMatch.routeNodes);
      _mergePathParameters(pathParameters, childMatch.pathParameters.unlock);
      break;
    }
  }

  if (matches.length == 1 &&
      (nextPathSegments.isNotEmpty || node is! AnyLocation)) {
    return emptyRouteMatch();
  }

  return (
    routeNodes: matches.toIList(),
    pathParameters: pathParameters.toIMap(),
  );
}

IList<RouteNode> _matchNodeById(
  RouteNode node,
  AnyNodeId id,
) {
  if (node is! PathRouteNode) {
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

IList<RouteNode> matchRelativeNode(
  RouteNode node,
  bool Function(AnyLocation location) predicate,
) {
  if (node is! PathRouteNode) {
    return emptyNodeMatch();
  }

  if (node case final AnyLocation location when predicate(location)) {
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
  Map<UnboundPathParam<dynamic>, String> target,
  Map<UnboundPathParam<dynamic>, String> source,
) {
  // UnboundPathParam is generic, so runtime map key types can become
  // `UnboundPathParam<String>`, `UnboundPathParam<MyExtensionType>`, and so on.
  // `Map.addAll` checks the whole source map type at runtime and can throw
  // even though each entry is individually valid here.
  for (final entry in source.entries) {
    if (target.containsKey(entry.key)) {
      throw StateError(
        'Path parameter definition `${entry.key.runtimeType}` was bound more '
        'than once in the same matched route branch.',
      );
    }
    target[entry.key] = entry.value;
  }
}

Map<UnboundPathParam<dynamic>, String>? startsWith(
  IList<String> uriPathSegments,
  List<PathSegment> startsWithSegments,
) {
  if (uriPathSegments.length < startsWithSegments.length) {
    return null;
  }

  final Map<UnboundPathParam<dynamic>, String> pathParameters =
      <UnboundPathParam<dynamic>, String>{};

  for (var i = 0; i < startsWithSegments.length; i++) {
    final uriSegment = uriPathSegments[i];
    final pathSegment = startsWithSegments[i];

    switch (pathSegment) {
      case LiteralPathSegment():
        if (uriSegment != pathSegment.value) {
          return null;
        }
      case PathParam():
        final unboundParam = pathSegment.unboundParam;
        if (pathParameters.containsKey(unboundParam)) {
          throw StateError(
            'Path parameter definition `${unboundParam.runtimeType}` was bound '
            'more than once in the same matched route branch.',
          );
        }
        pathParameters[unboundParam] = uriSegment;
    }
  }

  return pathParameters;
}

extension RouteNodePathBuilder
    on Iterable<PathRouteNode> {
  String buildPath(IMap<UnboundPathParam<dynamic>, String> pathParameters) {
    final uriPathSegments = <String>[];
    for (final location in this) {
      for (final pathSegment in location.path) {
        switch (pathSegment) {
          case LiteralPathSegment():
            uriPathSegments.add(pathSegment.value);
          case PathParam():
            final rawValue = pathParameters[pathSegment.unboundParam];
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

IList<RouteNode>? resolveExactChildRouteNodes(
  RouteNode owner,
  List<bool Function(RouteNode node)> relativeMatchers,
) {
  var children = owner.children;
  final matchedNodes = <RouteNode>[];

  for (final matcher in relativeMatchers) {
    RouteNode? matchedChild;
    for (final child in children) {
      if (matcher(child)) {
        matchedChild = child;
        break;
      }
    }
    if (matchedChild == null) {
      return null;
    }

    matchedNodes.add(matchedChild);
    children = matchedChild.children;
  }

  return matchedNodes.toIList();
}
