import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/working_router.dart';

class WorkingRouterData {
  final Uri uri;
  final IList<RouteNode> routeNodes;

  // Keep matched path params in their encoded URI form keyed by reusable
  // unbound path definitions. The router core is still URI-first, so URI
  // rebuilding, retention, and forwarding should work on raw URI values while
  // decoding stays at typed access boundaries like param(...).
  final IMap<UnboundPathParam<dynamic>, String> _pathParameters;

  // Keep query params encoded and string-keyed for the same reason: the URI is
  // string-keyed, and rebuilding or forwarding it should not require recovering
  // codec metadata first.
  final IMap<String, String> queryParameters;

  WorkingRouterData({
    required this.uri,
    required this.routeNodes,
    required IMap<UnboundPathParam<dynamic>, String> pathParameters,
    required this.queryParameters,
  }) : _pathParameters = pathParameters;

  static WorkingRouterData of(BuildContext context) {
    final data = InheritedModel.inheritFrom<InheritedWorkingRouterData>(
      context,
    );
    return data!.data;
  }

  static Slice ofSliced<Slice>(
    BuildContext context,
    Slice Function(WorkingRouterData) slice,
  ) {
    final data = InheritedModel.inheritFrom<InheritedWorkingRouterData>(
      context,
      aspect: (dynamic data) => slice(data as WorkingRouterData),
    );
    return slice(data!.data);
  }

  late final IList<AnyLocation> _locations = routeNodes.locations;
  late final IList<PathRouteNode> _pathRouteNodes =
      routeNodes.pathRouteNodes;

  AnyLocation? get leaf => _locations.lastOrNull;

  T? leafWithId<T extends AnyLocation<T>>(NodeId<T> id) {
    final currentLeaf = leaf;
    if (currentLeaf is! T || currentLeaf.id != id) {
      return null;
    }
    return currentLeaf;
  }

  T param<T>(Param<T> parameter) {
    return switch (parameter) {
      final PathParam<T> pathParam => _pathParam(pathParam),
      final QueryParam<T> queryParam => _queryParam(queryParam),
    };
  }

  /// Returns the value for a reusable unbound parameter when it is active in
  /// the current matched route chain.
  ///
  /// This is intended for outer code that only has access to a global/shared
  /// parameter definition and needs nullable access, such as wrappers or shell
  /// widgets above the location that declares the parameter.
  T? paramOrNull<T>(UnboundParam<T> parameter) {
    if (parameter is UnboundPathParam<T>) {
      return _pathParamOrNull(parameter);
    }
    if (parameter is UnboundQueryParam<T>) {
      return _queryParamOrNull(parameter);
    }
    throw StateError(
      'Unsupported unbound parameter type ${parameter.runtimeType}.',
    );
  }

  T _pathParam<T>(PathParam<T> parameter) {
    final rawValue = _pathParameters[parameter.unboundParam];
    if (rawValue == null) {
      throw StateError(
        'The requested PathParam is not part of the current matched route chain.',
      );
    }
    return parameter.codec.decode(rawValue);
  }

  T? _pathParamOrNull<T>(UnboundPathParam<T> parameter) {
    final rawValue = _pathParameters[parameter];
    if (rawValue == null) {
      return null;
    }
    return parameter.codec.decode(rawValue);
  }

  T _queryParam<T>(QueryParam<T> parameter) {
    if (!_hasDeclaredQueryParam(parameter.unboundParam)) {
      throw StateError(
        'The requested QueryParam is not part of the current matched route chain.',
      );
    }

    final rawValue = queryParameters[parameter.name];
    final value = rawValue == null ? null : parameter.codec.decode(rawValue);
    if (value != null) {
      return value;
    }

    final defaultValue = parameter.defaultValue;
    if (defaultValue != null) {
      return defaultValue.value;
    }

    throw StateError(
      'The requested QueryParam is not present in the current router data.',
    );
  }

  T? _queryParamOrNull<T>(UnboundQueryParam<T> parameter) {
    if (!_hasDeclaredQueryParam(parameter)) {
      return null;
    }

    final rawValue = queryParameters[parameter.name];
    final value = rawValue == null ? null : parameter.codec.decode(rawValue);
    if (value != null) {
      return value;
    }

    return parameter.defaultValue?.value;
  }

