import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_page_skeleton.dart';
import 'package:working_router/src/location_tree_element.dart';
import 'package:working_router/src/nested_location_page_skeleton.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildPages<ID> =
    List<LocationPageSkeleton<ID>> Function(
      WorkingRouter<ID> router,
      AnyLocation<ID> location,
      WorkingRouterData<ID> data,
    );

class WorkingRouterDelegate<ID> extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  @override
  late final GlobalKey<NavigatorState> navigatorKey;

  WorkingRouterKey routerKey;
  final bool isRootDelegate;
  final WorkingRouter<ID> router;
  final BuildPages<ID>? buildPages;
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
    required this.routerKey,
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
    if (!isRootDelegate) {
      router.addNestedDelegate(this);
    }
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
            // ignore: deprecated_member_use
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
              scheduleMicrotask(() {
                router.routeBack();
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
      router.routeToUriFromRouteInformation(configuration);
    }
    return SynchronousFuture<void>(null);
  }

  void refresh() {
    if (_data != null) {
      _pages = _matchedNodesForNavigator(_data!)
          .map((node) {
            return _buildPagesForNode(node, _data!).map((pageSkeleton) {
              return pageSkeleton.inflate(
                data: _data!,
                router: router,
                node: node,
              );
            });
          })
          .flattened
          .map((e) => e.page)
          .toList();
      notifyListeners();
    }
  }

  /// Filters the global matched node chain down to the nodes rendered by this
  /// delegate's navigator.
  ///
  /// WorkingRouterData contains the full matched chain for the current URI,
  /// including both semantic locations and structural shells. Each shell
  /// creates a routing boundary via its routerKey, so deeper nodes may belong
  /// to a nested delegate rather than this one. parentRouterKey can also route
  /// a node back to a different ancestor navigator. This method resolves that
  /// ownership and yields only the nodes assigned to the current delegate's
  /// navigator.
  Iterable<LocationTreeElement<ID>> _matchedNodesForNavigator(
    WorkingRouterData<ID> data,
  ) sync* {
    WorkingRouterKey childRouterKey = router.rootRouterKey;

    for (final node in data.elements) {
      final effectiveParentRouterKey = node.parentRouterKey ?? childRouterKey;

      if (identical(effectiveParentRouterKey, routerKey)) {
        yield node;
      }

      switch (node) {
        case Shell<ID>():
          childRouterKey = node.routerKey;
        case AnyLocation<ID>():
          childRouterKey = effectiveParentRouterKey;
      }
    }
  }

  List<LocationPageSkeleton<ID>> _buildPagesForNode(
    LocationTreeElement<ID> node,
    WorkingRouterData<ID> data,
  ) {
    if (node case final Shell<ID> shell) {
      return [
        NestedLocationPageSkeleton(
          router: router,
          buildPages: (_, location, data) => _buildPagesForLocation(
            location,
            data,
          ),
          routerKey: shell.routerKey,
          buildChild: (context, nestedData, child) {
            return shell.buildWidget(context, nestedData, child);
          },
          buildPage: shell.buildPage,
          debugLabel: '$shell',
        ),
      ];
    }

    return _buildPagesForLocation(node as AnyLocation<ID>, data);
  }

  List<LocationPageSkeleton<ID>> _buildPagesForLocation(
    AnyLocation<ID> location,
    WorkingRouterData<ID> data,
  ) {
    final selfBuiltPages = _selfBuiltPages(location, data);
    if (selfBuiltPages != null) {
      return selfBuiltPages;
    }
    final fallback = buildPages;
    if (fallback != null) {
      return fallback(router, location, data);
    }
    return const [];
  }

  /// Adapts the new location-owned `buildWidget` / `buildPage` API to the
  /// existing skeleton-based delegate flow. Returns `null` when the location
  /// still relies on the legacy `buildPages` callback.
  List<LocationPageSkeleton<ID>>? _selfBuiltPages(
    AnyLocation<ID> location,
    WorkingRouterData<ID> data,
  ) {
    if (!location.buildsOwnPage) {
      return null;
    }

    return [
      BuilderLocationPageSkeleton(
        buildChild: (context, currentData) {
          final child = location.buildWidget(context, currentData);
          if (child == null) {
            throw StateError(
              'Location ${location.runtimeType} returned null from buildWidget().',
            );
          }
          return child;
        },
        buildPage: location.buildPage,
      ),
    ];
  }

  void updateData(WorkingRouterData<ID> data) {
    _data = data;
    refresh();
  }

  void updateRouterKey(WorkingRouterKey routerKey) {
    this.routerKey = routerKey;
    refresh();
  }

  /// Needs to be called when the delegate will not be used anymore.
  void deregister() {
    if (!isRootDelegate) {
      router.removeNestedDelegate(this);
    }
  }
}
