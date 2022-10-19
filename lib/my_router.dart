import 'package:flutter/material.dart';
import 'package:navigator_test/locations/ab_location.dart';
import 'package:navigator_test/locations/abc_location.dart';
import 'package:navigator_test/platform_modal/platform_modal_page.dart';

import 'locations/a_location.dart';
import 'locations/ad_location.dart';
import 'locations/adc_location.dart';
import 'locations/location.dart';
import 'locations/splash_location.dart';
import 'nested_screen.dart';

class MyRouter with ChangeNotifier {
  Location currentLocation = SplashLocation();
  String currentPath = "/";

  Map<String,
          Location Function(String path, Map<String, String> queryParameters)>
      pathToLocation = {
    "/": (_, __) => SplashLocation(),
    "/a": (_, __) => ALocation(),
    "/a/b": (_, __) => ABLocation(),
    "/a/b/c": (_, __) => ABCLocation(),
    "/a/d": (_, __) => ADLocation(),
    "/a/d/c": (_, __) => ADCLocation(),
  };

  void routeToUri(String uri) {
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

    currentLocation = pathToLocation[path]!(path, queryParameters);
    currentPath = uri;
    notifyListeners();
  }

  void routeToLocation(Location location) {
    print("routeToLocation: $location");
    currentLocation = location;
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
  }

  void pop() {
    routeToLocation(currentLocation.pop());
    notifyListeners();
  }
}

class MyRouterProvider extends StatelessWidget {
  final MyRouter myRouter;
  final Widget child;

  const MyRouterProvider(
      {required this.myRouter, required this.child, Key? key})
      : super(key: key);

  static MyRouter of(BuildContext context) {
    final MyRouterProvider? routerProvider =
        context.findAncestorWidgetOfExactType<MyRouterProvider>();
    return routerProvider!.myRouter;
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
