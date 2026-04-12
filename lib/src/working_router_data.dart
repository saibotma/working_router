import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/working_router.dart';

class WorkingRouterData<ID> {
  final Uri uri;
  final IList<LocationTreeElement<ID>> elements;

  // Keep matched path params in their encoded URI form even though they are
  // keyed by PathParam objects. The router core is still URI-first, so URI
  // rebuilding, retention, and forwarding should work on raw URI values while
  // decoding stays at typed access boundaries like param(...).
  final IMap<PathParam<dynamic>, String> pathParameters;

  // Keep query params encoded and string-keyed for the same reason: the URI is
  // string-keyed, and rebuilding or forwarding it should not require recovering
  // codec metadata first.
  final IMap<String, String> queryParameters;

  WorkingRouterData({
    required this.uri,
    required this.elements,
    required this.pathParameters,
    required this.queryParameters,
  });

  static WorkingRouterData<ID> of<ID>(BuildContext context) {
    final data = InheritedModel.inheritFrom<InheritedWorkingRouterData<ID>>(
      context,
    );
    return data!.data;
  }

  static Slice ofSliced<ID, Slice>(
    BuildContext context,
    Slice Function(WorkingRouterData<ID>) slice,
  ) {
    final data = InheritedModel.inheritFrom<InheritedWorkingRouterData<ID>>(
      context,
      aspect: (dynamic data) => slice(data as WorkingRouterData<ID>),
    );
    return slice(data!.data);
  }

  late final IList<AnyLocation<ID>> locations = elements.locations;
  late final IList<PathLocationTreeElement<ID>> pathElements =
      elements.pathElements;

  AnyLocation<ID>? get activeLocation => locations.lastOrNull;

  T param<T>(Param<T> parameter) {
    return switch (parameter) {
      final PathParam<T> pathParam => _pathParam(pathParam),
      final QueryParam<T> queryParam => _queryParam(queryParam),
    };
  }

  T _pathParam<T>(PathParam<T> parameter) {
    final rawValue = pathParameters[parameter];
    if (rawValue == null) {
      throw StateError(
        'The requested PathParam is not part of the current matched route chain.',
      );
    }
    return parameter.codec.decode(rawValue);
  }

  T _queryParam<T>(QueryParam<T> parameter) {
    if (!_hasDeclaredQueryParam(parameter)) {
      throw StateError(
        'The requested QueryParam is not part of the current matched route chain.',
      );
    }

    final rawValue = queryParameters[parameter.name];
    final value = parameter.decodeValueOrNull(rawValue);
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

  bool _hasDeclaredQueryParam<T>(QueryParam<T> parameter) {
    for (final location in pathElements) {
      for (final declaredParameter in location.queryParameters) {
        if (!identical(declaredParameter, parameter)) {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  String pathUpToLocation(AnyLocation<ID> location) {
    final locationIndex = _indexOfIdenticalNode(location);
    if (locationIndex == -1) {
      return uri.path;
    }
    final pathElementsUpToLocation = elements
        .take(locationIndex + 1)
        .pathElements;
    return pathElementsUpToLocation.buildPath(pathParameters);
  }

  String pathUpToNode(LocationTreeElement<ID> node) {
    final nodeIndex = _indexOfIdenticalNode(node);
    if (nodeIndex == -1) {
      return uri.path;
    }

    final pathElementsUpToNode = elements.take(nodeIndex + 1).pathElements;
    return pathElementsUpToNode.buildPath(pathParameters);
  }

  String pathTemplateUpToNode(LocationTreeElement<ID> node) {
    final nodeIndex = _indexOfIdenticalNode(node);
    if (nodeIndex == -1) {
      return uri.path;
    }

    final pathElementsUpToNode = elements.take(nodeIndex + 1).pathElements;
    return pathElementsUpToNode.buildPathTemplate();
  }

  int _indexOfIdenticalNode(LocationTreeElement<ID> node) {
    for (var i = 0; i < elements.length; i++) {
      if (identical(elements[i], node)) {
        return i;
      }
    }
    return -1;
  }

  bool isChildOf(
    bool Function(AnyLocation<ID> location) parent,
    AnyLocation<ID> child,
  ) {
    var sawParent = false;

    for (final location in locations) {
      if (parent(location)) {
        sawParent = true;
      } else if (identical(location, child)) {
        return sawParent;
      }
    }

    return false;
  }

  bool isIdMatched(ID id) {
    return isMatched((location) => location.id == id);
  }

  bool isAnyIdMatched(Iterable<ID> ids) {
    return isMatched((location) => ids.contains(location.id));
  }

  ID? matchingId(Iterable<ID> ids) {
    for (final location in locations) {
      if (ids.contains(location.id)) {
        return location.id;
      }
    }
    return null;
  }

  bool isTypeMatched<T>() {
    return isMatched((location) => location is T);
  }

  bool isAnyTypeMatched2<T1, T2>() {
    return isMatched((location) => location is T1 || location is T2);
  }

  bool isAnyTypeMatched3<T1, T2, T3>() {
    return isMatched((location) {
      return location is T1 || location is T2 || location is T3;
    });
  }

  bool isMatched(bool Function(AnyLocation<ID> location) match) {
    return locations.any(match);
  }

  bool isIdActive(ID id) {
    return isActive((location) => location.id == id);
  }

  bool isAnyIdActive(Iterable<ID> ids) {
    return isActive((location) => ids.contains(location.id));
  }

  bool isTypeActive<T>() {
    return isActive((location) => location is T);
  }

  bool isAnyTypeActive2<T1, T2>() {
    return isActive((location) => location is T1 || location is T2);
  }

  bool isAnyTypeActive3<T1, T2, T3>() {
    return isActive((location) {
      return location is T1 || location is T2 || location is T3;
    });
  }

  bool isActive(bool Function(AnyLocation<ID> location) match) {
    final last = locations.lastOrNull;
    if (last == null) {
      return false;
    }
    return match(last);
  }

  WorkingRouterData<ID> copyWith({
    Uri? uri,
    IList<LocationTreeElement<ID>>? elements,
    IMap<PathParam<dynamic>, String>? pathParameters,
    IMap<String, String>? queryParameters,
  }) {
    return WorkingRouterData(
      uri: uri ?? this.uri,
      elements: elements ?? this.elements,
      pathParameters: pathParameters ?? this.pathParameters,
      queryParameters: queryParameters ?? this.queryParameters,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkingRouterData &&
            runtimeType == other.runtimeType &&
            uri == other.uri &&
            elements == other.elements &&
            pathParameters == other.pathParameters &&
            queryParameters == other.queryParameters;
  }

  @override
  int get hashCode {
    return uri.hashCode ^
        elements.hashCode ^
        pathParameters.hashCode ^
        queryParameters.hashCode;
  }

  @override
  String toString() {
    return 'WorkingRouterData{uri: $uri, elements: $elements, locations: $locations, pathParameters: $pathParameters, queryParameters: $queryParameters}';
  }
}