  bool _hasDeclaredQueryParam<T>(UnboundQueryParam<T> parameter) {
    for (final location in _pathRouteNodes) {
      for (final declaredParameter in location.queryParameters) {
        if (!identical(declaredParameter.unboundParam, parameter)) {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  String pathUpToLocation(AnyLocation location) {
    final locationIndex = _indexOfIdenticalNode(location);
    if (locationIndex == -1) {
      return uri.path;
    }
    final pathRouteNodesUpToLocation = routeNodes
        .take(locationIndex + 1)
        .pathRouteNodes;
    return pathRouteNodesUpToLocation.buildPath(_pathParameters);
  }

  String pathUpToNode(RouteNode node) {
    final nodeIndex = _indexOfIdenticalNode(node);
    if (nodeIndex == -1) {
      return uri.path;
    }

    final pathRouteNodesUpToNode = routeNodes
        .take(nodeIndex + 1)
        .pathRouteNodes;
    return pathRouteNodesUpToNode.buildPath(_pathParameters);
  }

  String pathTemplateUpToNode(RouteNode node) {
    final nodeIndex = _indexOfIdenticalNode(node);
    if (nodeIndex == -1) {
      return uri.path;
    }

    final pathRouteNodesUpToNode = routeNodes
        .take(nodeIndex + 1)
        .pathRouteNodes;
    return pathRouteNodesUpToNode.buildPathTemplate();
  }

  int _indexOfIdenticalNode(RouteNode node) {
    for (var i = 0; i < routeNodes.length; i++) {
      if (identical(routeNodes[i], node)) {
        return i;
      }
    }
    return -1;
  }

  bool isChildOf(
    bool Function(RouteNode node) parent,
    AnyLocation child,
  ) {
    var sawParent = false;

    for (final node in routeNodes) {
      if (parent(node)) {
        sawParent = true;
      } else if (identical(node, child)) {
        return sawParent;
      }
    }

    return false;
  }

  bool isIdMatched(AnyNodeId id) {
    return routeNodes.any((node) => node.id == id);
  }

  bool isAnyIdMatched(Iterable<AnyNodeId> ids) {
    return routeNodes.any((node) => ids.contains(node.id));
  }

  AnyNodeId? matchingId(Iterable<AnyNodeId> ids) {
    for (final node in routeNodes) {
      if (ids.contains(node.id)) {
        return node.id! as AnyNodeId;
      }
    }
    return null;
  }

  bool isTypeMatched<T extends RouteNode<T>>() {
    return isMatched<T>();
  }

  bool isAnyTypeMatched2<T1 extends RouteNode<T1>, T2 extends RouteNode<T2>>() {
    return routeNodes.any((node) => node is T1 || node is T2);
  }

  bool isAnyTypeMatched3<
    T1 extends RouteNode<T1>,
    T2 extends RouteNode<T2>,
    T3 extends RouteNode<T3>
  >() {
    return routeNodes.any((node) {
      return node is T1 || node is T2 || node is T3;
    });
  }

  /// Returns whether any matched route node of type [T] exists.
  ///
  /// Structural nodes such as scopes and shells participate here as well.
  /// Use [leaf] for terminal semantic activity checks.
  bool isMatched<T extends RouteNode<T>>([bool Function(T node)? match]) {
    final typedNodes = routeNodes.whereType<T>();
    if (match == null) {
      return typedNodes.isNotEmpty;
    }
    return typedNodes.any(match);
  }

  T? lastMatched<T extends RouteNode<T>>([bool Function(T node)? match]) {
    for (var i = routeNodes.length - 1; i >= 0; i--) {
      final node = routeNodes[i];
      if (node is! T) {
        continue;
      }
      if (match == null || match(node)) {
        return node;
      }
    }
    return null;
  }

  T? lastMatchedWithId<T extends RouteNode<T>>(
    NodeId<T> id, [
    bool Function(T node)? match,
  ]) {
    return lastMatched<T>((node) {
      if (node.id != id) {
        return false;
      }
      return match == null || match(node);
    });
  }

  WorkingRouterData copyWith({
    Uri? uri,
    IList<RouteNode>? routeNodes,
    IMap<UnboundPathParam<dynamic>, String>? pathParameters,
    IMap<String, String>? queryParameters,
  }) {
    return WorkingRouterData(
      uri: uri ?? this.uri,
      routeNodes: routeNodes ?? this.routeNodes,
      pathParameters: pathParameters ?? _pathParameters,
      queryParameters: queryParameters ?? this.queryParameters,
    );
  }

  @internal
  IMap<UnboundPathParam<dynamic>, String> get pathParametersForRouter =>
      _pathParameters;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkingRouterData &&
            runtimeType == other.runtimeType &&
            uri == other.uri &&
            routeNodes == other.routeNodes &&
            _pathParameters == other._pathParameters &&
            queryParameters == other.queryParameters;
  }

  @override
  int get hashCode {
    return uri.hashCode ^
        routeNodes.hashCode ^
        _pathParameters.hashCode ^
        queryParameters.hashCode;
  }

  @override
  String toString() {
    return 'WorkingRouterData{uri: $uri, routeNodes: $routeNodes, pathParameters: $_pathParameters, queryParameters: $queryParameters}';
  }
}
