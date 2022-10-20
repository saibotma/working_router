import 'package:flutter/material.dart';
import 'package:navigator_test/location_guard.dart';
import 'package:navigator_test/locations/ab_location.dart';
import 'package:navigator_test/locations/abc_location.dart';

import 'locations/a_location.dart';
import 'locations/ad_location.dart';
import 'locations/adc_location.dart';
import 'locations/location.dart';
import 'locations/splash_location.dart';

enum LocationId { splash, a, ab, abc, ad, adc }

class MyRouter with ChangeNotifier {
  late List<Location> currentLocations = [locationTree];
  String currentPath = "/";

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

  Future<void> routeToUri(String uri) async {
    print("routeToUri: $uri");
    final splitUri = uri.split("?");
    assert(splitUri.isNotEmpty);
    final path = splitUri.first;
    final Map<String, String> queryParameters = splitUri.length > 1
        ? Map.fromEntries(splitUri[1].split("&").map((e) {
            final split = e.split("=");
            return MapEntry(split[0], split[1]);
          }))
        : {};

    final matches = locationTree.match(path);

    for (final guard in guards) {
      if (currentLocations.any(guard.widget.guard) &&
          !matches.any(guard.widget.guard)) {
        if (!(await guard.widget.mayLeave())) {
          return;
        }
      }
    }

    currentLocations = matches;
    currentPath = uri;
    notifyListeners();
  }

  /*
  void routeToLocation(Location location) {
    print("routeToLocation: $location");
    currentLocations = location;
    if (location is SplashLocation) {
      currentPath = "/";
    } else if (location is ALocation) {
      currentPath = "/a";
    } else if (location is ABLocation) {
      currentPath = "/a/b";
    } else if (location is ABCLocation) {
      currentPath = "/a/b/c";
    } else if (location is ADLocation) {
      currentPath = "/a/d";
    } else if (location is ADCLocation) {
      currentPath = "/a/d/c";
    }
    notifyListeners();
  }*/

  void pop() {
    //routeToLocation(currentLocations.pop());
    notifyListeners();
  }

  final List<LocationGuardState> guards = [];

  void addGuard(LocationGuardState guard) {
    guards.add(guard);
  }

  void removeGuard(LocationGuardState guard) {
    guards.remove(guard);
  }
}

class MyRouterProvider extends StatelessWidget {
  final MyRouter myRouter;
  final Widget child;

  const MyRouterProvider({
    required this.myRouter,
    required this.child,
    Key? key,
  }) : super(key: key);

  static MyRouter of(BuildContext context) {
    final MyRouterProvider? routerProvider =
        context.findAncestorWidgetOfExactType<MyRouterProvider>();
    return routerProvider!.myRouter;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      child: child,
      onNotification: (notification) {
        if (notification is AddLocationGuardMessage) {
          myRouter.addGuard(notification.state);
          return true;
        }
        return false;
      },
    );
  }
}
