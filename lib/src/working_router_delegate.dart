import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'location.dart';
import 'location_page_skeleton.dart';
import 'working_router.dart';

class WorkingRouterDelegate<ID> extends RouterDelegate<Uri>
    with ChangeNotifier {
  final bool isRootRouter;
  final WorkingRouter<ID> router;
  final List<LocationPageSkeleton<ID>> Function(
    Location<ID> location,
    Location<ID> topLocation,
  ) buildPages;
  late List<Page<dynamic>> pages;
  late final GlobalKey<NavigatorState> navigatorKey;

  WorkingRouterDelegate({
    required this.isRootRouter,
    required this.router,
    required this.buildPages,
  }) {
    navigatorKey = GlobalKey<NavigatorState>();
    refresh();
    router.addListener(refresh);
  }

  @override
  Uri? get currentConfiguration => router.currentPath;

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
      onPopPage: (route, dynamic result) {
        // In case of Navigator 1 route.
        if (route.settings is! Page) {
          return route.didPop(result);
        }

        // Need to execute in new cycle, because otherwise would try
        // to push onto navigator while the pop is still running
        // causing debug lock in navigator pop to assert false.
        Future<void>.delayed(Duration.zero).then((_) => router.pop());
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
      router.routeToUri(configuration);
    }
    return SynchronousFuture(null);
  }

  void refresh() {
    pages = router.currentLocations
        .map((location) => buildPages(location, router.currentLocations.last)
            .map((e) => e.inflate(location)))
        .flattened
        .map((e) => e.page)
        .toList();
    notifyListeners();
  }
}
