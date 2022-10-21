import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/locations/location.dart';
import 'package:navigator_test/my_router.dart';

class AppellaRouterDelegate extends RouterDelegate<Uri> with ChangeNotifier {
  final bool isRootRouter;
  final MyRouter myRouter;
  final List<LocationPageSkeleton> Function(
      Location location, Location topLocation) buildPages;
  late List<Page<dynamic>> pages;
  late final GlobalKey<NavigatorState> navigatorKey;

  AppellaRouterDelegate({
    required this.isRootRouter,
    required this.myRouter,
    required this.buildPages,
  }) {
    navigatorKey = GlobalKey<NavigatorState>();
    refresh();
    myRouter.addListener(refresh);
  }

  @override
  Uri? get currentConfiguration => myRouter.currentPath;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return Material(
        child: Container(
          color: Colors.red,
          child: const Center(child: Text("Not found")),
        ),
      );
    }
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onPopPage: (route, result) {
        // In case of Navigator 1 route.
        if (route.settings is! Page) {
          return route.didPop(result);
        }

        // Need to execute in new cycle, because otherwise would try
        // to push onto navigator while the pop is still running
        // causing debug lock in navigator pop to assert false.
        Future.delayed(Duration.zero).then((_) => myRouter.pop());
        return false;
      },
    );
  }

  @override
  Future<bool> popRoute() {
    return SynchronousFuture(true);
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    if (isRootRouter) {
      myRouter.routeToUri(configuration);
    }
    return SynchronousFuture(null);
  }

  void refresh() {
    pages = myRouter.currentLocations
        .map((location) => buildPages(location, myRouter.currentLocations.last)
            .map((e) => e.inflate(location)))
        .flattened
        .map((e) => e.page)
        .toList();
    notifyListeners();
  }
}

class LocationPageSkeleton {
  final Widget child;
  final Page<dynamic> Function(LocalKey? key, Widget child)? buildPage;
  final LocalKey Function(Location location)? buildKey;

  LocationPageSkeleton({required this.child, this.buildPage, this.buildKey});

  LocationPage inflate(Location location) {
    final wrappedChild = NearestLocation(location: location, child: child);
    final key = buildKey?.call(location);
    return LocationPage(
      buildPage?.call(key, wrappedChild) ??
          MaterialPage(key: key, child: wrappedChild),
    );
  }
}

class LocationPage {
  final Page<dynamic> page;

  LocationPage(this.page);
}

class NearestLocation extends InheritedWidget {
  final Location location;

  const NearestLocation({
    required this.location,
    required super.child,
    super.key,
  });

  static Location of(BuildContext context) {
    final NearestLocation? nearestLocation =
        context.dependOnInheritedWidgetOfExactType<NearestLocation>();
    return nearestLocation!.location;
  }

  @override
  bool updateShouldNotify(covariant NearestLocation oldWidget) {
    return oldWidget.location != location;
  }
}
