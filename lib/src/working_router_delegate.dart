import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'location.dart';
import 'location_page_skeleton.dart';
import 'working_router.dart';
import 'working_router_data_provider.dart';

typedef BuildPages<ID> = List<LocationPageSkeleton<ID>> Function(
  Location<ID> location,
  Location<ID> topLocation,
);

class WorkingRouterDelegate<ID> extends RouterDelegate<Uri>
    with ChangeNotifier {
  final bool isRootDelegate;
  final WorkingRouter<ID> router;
  final BuildPages<ID> buildPages;
  late final GlobalKey<NavigatorState> navigatorKey;

  List<Page<dynamic>> pages = [];

  WorkingRouterDelegate({
    required this.isRootDelegate,
    required this.router,
    required this.buildPages,
  }) {
    navigatorKey = GlobalKey<NavigatorState>();
    // A root router may not refresh, because the data will still be null.
    // A nested router must refresh, because otherwise it will not have the
    // pages set.
    if (!isRootDelegate) refresh();
    router.addListener(refresh);
  }

  @override
  Uri? get currentConfiguration => router.data?.uri;

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
    return WorkingRouterDataProvider<ID>(
      router: router,
      child: Navigator(
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
      ),
    );
  }

  @override
  Future<bool> popRoute() {
    return SynchronousFuture(true);
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    if (isRootDelegate) {
      await router.routeToUri(configuration);
    }
  }

  void refresh() {
    final locations = router.data!.locations;
    pages = locations
        .map((location) => buildPages(location, locations.last)
            .map((e) => e.inflate(location)))
        .flattened
        .map((e) => e.page)
        .toList();
    notifyListeners();
  }
}
