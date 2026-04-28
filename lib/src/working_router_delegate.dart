import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_page_skeleton.dart';
import 'package:working_router/src/multi_shell.dart';
import 'package:working_router/src/multi_shell_location.dart';
import 'package:working_router/src/multi_shell_location_page_skeleton.dart';
import 'package:working_router/src/nested_location_page_skeleton.dart';
import 'package:working_router/src/overlay.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/shell_location.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_information_parser.dart';
import 'package:working_router/src/working_router_key.dart';

typedef BuildPages =
    List<LocationPageSkeleton> Function(
      WorkingRouter router,
      AnyLocation location,
      WorkingRouterData data,
    );

enum _MatchedNodeRenderKind {
  node,
  shell,
  multiShell,
  shellLocationShell,
  multiShellLocationShell,
}

typedef _MatchedNodeEntry = ({
  RouteNode node,
  WorkingRouterKey effectiveParentRouterKey,
  _MatchedNodeRenderKind renderKind,
});

class WorkingRouterDelegate extends RouterDelegate<WorkingRouteConfiguration>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  @override
  late final GlobalKey<NavigatorState> navigatorKey;

  WorkingRouterKey routerKey;
  final bool isRootDelegate;
  final WorkingRouter router;
  final BuildPages? buildPages;
  final List<Page<dynamic>> Function(WorkingRouterData data)? buildDefaultPages;
  final Widget? noContentWidget;
  final Widget? navigatorInitializingWidget;
  final Widget Function(BuildContext context, Widget child)? wrapNavigator;

  List<Page<dynamic>>? _pages;

  // Have an extra data property here and don't get it directly from router,
  // because nested delegates should not use the newest data, when their
  // route gets animated out.
  WorkingRouterData? _data;

  WorkingRouterDelegate({
    required this.isRootDelegate,
    required this.routerKey,
    required this.router,
    required this.buildPages,
    this.buildDefaultPages,
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
  WorkingRouteConfiguration? get currentConfiguration =>
      router.nullableConfiguration;

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
                router.routeBackInNavigator(routerKey);
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
  Future<void> setNewRoutePath(WorkingRouteConfiguration configuration) {
    if (isRootDelegate) {
      router.routeToConfigurationFromRouteInformation(configuration);
    }
    return SynchronousFuture<void>(null);
  }

  void refresh() {
    if (_data != null) {
      final routedPages = _matchedNodesForNavigator(_data!)
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
      final defaultPages = buildDefaultPages?.call(_data!) ?? const [];
      _pages = [...defaultPages, ...routedPages];
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
  Iterable<_MatchedNodeEntry> _matchedNodesForNavigator(
    WorkingRouterData data,
  ) sync* {
    for (final entry in _matchedNodesWithEffectiveParentRouterKeys(data)) {
      if (identical(entry.effectiveParentRouterKey, routerKey)) {
        yield entry;
      }
    }
  }

  RouteNode? lastNodeForRouterKey(
    WorkingRouterData data,
    WorkingRouterKey routerKey,
  ) {
    RouteNode? lastNode;
    for (final entry in _matchedNodesWithEffectiveParentRouterKeys(data)) {
      if (!identical(entry.effectiveParentRouterKey, routerKey)) {
        continue;
      }
      lastNode = entry.node;
    }
    return lastNode;
  }

  Iterable<_MatchedNodeEntry> _matchedNodesWithEffectiveParentRouterKeys(
    WorkingRouterData data,
  ) sync* {
    WorkingRouterKey childRouterKey = router.rootRouterKey;
    // Disabled shells and multi shell content slots still have stable router
    // keys in build callbacks, but for routing ownership those keys alias back
    // to the parent navigator. This keeps explicit parentRouterKey references
    // working without forcing responsive tree rewrites.
    final aliasedRouterKeys = <WorkingRouterKey, WorkingRouterKey>{};

    for (final node in data.routeNodesWithOverlays) {
      final inheritedParentRouterKey =
          aliasedRouterKeys[node.parentRouterKey] ??
          node.parentRouterKey ??
          childRouterKey;
      final effectiveParentRouterKey = inheritedParentRouterKey;
      switch (node) {
        case final AbstractMultiShell multiShell:
          if (multiShell.navigatorEnabled) {
            yield (
              node: node,
              effectiveParentRouterKey: effectiveParentRouterKey,
              renderKind: _MatchedNodeRenderKind.multiShell,
            );
          }
          for (final slotDefinition in multiShell.slotDefinitions) {
            aliasedRouterKeys[slotDefinition.slot.routerKey] =
                multiShell.navigatorEnabled && slotDefinition.navigatorEnabled
                ? slotDefinition.slot.routerKey
                : effectiveParentRouterKey;
          }
          childRouterKey = effectiveParentRouterKey;
        case final AbstractMultiShellLocation multiShellLocation:
          if (multiShellLocation.navigatorEnabled) {
            yield (
              node: node,
              effectiveParentRouterKey: effectiveParentRouterKey,
              renderKind: _MatchedNodeRenderKind.multiShellLocationShell,
            );
          }
          final effectiveContentChildRouterKey =
              multiShellLocation.navigatorEnabled
              ? multiShellLocation.contentRouterKey
              : effectiveParentRouterKey;
          yield (
            node: node,
            effectiveParentRouterKey: effectiveContentChildRouterKey,
            renderKind: _MatchedNodeRenderKind.node,
          );
          aliasedRouterKeys[multiShellLocation.contentRouterKey] =
              effectiveContentChildRouterKey;
          for (final slotDefinition in multiShellLocation.slotDefinitions) {
            aliasedRouterKeys[slotDefinition.slot.routerKey] =
                multiShellLocation.navigatorEnabled &&
                    slotDefinition.navigatorEnabled
                ? slotDefinition.slot.routerKey
                : effectiveParentRouterKey;
          }
          childRouterKey = effectiveContentChildRouterKey;
        case final AbstractShellLocation shellLocation:
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
        case final AbstractShell shell:
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
        case PathRouteNode():
          yield (
            node: node,
            effectiveParentRouterKey: effectiveParentRouterKey,
            renderKind: _MatchedNodeRenderKind.node,
          );
          childRouterKey = effectiveParentRouterKey;
        case AnyOverlay():
          yield (
            node: node,
            effectiveParentRouterKey: effectiveParentRouterKey,
            renderKind: _MatchedNodeRenderKind.node,
          );
      }
    }
  }

  bool _navigatorWouldBuildPages(
    WorkingRouterKey navigatorRouterKey,
    WorkingRouterData data,
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
        case (_MatchedNodeRenderKind.shell, final AbstractShell shell):
          if (_navigatorWouldBuildPages(shell.routerKey, data)) {
            return true;
          }
        case (
          _MatchedNodeRenderKind.multiShell,
          final AbstractMultiShell multiShell,
        ):
          if (_resolveMultiShellSlots(
            multiShell.slotDefinitions,
            data,
            containerNavigatorEnabled: multiShell.navigatorEnabled,
          ).isNotEmpty) {
            return true;
          }
        case (
          _MatchedNodeRenderKind.shellLocationShell,
          final AbstractShellLocation shellLocation,
        ):
          if (_navigatorWouldBuildPages(shellLocation.routerKey, data)) {
            return true;
          }
        case (
          _MatchedNodeRenderKind.multiShellLocationShell,
          final AbstractMultiShellLocation multiShellLocation,
        ):
          if (_navigatorWouldBuildPages(
                multiShellLocation.contentRouterKey,
                data,
              ) ||
              _resolveMultiShellSlots(
                multiShellLocation.slotDefinitions,
                data,
                containerNavigatorEnabled: multiShellLocation.navigatorEnabled,
              ).isNotEmpty) {
            return true;
          }
        case (_, final AnyLocation location):
          if (_buildPagesForLocation(location, data).isNotEmpty) {
            return true;
          }
        case (_, final AnyOverlay overlay):
          if (_buildPagesForOverlay(overlay, data).isNotEmpty) {
            return true;
          }
      }
    }

    return false;
  }

  List<LocationPageSkeleton> _buildPagesForMatchedEntry(
    _MatchedNodeEntry entry,
    WorkingRouterData data,
  ) {
    switch ((entry.renderKind, entry.node)) {
      case (_MatchedNodeRenderKind.shell, final AbstractShell shell):
        if (!shell.navigatorEnabled) {
          return const [];
        }
        final navigatorWouldBuildPages = _navigatorWouldBuildPages(
          shell.routerKey,
          data,
        );
        if (!navigatorWouldBuildPages) {
          if (_hasMatchedDescendantAfter(entry.node, data)) {
            if (!shell.hasDefaultPage) {
              throw StateError(
                'Enabled shell ${shell.runtimeType} has matched descendants, '
                'but none are assigned to its routerKey. Disable '
                'navigatorEnabled, configure defaultContent/defaultPage, '
                'or route a child to this shell navigator.',
              );
            }
          } else {
            return const [];
          }
        }
        return [
          NestedLocationPageSkeleton(
            router: router,
            buildPages: (_, location, data) => _buildPagesForLocation(
              location,
              data,
            ),
            buildDefaultPages: shell.hasDefaultPage
                ? (data) => shell.buildDefaultPages(data)
                : null,
            routerKey: shell.routerKey,
            buildChild: (context, nestedData, child) {
              return shell.buildContent(context, nestedData, child);
            },
            buildPage: shell.buildPage,
            debugLabel: '$shell',
          ),
        ];
      case (
        _MatchedNodeRenderKind.multiShell,
        final AbstractMultiShell multiShell,
      ):
        if (!multiShell.navigatorEnabled) {
          return const [];
        }
        final resolvedSlots = _resolveMultiShellSlots(
          multiShell.slotDefinitions,
          data,
          containerNavigatorEnabled: true,
        );
        if (resolvedSlots.isEmpty) {
          return const [];
        }
        return [
          MultiShellLocationPageSkeleton(
            router: router,
            buildPages:
                (
                  WorkingRouter _,
                  AnyLocation location,
                  WorkingRouterData data,
                ) => _buildPagesForLocation(location, data),
            slots: resolvedSlots,
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
        final AbstractShellLocation shellLocation,
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
            buildDefaultPages: shellLocation.hasDefaultPage
                ? (data) => shellLocation.buildDefaultPages(data)
                : null,
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
        final AbstractMultiShellLocation multiShellLocation,
      ):
        if (!multiShellLocation.navigatorEnabled) {
          return const [];
        }
        final resolvedExtraSlots = _resolveMultiShellSlots(
          multiShellLocation.slotDefinitions,
          data,
          containerNavigatorEnabled: true,
        );
        final contentNavigatorActive = _navigatorWouldBuildPages(
          multiShellLocation.contentRouterKey,
          data,
        );
        return [
          MultiShellLocationPageSkeleton(
            router: router,
            buildPages:
                (
                  WorkingRouter _,
                  AnyLocation location,
                  WorkingRouterData data,
                ) => _buildPagesForLocation(location, data),
            slots: [
              MultiShellResolvedSlot(
                definition: multiShellLocation.contentSlotDefinition,
                isEnabled: true,
                hasRoutedContent: contentNavigatorActive,
              ),
              ...resolvedExtraSlots,
            ],
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
      case (_, final AnyLocation location):
        return _buildPagesForLocation(location, data);
      case (_, final AnyOverlay overlay):
        return _buildPagesForOverlay(overlay, data);
    }

    return const [];
  }

  List<LocationPageSkeleton> _buildPagesForLocation(
    AnyLocation location,
    WorkingRouterData data,
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

  List<LocationPageSkeleton> _buildPagesForOverlay(
    AnyOverlay overlay,
    WorkingRouterData data,
  ) {
    if (!overlay.contributesPage) {
      return const [];
    }
    return [
      BuilderLocationPageSkeleton(
        buildChild: overlay.buildWidget,
        buildPage: overlay.buildPage,
      ),
    ];
  }

  bool _hasMatchedDescendantAfter(
    RouteNode node,
    WorkingRouterData data,
  ) {
    var foundNode = false;
    for (final current in data.routeNodesWithOverlays) {
      if (foundNode) {
        return true;
      }
      if (identical(current, node)) {
        foundNode = true;
      }
    }
    return false;
  }

  List<MultiShellResolvedSlot> _resolveMultiShellSlots(
    List<MultiShellSlotDefinition> slotDefinitions,
    WorkingRouterData data, {
    required bool containerNavigatorEnabled,
  }) {
    return [
      for (final slotDefinition in slotDefinitions)
        MultiShellResolvedSlot(
          definition: slotDefinition,
          isEnabled:
              containerNavigatorEnabled && slotDefinition.navigatorEnabled,
          hasRoutedContent:
              containerNavigatorEnabled &&
              slotDefinition.navigatorEnabled &&
              _navigatorWouldBuildPages(slotDefinition.slot.routerKey, data),
        ),
    ];
  }

  /// Adapts the new location-owned `buildWidget` / `buildPage` API to the
  /// existing skeleton-based delegate flow. Returns `null` when the location
  /// still relies on the legacy `buildPages` callback.
  List<LocationPageSkeleton>? _selfBuiltPages(
    AnyLocation location,
    WorkingRouterData data,
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

  void updateData(WorkingRouterData data) {
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
