import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../working_router.dart';
import 'inherited_working_router_data.dart';

class WorkingRouterData<ID> {
  final Uri uri;

  // TODO(saibotma): This is different from e.g. VRouter where a name is only added, when it's page is also displayed. Here a location gets added, when the path matches, but the page must not be displayed. This could be changed, by respecting whether buildPages from router delegate returns an empty list or not for a location.
  final IList<Location<ID>> locations;
  final IMap<String, String> pathParameters;
  final IMap<String, String> queryParameters;

  WorkingRouterData({
    required this.uri,
    required this.locations,
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
      BuildContext context, Slice Function(WorkingRouterData<ID>) slice) {
    final data = InheritedModel.inheritFrom<InheritedWorkingRouterData<ID>>(
        context,
        aspect: (dynamic data) => slice(data as WorkingRouterData<ID>));
    return slice(data!.data);
  }

  Location<ID> get activeLocation => locations.last;

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

  bool isMatched(bool Function(Location<ID> location) match) {
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

  bool isActive(bool Function(Location<ID> location) match) {
    final last = locations.lastOrNull;
    if (last == null) {
      return false;
    }
    return match(last);
  }

  WorkingRouterData<ID> copyWith({
    Uri? uri,
    IList<Location<ID>>? locations,
    IMap<String, String>? pathParameters,
    IMap<String, String>? queryParameters,
  }) {
    return WorkingRouterData(
      uri: uri ?? this.uri,
      locations: locations ?? this.locations,
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
            locations == other.locations &&
            pathParameters == other.pathParameters &&
            queryParameters == other.queryParameters;
  }

  @override
  int get hashCode {
    return uri.hashCode ^
        locations.hashCode ^
        pathParameters.hashCode ^
        queryParameters.hashCode;
  }

  @override
  String toString() {
    return 'WorkingRouterData{uri: $uri, locations: $locations, pathParameters: $pathParameters, queryParameters: $queryParameters}';
  }
}
