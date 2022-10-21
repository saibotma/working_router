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
    final matches = locationTree.match(uri.pathSegments.toIList());

    if (await _guard(matches)) {
      return;
    }

    currentLocations = matches;
    currentPath = uri;
    notifyListeners();
  }

  void routeToId(
    LocationId id, {
    Map<String, String> queryParameters = const {},
  }) {
    final matches = locationTree.matchId(id);
    final uri =
        _uriFromLocations(locations: matches, queryParameters: queryParameters);
    _routeTo(matches, uri);
  }

  Future<void> _routeTo(IList<Location> matches, Uri uri) async {
    if (await _guard(matches)) {
      return;
    }

    currentLocations = matches;
    currentPath = uri;
    notifyListeners();
  }

  void pop() {
    if (currentPath != null) {
      final newLocations = currentLocations.removeLast();
      final newQueryParameters =
          newLocations.last.selectQueryParameters(currentPath!.queryParameters);

      _routeTo(
        newLocations,
        _uriFromLocations(
          locations: currentLocations,
          queryParameters: newQueryParameters,
        ),
      );

      notifyListeners();
    }
  }

  Uri _uriFromLocations({
    required IList<Location> locations,
    required Map<String, String> queryParameters,
  }) {
    return Uri(
      pathSegments: currentLocations.map((e) => e.pathSegments).flattened,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
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
      currentLocations: widget.myRouter.currentLocations,
      currentPath: widget.myRouter.currentPath,
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
  final IList<Location> currentLocations;
  final Uri? currentPath;

  const _MyRouterDataProvider({
    required this.myRouter,
    required this.currentLocations,
    required this.currentPath,
    required Widget child,
  }) : super(child: child);

  @override
  bool updateShouldNotify(covariant _MyRouterDataProvider oldWidget) {
    return oldWidget.currentLocations != currentLocations ||
        oldWidget.currentPath != currentPath;
  }
}
