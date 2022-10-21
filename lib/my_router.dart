import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/location_guard.dart';
import 'package:navigator_test/locations/ab_location.dart';
import 'package:navigator_test/locations/abc_location.dart';

import 'appella_router_delegate.dart';
import 'locations/a_location.dart';
import 'locations/ad_location.dart';
import 'locations/adc_location.dart';
import 'locations/location.dart';
import 'locations/splash_location.dart';

enum LocationId { splash, a, ab, abc, ad, adc }

class MyRouter with ChangeNotifier {
  late IList<Location> currentLocations = IList();
  Uri? currentPath;
  IMap<String, String> currentPathParameters = IMap();

  final Location locationTree = SplashLocation(
    id: LocationId.splash,
    children: [
      ALocation(
        id: LocationId.a,
        children: [
          ABLocation(
            id: LocationId.ab,
            children: [
              ABCLocation(id: LocationId.abc, children: []),
            ],
          ),
          ADLocation(
            id: LocationId.ad,
            children: [
              ADCLocation(id: LocationId.adc, children: []),
            ],
          ),
        ],
      ),
    ],
  );

  static MyRouter of(BuildContext context) {
    final _MyRouterDataProvider? myRouter =
        context.dependOnInheritedWidgetOfExactType<_MyRouterDataProvider>();
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
    LocationId id, {
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
    required IList<Location> locations,
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
      final guardedLocation = NearestLocation.of(guard.context);
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

class MyRouterDataProvider extends StatefulWidget {
  final MyRouter myRouter;
  final Widget child;

  const MyRouterDataProvider({
    required this.myRouter,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  State<MyRouterDataProvider> createState() => _MyRouterDataProviderState();
}

class _MyRouterDataProviderState extends State<MyRouterDataProvider> {
  @override
  void initState() {
    super.initState();
    widget.myRouter.addListener(handleMyRouterNotify);
  }

  @override
  Widget build(BuildContext context) {
    return _MyRouterDataProvider(
      myRouter: widget.myRouter,
      locations: widget.myRouter.currentLocations,
      pathParameters: widget.myRouter.currentPathParameters,
      queryParameters:
          widget.myRouter.currentPath?.queryParameters.toIMap() ?? IMap(),
      child: NotificationListener(
        child: widget.child,
        onNotification: (notification) {
          if (notification is AddLocationGuardMessage) {
            widget.myRouter.addGuard(notification.state);
            return true;
          }
          if (notification is RemoveLocationGuardMessage) {
            widget.myRouter.removeGuard(notification.state);
            return true;
          }
          return false;
        },
      ),
    );
  }

  void handleMyRouterNotify() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.myRouter.removeListener(handleMyRouterNotify);
    super.dispose();
  }
}

class _MyRouterDataProvider extends InheritedWidget {
  final MyRouter myRouter;
  final IList<Location> locations;
  final IMap<String, String> queryParameters;
  final IMap<String, String> pathParameters;

  const _MyRouterDataProvider({
    required this.myRouter,
    required this.locations,
    required this.queryParameters,
    required this.pathParameters,
    required Widget child,
  }) : super(child: child);

  @override
  bool updateShouldNotify(covariant _MyRouterDataProvider oldWidget) {
    return oldWidget.locations != locations ||
        oldWidget.queryParameters != queryParameters ||
        oldWidget.pathParameters != pathParameters;
  }
}
