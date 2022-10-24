import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'location.dart';
import 'widgets/location_guard.dart';
import 'widgets/nearest_location.dart';
import 'working_router_data.dart';
import 'working_router_data_provider.dart';

class WorkingRouter<ID> with ChangeNotifier {
  final Location<ID> locationTree;
  WorkingRouterData<ID>? _data;

  /// oldData is null when the route from the OS is set for the first
  /// time at router start up.
  Future<bool> Function(
    WorkingRouterData<ID>? oldData,
    WorkingRouterData<ID> newData,
  )? beforeRouting;

  WorkingRouter({required this.locationTree, this.beforeRouting});

  WorkingRouterData<ID>? get data => _data;

  static WorkingRouter<ID> of<ID>(BuildContext context) {
    final WorkingRouterDataProviderInherited<ID>? myRouter =
        context.dependOnInheritedWidgetOfExactType<
            WorkingRouterDataProviderInherited<ID>>();
    return myRouter!.router;
  }

  Future<void> routeToUriString(String uriString) async {
    await routeToUri(Uri.parse(uriString));
  }

  Future<void> routeToUri(Uri uri) async {
    final matchResult = locationTree.match(uri.pathSegments.toIList());
    final matches = matchResult.first;
    final pathParameters = matchResult.second;

    await _routeTo(
      locations: matches,
      fallback: uri,
      pathParameters: pathParameters,
      queryParameters: uri.queryParameters.toIMap(),
    );
  }

  void routeToId(
    ID id, {
    IMap<String, String> pathParameters = const IMapConst({}),
    IMap<String, String> queryParameters = const IMapConst({}),
  }) {
    final matches = locationTree.matchId(id);
    _routeTo(
      locations: matches,
      fallback: null,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  void routeToRelative(
    bool Function(Location<ID> location) match, {
    IMap<String, String> pathParameters = const IMapConst({}),
    IMap<String, String> queryParameters = const IMapConst({}),
  }) {
    final relativeMatches = data!.locations.last.matchRelative(match);
    if (relativeMatches.isEmpty) {
      return;
    }

    _routeTo(
      locations: data!.locations.addAll(relativeMatches),
      fallback: null,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  Future<void> _routeTo({
    required IList<Location<ID>> locations,
    required Uri? fallback,
    required IMap<String, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) async {
    assert(
      locations.isNotEmpty || (fallback != null),
      "Fallback must not be null when locations are empty.",
    );

    final newData = WorkingRouterData(
      // Set the uri to fallback when locations are empty.
      // When locations are empty, then not found should be shown, but
      // the path in the browser URL bar should stay at the not found path value
      // entered by the user.
      uri: locations.isEmpty
          ? fallback!
          : _uriFromLocations(
              locations: locations,
              queryParameters: queryParameters,
              pathParameters: pathParameters,
            ),
      locations: locations,
      pathParameters: locations.isEmpty ? const IMapConst({}) : pathParameters,
      queryParameters: locations.isEmpty
          ? fallback!.queryParameters.toIMap()
          : queryParameters,
    );
    if (!(await beforeRouting?.call(data, newData) ?? true)) {
      return;
    }

    if (await _guard(locations)) {
      return;
    }

    _data = newData;
    notifyListeners();
  }

  void pop() {
    final newLocations = data!.locations.removeLast();
    final newPathParameters =
        newLocations.last.selectPathParameters(data!.pathParameters);
    final newQueryParameters =
        newLocations.last.selectQueryParameters(data!.queryParameters);

    _routeTo(
        locations: newLocations,
        fallback: null,
        queryParameters: newQueryParameters,
        pathParameters: newPathParameters);

    notifyListeners();
  }

  Uri _uriFromLocations({
    required IList<Location<ID>> locations,
    required IMap<String, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    return Uri(
      pathSegments: locations
          .map((location) => location.pathSegments)
          .flattened
          .map((pathSegment) {
        if (pathSegment.startsWith(":")) {
          return pathParameters[pathSegment.replaceRange(0, 1, "")]!;
        }
        return pathSegment;
      }),
      queryParameters: queryParameters.isEmpty ? null : queryParameters.unlock,
    );
  }

  Future<bool> _guard(IList<Location<ID>> newLocations) async {
    for (final guard in guards) {
      final guardedLocation = NearestLocation.of<ID>(guard.context);
      if (data!.locations.contains(guardedLocation) &&
          !newLocations.contains(guardedLocation)) {
        if (!(await guard.widget.mayLeave())) {
          return true;
        }
      }
    }
    return false;
  }

  final List<LocationGuardState> guards = [];

  void addGuard(LocationGuardState guard) {
    guards.add(guard);
  }

  void removeGuard(LocationGuardState guard) {
    guards.remove(guard);
  }
}
