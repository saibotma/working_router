import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/working_router.dart';

typedef LocationChildBuilder =
    Widget Function(BuildContext, WorkingRouterData data);
typedef LocationPageBuilder =
    Page<dynamic> Function(LocalKey? key, Widget child);
typedef LocationPageKeyBuilder =
    LocalKey Function(AnyLocation location, WorkingRouterData data);
typedef LocationChildWrapper =
    Widget Function(
      BuildContext context,
      AnyLocation location,
      WorkingRouterData data,
      Widget child,
    );

abstract interface class LocationPageSkeleton {
  LocationPage inflate({
    required WorkingRouter router,
    required WorkingRouterData data,
    required RouteNode node,
  });
}

/// A blueprint used by the router to insert a page built by [buildPage]
/// displaying [buildChild] into a navigator.
///
/// The key built by [buildPageKey] from [location] and [data]
/// gets passed to [buildPage].
///
/// Does not hold state and thus can be reused.
class BuilderLocationPageSkeleton implements LocationPageSkeleton {
  final LocationChildBuilder buildChild;
  final LocationPageBuilder? buildPage;
  final LocationPageKeyBuilder? buildPageKey;

  BuilderLocationPageSkeleton({
    required this.buildChild,
    this.buildPage,
    this.buildPageKey,
  });

  @override
  LocationPage inflate({
    required WorkingRouter router,
    required WorkingRouterData data,
    required RouteNode node,
  }) {
    // Keep the widget subtree keyed by the fully hydrated matched path.
    // This lets inner widget state reset when a path parameter changes, while
    // still preserving the outer Page identity.
    final childKey = ValueKey((node.runtimeType, data.pathUpToNode(node)));
    final builtChild = Builder(
      key: childKey,
      builder: (context) {
        final child = buildChild(context, data);
        if (node case final AnyLocation location) {
          final wrapChild = router.wrapLocationChild;
          if (wrapChild != null) {
            return wrapChild(context, location, data, child);
          }
        }
        return child;
      },
    );
    final wrappedChild = InheritedWorkingRouterData(
      // Require an extra inherited widget for each location, because
      // the widget below should have access to old router data, when
      // it animates out of view because of a routing event.
      data: data,
      child: switch (node) {
        final AnyLocation location => NearestLocation(
          location: location,
          child: NotificationListener(
            onNotification: (notification) {
              if (notification is AddLocationObserverMessage) {
                router.addObserver(notification.state);
                return true;
              }
              if (notification is RemoveLocationObserverMessage) {
                router.removeObserver(notification.state);
                return true;
              }
              return false;
            },
            child: builtChild,
          ),
        ),
        _ => builtChild,
      },
    );
    final pageKey = node.buildPageKey(data);
    final key = node is AnyLocation
        ? (buildPageKey?.call(node, data) ?? pageKey)
        : pageKey;
    return LocationPage(
      buildPage?.call(key, wrappedChild) ??
          MaterialPage<dynamic>(key: key, child: wrappedChild),
    );
  }
}

class ChildLocationPageSkeleton extends BuilderLocationPageSkeleton {
  ChildLocationPageSkeleton({
    required Widget child,
    super.buildPage,
    super.buildPageKey,
  }) : super(buildChild: (_, _) => child);
}
