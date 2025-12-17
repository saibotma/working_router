import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/working_router.dart';

typedef LocationChildBuilder<ID> =
    Widget Function(BuildContext, WorkingRouterData<ID> data);
typedef LocationPageBuilder =
    Page<dynamic> Function(LocalKey? key, Widget child);
typedef LocationPageKeyBuilder<ID> = LocalKey Function(Location<ID> location);

abstract interface class LocationPageSkeleton<ID> {
  LocationPage inflate({
    required WorkingRouter<ID> router,
    required WorkingRouterData<ID> data,
    required Location<ID> location,
  });
}

/// A blueprint used by the router to insert a page built by [buildPage]
/// displaying [buildChild] into a navigator.
///
/// The key built by [buildKey] gets passed to [buildPage].
///
/// Does not hold state and thus can be reused.
class BuilderLocationPageSkeleton<ID> implements LocationPageSkeleton<ID> {
  final LocationChildBuilder<ID> buildChild;
  final LocationPageBuilder? buildPage;
  final LocationPageKeyBuilder<ID>? buildKey;

  BuilderLocationPageSkeleton({
    required this.buildChild,
    this.buildPage,
    this.buildKey,
  });

  @override
  LocationPage inflate({
    required WorkingRouter<ID> router,
    required WorkingRouterData<ID> data,
    required Location<ID> location,
  }) {
    final childKey = ValueKey(data.pathUpToLocation(location));
    final wrappedChild = InheritedWorkingRouterData(
      // Require an extra inherited widget for each location, because
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
          child: Builder(
            key: childKey,
            builder: (context) => buildChild(context, data),
          ),
        ),
      ),
    );
    final key = buildKey?.call(location) ?? ValueKey(location);
    return LocationPage(
      buildPage?.call(key, wrappedChild) ??
          MaterialPage<dynamic>(key: key, child: wrappedChild),
    );
  }
}

class ChildLocationPageSkeleton<ID> extends BuilderLocationPageSkeleton<ID> {
  ChildLocationPageSkeleton({
    required Widget child,
    super.buildPage,
    super.buildKey,
  }) : super(buildChild: (_, _) => child);
}
