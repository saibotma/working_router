import 'package:flutter/material.dart';
import '../working_router.dart';

class LocationPageSkeleton<ID> {
  final Widget child;
  final Page<dynamic> Function(LocalKey? key, Widget child)? buildPage;
  final LocalKey Function(Location<ID> location)? buildKey;

  LocationPageSkeleton({required this.child, this.buildPage, this.buildKey});

  LocationPage inflate({
    required WorkingRouter<ID> router,
    required WorkingRouterData<ID> data,
    required Location<ID> location,
  }) {
    final wrappedChild = WorkingRouterDataProvider(
      router: router,
      // Require an extra data provider for each location, because
      // the widget below should have access to old router data, when
      // it animates out of view because of a routing event.
      data: data,
      child: NearestLocation<ID>(
        location: location,
        child: NotificationListener(
          onNotification: (notification) {
            if (notification is AddLocationGuardMessage) {
              router.addGuard(notification.state);
              return true;
            }
            if (notification is RemoveLocationGuardMessage) {
              router.removeGuard(notification.state);
              return true;
            }
            return false;
          },
          child: child,
        ),
      ),
    );
    final key = buildKey?.call(location);
    return LocationPage(
      buildPage?.call(key, wrappedChild) ??
          MaterialPage<dynamic>(key: key, child: wrappedChild),
    );
  }
}
