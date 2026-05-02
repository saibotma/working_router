import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/multi_shell.dart';
import 'package:working_router/src/multi_shell_location.dart';
import 'package:working_router/src/overlay.dart';
import 'package:working_router/src/path_route_node.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/shell.dart';
import 'package:working_router/src/shell_location.dart';
import 'package:working_router/src/widgets/location_observer.dart';
import 'package:working_router/src/widgets/nearest_location.dart';
import 'package:working_router/src/widgets/nested_routing.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_information_parser.dart';
import 'package:working_router/src/working_router_key.dart';

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
  List<Page<dynamic>> Function(WorkingRouterData data)? buildDefaultPages;
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
            "Nested routers must not build an empty page stack.",
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
    final data = _data;
    if (data != null) {
      final routedPages = _matchedNodesForNavigator(
        data,
      ).expand((entry) => _pagesForMatchedEntry(entry, data)).toList();
      final defaultPages = buildDefaultPages?.call(data) ?? const [];
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

  AnyLocation? deepestLocationInNavigator({
    required WorkingRouterData data,
    required AnyRouteNodeId locationId,
  }) {
    final navigatorKeysInSubtree = <WorkingRouterKey>{};
    var foundTargetLocation = false;
    AnyLocation? deepestLocation;

    for (final entry in _matchedNodesWithEffectiveParentRouterKeys(data)) {
      final node = entry.node;
      if (!foundTargetLocation) {
        if (node is AnyLocation &&
            node.id == locationId &&
            entry.renderKind == _MatchedNodeRenderKind.node) {
          foundTargetLocation = true;
          deepestLocation = node;
          navigatorKeysInSubtree.addAll(_ownedNavigatorKeys(entry));
        }
        continue;
      }

      final isRenderedInSubtree = navigatorKeysInSubtree.any(
        (routerKey) => identical(routerKey, entry.effectiveParentRouterKey),
      );
      if (!isRenderedInSubtree) {
        if (node is AnyLocation) {
          break;
        }
        continue;
      }

      navigatorKeysInSubtree.addAll(_ownedNavigatorKeys(entry));
      if (node is AnyLocation &&
          entry.renderKind == _MatchedNodeRenderKind.node) {
        deepestLocation = node;
      }
    }

    return deepestLocation;
  }

  Iterable<WorkingRouterKey> _ownedNavigatorKeys(
    _MatchedNodeEntry entry,
  ) sync* {
    switch (entry.node) {
      case final AbstractMultiShell multiShell:
        if (!multiShell.navigatorEnabled) {
          return;
        }
        for (final slotDefinition in multiShell.slotDefinitions) {
          if (slotDefinition.navigatorEnabled) {
            yield slotDefinition.slot.routerKey;
          }
        }
      case final MultiShellLocation multiShellLocation:
        if (!multiShellLocation.navigatorEnabled) {
          return;
        }
        yield multiShellLocation.contentRouterKey;
        for (final slotDefinition in multiShellLocation.slotDefinitions) {
          if (slotDefinition.navigatorEnabled) {
            yield slotDefinition.slot.routerKey;
          }
        }
      case final ShellLocation shellLocation:
        if (shellLocation.navigatorEnabled) {
          yield shellLocation.routerKey;
        }
      case final AbstractShell shell:
        if (shell.navigatorEnabled) {
          yield shell.routerKey;
        }
      case PathRouteNode() || AnyOverlay():
        return;
    }
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
        case final MultiShellLocation multiShellLocation:
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
        case final ShellLocation shellLocation:
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

  bool _navigatorWouldRenderPages(
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
          if (shell.hasDefaultPage ||
              _navigatorWouldRenderPages(shell.routerKey, data)) {
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
          final ShellLocation shellLocation,
        ):
          if (shellLocation.hasDefaultPage ||
              _navigatorWouldRenderPages(shellLocation.routerKey, data)) {
            return true;
          }
        case (
          _MatchedNodeRenderKind.multiShellLocationShell,
          final MultiShellLocation multiShellLocation,
        ):
          if (multiShellLocation.contentSlotDefinition.hasDefault ||
              _navigatorWouldRenderPages(
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
          if (_pagesForLocation(location, data).isNotEmpty) {
            return true;
          }
        case (_, final AnyOverlay overlay):
          if (_pagesForOverlay(overlay, data).isNotEmpty) {
            return true;
          }
      }
    }

    return false;
  }

  List<Page<dynamic>> _pagesForMatchedEntry(
    _MatchedNodeEntry entry,
    WorkingRouterData data,
  ) {
    switch ((entry.renderKind, entry.node)) {
      case (_MatchedNodeRenderKind.shell, final AbstractShell shell):
        if (!shell.navigatorEnabled) {
          return const [];
        }
        final navigatorWouldRenderPages = _navigatorWouldRenderPages(
          shell.routerKey,
          data,
        );
        if (!navigatorWouldRenderPages) {
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
          _buildNodePage(
            node: shell,
            data: data,
            buildChild: (context, nestedData) {
              final nested = NestedRouting(
                router: router,
                buildDefaultPages: shell.hasDefaultPage
                    ? (data) => shell.buildDefaultPages(data)
                    : null,
                routerKey: shell.routerKey,
                debugLabel: '$shell',
              );
              return shell.buildContent(context, nestedData, nested);
            },
            buildPage: shell.buildPage,
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
          _buildNodePage(
            node: multiShell,
            data: data,
            buildChild: (context, nestedData) {
              final slotChildren = MultiShellSlotChildren({
                for (final resolvedSlot in resolvedSlots)
                  resolvedSlot.slot: _buildSlotChild(
                    resolvedSlot: resolvedSlot,
                    debugLabel: '$multiShell',
                  ),
              });
              return multiShell.buildContent(
                context,
                nestedData,
                slotChildren,
              );
            },
            buildPage: multiShell.buildPage,
          ),
        ];
      case (
        _MatchedNodeRenderKind.shellLocationShell,
        final ShellLocation shellLocation,
      ):
        if (!shellLocation.navigatorEnabled) {
          return const [];
        }
        return [
          _buildNodePage(
            node: shellLocation,
            data: data,
            buildChild: (context, nestedData) {
              final nested = NestedRouting(
                router: router,
                buildDefaultPages: shellLocation.hasDefaultPage
                    ? (data) => shellLocation.buildDefaultPages(data)
                    : null,
                routerKey: shellLocation.routerKey,
                debugLabel: '$shellLocation',
              );
              return shellLocation.buildShellContent(
                context,
                nestedData,
                nested,
              );
            },
            buildPage: shellLocation.buildShellPage,
          ),
        ];
      case (
        _MatchedNodeRenderKind.multiShellLocationShell,
        final MultiShellLocation multiShellLocation,
      ):
        if (!multiShellLocation.navigatorEnabled) {
          return const [];
        }
        final resolvedExtraSlots = _resolveMultiShellSlots(
          multiShellLocation.slotDefinitions,
          data,
          containerNavigatorEnabled: true,
        );
        final contentNavigatorActive = _navigatorWouldRenderPages(
          multiShellLocation.contentRouterKey,
          data,
        );
        return [
          _buildNodePage(
            node: multiShellLocation,
            data: data,
            buildChild: (context, nestedData) {
              final slotChildren = MultiShellSlotChildren({
                for (final resolvedSlot in [
                  MultiShellResolvedSlot(
                    definition: multiShellLocation.contentSlotDefinition,
                    isEnabled: true,
                    hasRoutedContent: contentNavigatorActive,
                  ),
                  ...resolvedExtraSlots,
                ])
                  resolvedSlot.slot: _buildSlotChild(
                    resolvedSlot: resolvedSlot,
                    debugLabel: '$multiShellLocation',
                  ),
              });
              return multiShellLocation.buildShellContent(
                context,
                nestedData,
                slotChildren,
              );
            },
            buildPage: multiShellLocation.buildShellPage,
          ),
        ];
      case (_, final AnyLocation location):
        return _pagesForLocation(location, data);
      case (_, final AnyOverlay overlay):
        return _pagesForOverlay(overlay, data);
    }

    return const [];
  }

  List<Page<dynamic>> _pagesForLocation(
    AnyLocation location,
    WorkingRouterData data,
  ) {
    if (!location.contributesPage) {
      return const [];
    }
    return [
      _buildNodePage(
        node: location,
        data: data,
        buildChild: (context, currentData) {
          final child = location.buildWidget(context, currentData);
          if (child == null) {
            throw StateError(
              'Location ${location.runtimeType} does not build content.',
            );
          }
          return child;
        },
        buildPage: location.buildPage,
      ),
    ];
  }

  List<Page<dynamic>> _pagesForOverlay(
    AnyOverlay overlay,
    WorkingRouterData data,
  ) {
    if (!overlay.contributesPage) {
      return const [];
    }
    return [
      _buildNodePage(
        node: overlay,
        data: data,
        buildChild: overlay.buildWidget,
        buildPage: overlay.buildPage,
      ),
    ];
  }

  Page<dynamic> _buildNodePage({
    required RouteNode node,
    required WorkingRouterData data,
    required Widget Function(BuildContext context, WorkingRouterData data)
    buildChild,
    required Page<dynamic> Function(LocalKey? key, Widget child) buildPage,
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
    return buildPage(node.buildPageKey(data), wrappedChild);
  }

  MultiShellResolvedSlotChild _buildSlotChild({
    required MultiShellResolvedSlot resolvedSlot,
    required String? debugLabel,
  }) {
    if (!resolvedSlot.isEnabled) {
      return const MultiShellResolvedSlotChild(
        isEnabled: false,
        child: null,
      );
    }
    final buildDefaultWidget = resolvedSlot.definition.buildDefaultWidget;
    if (!resolvedSlot.hasRoutedContent && buildDefaultWidget == null) {
      return const MultiShellResolvedSlotChild(
        isEnabled: true,
        child: null,
      );
    }

    return MultiShellResolvedSlotChild(
      isEnabled: true,
      child: NestedRouting(
        router: router,
        buildDefaultPages: buildDefaultWidget == null
            ? null
            : (data) => [
                _buildDefaultPage(
                  data: data,
                  resolvedSlot: resolvedSlot,
                ),
              ],
        routerKey: resolvedSlot.slot.routerKey,
        debugLabel:
            resolvedSlot.slot.debugLabel ?? '$debugLabel/${resolvedSlot.slot}',
      ),
    );
  }

  Page<dynamic> _buildDefaultPage({
    required WorkingRouterData data,
    required MultiShellResolvedSlot resolvedSlot,
  }) {
    final buildDefaultWidget = resolvedSlot.definition.buildDefaultWidget!;
    final defaultChild = InheritedWorkingRouterData(
      data: data,
      child: Builder(
        builder: (context) {
          return buildDefaultWidget(context, data);
        },
      ),
    );
    final key = ValueKey((resolvedSlot.slot.routerKey, 'default'));
    return resolvedSlot.definition.buildDefaultPage?.call(
          key,
          defaultChild,
        ) ??
        MaterialPage<dynamic>(key: key, child: defaultChild);
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
              _navigatorWouldRenderPages(slotDefinition.slot.routerKey, data),
        ),
    ];
  }

  void updateData(WorkingRouterData data) {
    _data = data;
    refresh();
  }

  /// Updates configuration owned by a reused nested delegate.
  ///
  /// Nested delegates intentionally survive shell widget rebuilds so their
  /// navigator state is preserved. Their configuration still has to follow the
  /// current [NestedRouting] widget, because [buildDefaultPages] is built from
  /// the current shell or slot route-node definitions.
  void updateConfiguration({
    required WorkingRouterKey routerKey,
    required List<Page<dynamic>> Function(WorkingRouterData data)?
    buildDefaultPages,
    WorkingRouterData? data,
  }) {
    this.routerKey = routerKey;
    this.buildDefaultPages = buildDefaultPages;
    if (data != null) {
      _data = data;
    }
    refresh();
  }

  /// Needs to be called when the delegate will not be used anymore.
  void deregister() {
    if (!isRootDelegate) {
      router.removeNestedDelegate(this);
    }
  }
}
