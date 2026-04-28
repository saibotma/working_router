import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/working_router.dart';

class WorkingRouterData {
  final Uri uri;
  final IList<RouteNode> routeNodes;

  @internal
  final IMap<RouteNode, IList<AnyOverlay>> activeOverlaysByOwner;

  // Effective path parameters for the matched route chain.
  //
  // This intentionally stays stored instead of being derived from `uri`:
  // reconstructing it requires replaying the matched path templates so each raw
  // segment can be keyed by its UnboundPathParam identity. Keeping the encoded
  // values here makes routing and typed `param(...)` access cheap while still
  // decoding only at typed access boundaries.
  final IMap<UnboundPathParam<dynamic>, String> _pathParameters;

  // Effective query parameters for the matched route state.
  //
  // This includes visible query parameters from `uri`, hidden query parameters
  // from browser state, and active overlay condition values. Keep the encoded,
  // string-keyed form because URI rebuilding and forwarding should not require
  // recovering codec metadata first.
  final IMap<String, String> queryParameters;

  WorkingRouterData({
    required this.uri,
    required this.routeNodes,
    required this.activeOverlaysByOwner,
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
  late final IList<PathRouteNode> _pathRouteNodes = routeNodes.pathRouteNodes;

  AnyLocation? get leaf => _locations.lastOrNull;

  /// Primary route nodes plus active overlays in deterministic traversal order.
  ///
  /// Public leaf/path semantics still use [routeNodes]; matched helpers scan
  /// this expanded list so active overlays can be observed after their owner.
  @internal
  late final IList<RouteNode> routeNodesWithOverlays =
      _buildRouteNodesWithOverlays();

  IList<RouteNode> _buildRouteNodesWithOverlays() {
    final result = <RouteNode>[];
    for (final node in routeNodes) {
      result.add(node);
      result.addAll(activeOverlaysByOwner[node] ?? const IListConst([]));
    }
    return result.toIList();
  }

  T? leafWithId<T extends AnyLocation<T>>(NodeId<T> id) {
    final leaf = this.leaf;
    if (leaf is T && leaf.id == id) {
      return leaf;
    }
    return null;
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
        'The requested QueryParam `${parameter.name}` is not part of the '
        'current matched route chain for `$uri`. Active query params: '
        '${_activeQueryParamNamesDescription()}.',
      );
    }

    final rawValue = queryParameters[parameter.name];
    final value = rawValue == null ? null : parameter.codec.decode(rawValue);
    if (value != null) {
      return value;
    }

    if (parameter case final DefaultQueryParam<T> defaultParameter) {
      return defaultParameter.defaultValue;
    }

    throw StateError(
      'The requested QueryParam `${parameter.name}` is not present in the '
      'current router data for `$uri` and it has no default value. Available '
      'query values: ${_availableQueryValueNamesDescription()}.',
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

    if (parameter case final DefaultUnboundQueryParam<T> defaultParameter) {
      return defaultParameter.defaultValue;
    }

    return null;
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

  String _activeQueryParamNamesDescription() {
    final names =
        _pathRouteNodes
            .expand((node) => node.queryParameters.map((it) => it.name))
            .toSet()
            .toList()
          ..sort();
    if (names.isEmpty) {
      return 'none';
    }
    return names.map((name) => '`$name`').join(', ');
  }

  String _availableQueryValueNamesDescription() {
    final names = queryParameters.keys.toList()..sort();
    if (names.isEmpty) {
      return 'none';
    }
    return names.map((name) => '`$name`').join(', ');
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
    return routeNodesWithOverlays.any((node) => node.id == id);
  }

  bool isAnyIdMatched(Iterable<AnyNodeId> ids) {
    return routeNodesWithOverlays.any((node) => ids.contains(node.id));
  }

  AnyNodeId? matchingId(Iterable<AnyNodeId> ids) {
    for (final node in routeNodesWithOverlays) {
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
    return routeNodesWithOverlays.any((node) => node is T1 || node is T2);
  }

  bool isAnyTypeMatched3<
    T1 extends RouteNode<T1>,
    T2 extends RouteNode<T2>,
    T3 extends RouteNode<T3>
  >() {
    return routeNodesWithOverlays.any((node) {
      return node is T1 || node is T2 || node is T3;
    });
  }

  /// Returns whether any matched route node of type [T] exists.
  ///
  /// Structural nodes such as scopes and shells participate here as well.
  /// Query overlays participate here when their conditions match, even though
  /// overlays are not part of [routeNodes] and can never be [leaf].
  bool isMatched<T extends RouteNode<T>>([bool Function(T node)? match]) {
    final typedNodes = routeNodesWithOverlays.whereType<T>();
    if (match == null) {
      return typedNodes.isNotEmpty;
    }
    return typedNodes.any(match);
  }

  T? lastMatched<T extends RouteNode<T>>([bool Function(T node)? match]) {
    for (var i = routeNodesWithOverlays.length - 1; i >= 0; i--) {
      final node = routeNodesWithOverlays[i];
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
    IMap<RouteNode, IList<AnyOverlay>>? activeOverlaysByOwner,
    IMap<UnboundPathParam<dynamic>, String>? pathParameters,
    IMap<String, String>? queryParameters,
  }) {
    return WorkingRouterData(
      uri: uri ?? this.uri,
      routeNodes: routeNodes ?? this.routeNodes,
      activeOverlaysByOwner:
          activeOverlaysByOwner ?? this.activeOverlaysByOwner,
      pathParameters: pathParameters ?? _pathParameters,
      queryParameters: queryParameters ?? this.queryParameters,
    );
  }

  @internal
  IMap<UnboundPathParam<dynamic>, String> get pathParameters => _pathParameters;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkingRouterData &&
            runtimeType == other.runtimeType &&
            uri == other.uri &&
            routeNodes == other.routeNodes &&
            activeOverlaysByOwner == other.activeOverlaysByOwner &&
            _pathParameters == other._pathParameters &&
            queryParameters == other.queryParameters;
  }

  @override
  int get hashCode {
    return uri.hashCode ^
        routeNodes.hashCode ^
        activeOverlaysByOwner.hashCode ^
        _pathParameters.hashCode ^
        queryParameters.hashCode;
  }

  @override
  String toString() {
    return 'WorkingRouterData{uri: $uri, routeNodes: $routeNodes, activeOverlaysByOwner: $activeOverlaysByOwner, pathParameters: $_pathParameters, queryParameters: $queryParameters}';
  }
}
