import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/widgets/location_guard.dart';
import 'package:working_router/src/widgets/nearest_location.dart';
import 'package:working_router/src/working_router_data_provider.dart';

class WorkingRouter<ID> with ChangeNotifier {
  final Location<ID> locationTree;

  late IList<Location<ID>> currentLocations = IList();
  Uri? currentPath;
  IMap<String, String> currentPathParameters = IMap();

  WorkingRouter({required this.locationTree});

  static WorkingRouter<ID> of<ID>(BuildContext context) {
    final WorkingRouterDataProviderInherited<ID>? myRouter =
        context.dependOnInheritedWidgetOfExactType<
            WorkingRouterDataProviderInherited<ID>>();
    return myRouter!.myRouter;
  }

  Future<void> routeToUriString(String uriString) async {
    routeToUri(Uri.parse(uriString));
  }

  Future<void> routeToUri(Uri uri) async {
    final matchResult = locationTree.match(uri.pathSegments.toIList());
    final matches = matchResult.first;
    final pathParameters = matchResult.second;

    _routeTo(
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

  Future<void> _routeTo({
    required IList<Location<ID>> locations,
    required Uri? fallback,
    required IMap<String, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) async {
    if (await _guard(locations)) {
      return;
    }

    currentLocations = locations;
    // Set the path to fallback when locations are empty.
    // When locations are empty, then not found should be shown, but
    // the path in the browser URL bar should stay at the not found path value
    // entered by the user.
    currentPath = locations.isEmpty
        ? fallback!
        : _uriFromLocations(
            locations: locations,
            queryParameters: queryParameters,
            pathParameters: pathParameters,
          );
    currentPathParameters = pathParameters;
    notifyListeners();
  }

  void pop() {
    if (currentPath != null) {
      final newLocations = currentLocations.removeLast();
      final newPathParameters =
          newLocations.last.selectPathParameters(currentPathParameters);
      final newQueryParameters = newLocations.last
          .selectQueryParameters(currentPath!.queryParameters.toIMap());

      _routeTo(
          locations: newLocations,
          fallback: null,
          queryParameters: newQueryParameters,
          pathParameters: newPathParameters);

      notifyListeners();
    }
  }

  Uri _uriFromLocations({
    required IList<Location> locations,
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

  Future<bool> _guard(IList<Location> newLocations) async {
    for (final guard in guards) {
      final guardedLocation = NearestLocation.of<ID>(guard.context);
      if (currentLocations.contains(guardedLocation) &&
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