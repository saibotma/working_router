import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'inherited_working_router_data.dart';
import 'location.dart';
import 'location_page_skeleton.dart';
import 'inherited_working_router.dart';
import 'working_router.dart';
import 'working_router_data.dart';

typedef BuildPages<ID> = List<LocationPageSkeleton<ID>> Function(
  WorkingRouter<ID> router,
  Location<ID> location,
  WorkingRouterData<ID> data,
);

class WorkingRouterDelegate<ID> extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  @override
  late final GlobalKey<NavigatorState> navigatorKey;

  final bool isRootDelegate;
  final WorkingRouter<ID> router;
  final BuildPages<ID> buildPages;
  final Widget? noContentWidget;
  final Widget? navigatorInitializingWidget;
  final Widget Function(BuildContext context, Widget child)? wrapNavigator;

  List<Page<dynamic>>? _pages;

  // Have an extra data property here and don't get it directly from router,
  // because nested delegates should not use the newest data, when their
  // route gets animated out.
  WorkingRouterData<ID>? _data;

  WorkingRouterDelegate({
    required this.isRootDelegate,
    required this.router,
    required this.buildPages,
    this.noContentWidget,
    this.navigatorInitializingWidget,
    this.wrapNavigator,
    GlobalKey<NavigatorState>? navigatorKey,
    String? debugLabel,
  }) : assert(
          isRootDelegate == (noContentWidget != null),
          "noContentWidget must be set for the root delegate, "
          "but must not be set for nested delegates.",
        ) {
    this.navigatorKey =
        navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: debugLabel);
    router.addNestedDelegate(this);
  }

  @override
  Uri? get currentConfiguration => router.nullableData?.uri;

  @override
  Widget build(BuildContext context) {
    if (_pages == null) {
      return navigatorInitializingWidget ??
          const Material(child: Center(child: CircularProgressIndicator()));
    }

    final child = Builder(
      builder: (context) {
        if (_pages!.isEmpty) {
          assert(
            isRootDelegate,
            "buildPages of nested routers must not return empty pages.",
          );
          return noContentWidget!;
        }
        return (wrapNavigator ?? (_, child) => child)(
          context,
          Navigator(
            key: navigatorKey,
            pages: _pages!,
            onPopPage: (route, dynamic result) {
              // In case of Navigator 1 route.
              if (route.settings is! Page) {
                return route.didPop(result);
              }

              // Need to execute in new cycle, because otherwise would try
              // to push onto navigator while the pop is still running
              // causing debug lock in navigator pop to assert false.
              // Schedule a Microtask instead of a Future, because
              // go_router also does it like this.
              scheduleMicrotask(() async {
                await router.routeBack();
              });
              return false;
            },
          ),
        );
      },
    );

    if (isRootDelegate) {
      return InheritedWorkingRouter(
        sailor: router,
        child: InheritedWorkingRouterData(
          // Gets updated every time the routing changes, because then
          // this gets rebuilt.
          data: router.nullableData!,
          child: child,
        ),
      );
    }

    return child;
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    if (isRootDelegate) {
      return router.routeToUri(configuration);
    }
    return SynchronousFuture(null);
  }

  void refresh() {
    if (_data != null) {
      _pages = _data!.locations
          .map((location) {
            return buildPages(router, location, _data!).map((pageSkeleton) {
              return pageSkeleton.inflate(
                data: _data!,
                router: router,
                location: location,
              );
            });
          })
          .flattened
          .map((e) => e.page)
          .toList();
      notifyListeners();
    }
  }

  void updateData(WorkingRouterData<ID> data) {
    _data = data;
    refresh();
  }

  /// Needs to be called when the delegate will not be used anymore.
  void deregister() {
    router.removeNestedDelegate(this);
  }
}
