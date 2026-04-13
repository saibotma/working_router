import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_page_skeleton.dart';
import 'package:working_router/src/location_tree_element.dart';
import 'package:working_router/src/multi_shell_location.dart';
import 'package:working_router/src/multi_shell_location_page_skeleton.dart';
import 'package:working_router/src/nested_location_page_skeleton.dart';
import 'package:working_router/src/path_location_tree_element.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/shell_location.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildPages<ID> =
    List<LocationPageSkeleton<ID>> Function(
      WorkingRouter<ID> router,
      AnyLocation<ID> location,
      WorkingRouterData<ID> data,
    );

enum _MatchedNodeRenderKind {
  node,
  shell,
  multiShell,
  shellLocationShell,
  multiShellLocationShell,
}

typedef _MatchedNodeEntry<ID> = ({
  LocationTreeElement<ID> node,
  WorkingRouterKey effectiveParentRouterKey,
  _MatchedNodeRenderKind renderKind,
});

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
          .map((entry) {
            return _buildPagesForMatchedEntry(entry, _data!).map((
              pageSkeleton,
            ) {
              return pageSkeleton.inflate(
                data: _data!,
                router: router,
                node: entry.node,
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
  Iterable<_MatchedNodeEntry<ID>> _matchedNodesForNavigator(
    WorkingRouterData<ID> data,
  ) sync* {
    for (final entry in _matchedNodesWithEffectiveParentRouterKeys(data)) {
      if (identical(entry.effectiveParentRouterKey, routerKey)) {
        yield entry;
      }
    }
  }

  Iterable<_MatchedNodeEntry<ID>> _matchedNodesWithEffectiveParentRouterKeys(
    WorkingRouterData<ID> data,
  ) sync* {
    WorkingRouterKey childRouterKey = router.rootRouterKey;
    // Disabled shells and multi shell content slots still have stable router
    // keys in build callbacks, but for routing ownership those keys alias back
    // to the parent navigator. This keeps explicit parentRouterKey references
    // working without forcing responsive tree rewrites.
    final aliasedRouterKeys = <WorkingRouterKey, WorkingRouterKey>{};

    for (final node in data.elements) {
      final inheritedParentRouterKey =
          aliasedRouterKeys[node.parentRouterKey] ??
          node.parentRouterKey ??
          childRouterKey;
      final effectiveParentRouterKey = inheritedParentRouterKey;
      switch (node) {
        case final AbstractMultiShell<ID> multiShell:
          if (multiShell.navigatorEnabled) {
            yield (
              node: node,
              effectiveParentRouterKey: effectiveParentRouterKey,
              renderKind: _MatchedNodeRenderKind.multiShell,
            );
          }
          for (final slot in multiShell.slots) {
            aliasedRouterKeys[slot.routerKey] = multiShell.navigatorEnabled
                ? slot.routerKey
                : effectiveParentRouterKey;
          }
          childRouterKey = effectiveParentRouterKey;
        case final AbstractMultiShellLocation<ID, dynamic> multiShellLocation:
          if (multiShellLocation.navigatorEnabled) {
            yield (
              node: node,
              effectiveParentRouterKey: effectiveParentRouterKey,
              renderKind: _MatchedNodeRenderKind.multiShellLocationShell,
            );
          }
          final effectiveContentChildRouterKey = multiShellLocation
                  .navigatorEnabled
              ? multiShellLocation.contentRouterKey
              : effectiveParentRouterKey;
          yield (
            node: node,
            effectiveParentRouterKey: effectiveContentChildRouterKey,
            renderKind: _MatchedNodeRenderKind.node,
          );
          aliasedRouterKeys[multiShellLocation.contentRouterKey] =
              effectiveContentChildRouterKey;
          for (final slot in multiShellLocation.slots) {
            aliasedRouterKeys[slot.routerKey] = multiShellLocation
                    .navigatorEnabled
                ? slot.routerKey
                : effectiveParentRouterKey;
          }
          childRouterKey = effectiveContentChildRouterKey;
        case final AbstractShellLocation<ID, dynamic> shellLocation:
          // A shell location contributes two render phases from one matched
          // semantic node: its outer shell page on the parent navigator and
          // its inner location page on its own nested navigator.
          if (shellLocation.navigatorEnabled) {
            yield (
              node: node,
              effectiveParentRouterKey: effectiveParentRouterKey,
              renderKind: _MatchedNodeRenderKind.shellLocationShell,
            );
          }
          final effectiveShellChildRouterKey = shellLocation.navigatorEnabled
              ? shellLocation.routerKey
              : effectiveParentRouterKey;
          yield (
            node: node,
            effectiveParentRouterKey: effectiveShellChildRouterKey,
            renderKind: _MatchedNodeRenderKind.node,
          );
          aliasedRouterKeys[shellLocation.routerKey] =
              effectiveShellChildRouterKey;
          childRouterKey = effectiveShellChildRouterKey;
        case final AbstractShell<ID> shell:
          if (shell.navigatorEnabled) {
            yield (
              node: node,
              effectiveParentRouterKey: effectiveParentRouterKey,
              renderKind: _MatchedNodeRenderKind.shell,
            );
          }
          final effectiveShellChildRouterKey = shell.navigatorEnabled
              ? shell.routerKey
              : effectiveParentRouterKey;
          aliasedRouterKeys[shell.routerKey] = effectiveShellChildRouterKey;
          childRouterKey = effectiveShellChildRouterKey;
        case PathLocationTreeElement<ID>():
          yield (
            node: node,
            effectiveParentRouterKey: effectiveParentRouterKey,
            renderKind: _MatchedNodeRenderKind.node,
          );
          childRouterKey = effectiveParentRouterKey;
      }
    }
  }

  bool _navigatorWouldBuildPages(
    WorkingRouterKey navigatorRouterKey,
    WorkingRouterData<ID> data,
  ) {
    // A shell only contributes a page when its own navigator would actually
    // build at least one page from later matched descendants. If no matched
    // descendant is assigned to that navigator, the shell stays in the matched
    // element chain for shared path/query semantics but renders no page,
    // effectively behaving like a Scope.
    for (final entry in _matchedNodesWithEffectiveParentRouterKeys(data)) {
      if (!identical(entry.effectiveParentRouterKey, navigatorRouterKey)) {
        continue;
      }

      switch ((entry.renderKind, entry.node)) {
        case (_MatchedNodeRenderKind.shell, final AbstractShell<ID> shell):
          if (_navigatorWouldBuildPages(shell.routerKey, data)) {
            return true;
          }
        case (_MatchedNodeRenderKind.multiShell, final AbstractMultiShell<ID> multiShell):
          if (multiShell.slots.any(
            (slot) => _navigatorWouldBuildPages(slot.routerKey, data),
          )) {
            return true;
          }
        case (
          _MatchedNodeRenderKind.shellLocationShell,
          final AbstractShellLocation<ID, dynamic> shellLocation,
        ):
          if (_navigatorWouldBuildPages(shellLocation.routerKey, data)) {
            return true;
          }
        case (
          _MatchedNodeRenderKind.multiShellLocationShell,
          final AbstractMultiShellLocation<ID, dynamic> multiShellLocation,
        ):
          if (_navigatorWouldBuildPages(
                multiShellLocation.contentRouterKey,
                data,
              ) ||
              multiShellLocation.slots.any(
                (slot) => _navigatorWouldBuildPages(slot.routerKey, data),
              )) {
            return true;
          }
        case (_, final AnyLocation<ID> location):
          if (_buildPagesForLocation(location, data).isNotEmpty) {
            return true;
          }
      }
    }

    return false;
  }

  List<LocationPageSkeleton<ID>> _buildPagesForMatchedEntry(
    _MatchedNodeEntry<ID> entry,
    WorkingRouterData<ID> data,
  ) {
    switch ((entry.renderKind, entry.node)) {
      case (_MatchedNodeRenderKind.shell, final AbstractShell<ID> shell):
        // Keep shells structural unless their navigator would host a matched
        // descendant page. This allows a shell to stay in the route tree for
        // shared path/query params while descendants are routed to an ancestor
        // navigator, such as root-stacked pages on small screens.
        if (!shell.navigatorEnabled ||
            !_navigatorWouldBuildPages(shell.routerKey, data)) {
          return const [];
        }
        return [
          NestedLocationPageSkeleton(
            router: router,
            buildPages: (_, location, data) => _buildPagesForLocation(
              location,
              data,
            ),
            routerKey: shell.routerKey,
            buildChild: (context, nestedData, child) {
              return shell.buildContent(context, nestedData, child);
            },
            buildPage: shell.buildPage,
            debugLabel: '$shell',
          ),
        ];
      case (_MatchedNodeRenderKind.multiShell, final AbstractMultiShell<ID> multiShell):
        if (!multiShell.navigatorEnabled ||
            !multiShell.slots.any(
              (slot) => _navigatorWouldBuildPages(slot.routerKey, data),
            )) {
          return const [];
        }
        return [
          MultiShellLocationPageSkeleton(
            router: router,
            buildPages: (
              WorkingRouter<ID> _,
              AnyLocation<ID> location,
              WorkingRouterData<ID> data,
            ) => _buildPagesForLocation(location, data),
            activeSlots: multiShell.slots.where(
              (slot) => _navigatorWouldBuildPages(slot.routerKey, data),
            ),
            buildChild: (context, nestedData, slots) {
              return multiShell.buildContent(
                context,
                nestedData,
                slots,
              );
            },
            buildPage: multiShell.buildPage,
            debugLabel: '$multiShell',
          ),
        ];
      case (
        _MatchedNodeRenderKind.shellLocationShell,
        final AbstractShellLocation<ID, dynamic> shellLocation,
      ):
        if (!shellLocation.navigatorEnabled) {
          return const [];
        }
        return [
          NestedLocationPageSkeleton(
            router: router,
            buildPages: (_, location, data) => _buildPagesForLocation(
              location,
              data,
            ),
            routerKey: shellLocation.routerKey,
            buildChild: (context, nestedData, child) {
              return shellLocation.buildShellContent(
                context,
                nestedData,
                child,
              );
            },
            buildPage: shellLocation.buildShellPage,
            debugLabel: '$shellLocation',
          ),
        ];
      case (
        _MatchedNodeRenderKind.multiShellLocationShell,
        final AbstractMultiShellLocation<ID, dynamic> multiShellLocation,
      ):
        if (!multiShellLocation.navigatorEnabled) {
          return const [];
        }
        final contentNavigatorActive = _navigatorWouldBuildPages(
          multiShellLocation.contentRouterKey,
          data,
        );
        return [
          MultiShellLocationPageSkeleton(
            router: router,
            buildPages: (
              WorkingRouter<ID> _,
              AnyLocation<ID> location,
              WorkingRouterData<ID> data,
            ) => _buildPagesForLocation(location, data),
            activeSlots: multiShellLocation.allSlots.where(
              (slot) =>
                  identical(slot.routerKey, multiShellLocation.contentRouterKey)
                  ? contentNavigatorActive
                  : _navigatorWouldBuildPages(slot.routerKey, data),
            ),
            buildChild: (context, nestedData, slots) {
              return multiShellLocation.buildShellContent(
                context,
                nestedData,
                slots,
              );
            },
            buildPage: multiShellLocation.buildShellPage,
            debugLabel: '$multiShellLocation',
          ),
        ];
      case (_, final AnyLocation<ID> location):
        return _buildPagesForLocation(location, data);
    }

    return const [];
  }

  List<LocationPageSkeleton<ID>> _buildPagesForLocation(
    AnyLocation<ID> location,
    WorkingRouterData<ID> data,
  ) {
    if (!location.contributesPage) {
      return const [];
    }
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
