import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:working_router/src/inherited_working_router.dart';
import 'package:working_router/working_router.dart';

/// Rebuilds the top-level route tree for a router instance.
///
/// This callback is used at startup and again on [WorkingRouter.refresh] so the
/// runtime tree can react to changing application state such as permissions.
typedef BuildRouteNodes =
    List<RouteNode> Function(WorkingRouterKey rootRouterKey);

class WorkingRouter extends ChangeNotifier
    implements
        RouterConfig<WorkingRouteConfiguration>,
        WorkingRouterDataSailor {
  /// Does not notify widgets at all.
  /// This is meant to be used for one off calls to the router,
  /// and not rebuilding a widget based router data changes.
  /// Use [WorkingRouterData.of] for this instead.
  static WorkingRouterDataSailor of(
    BuildContext context,
  ) {
    final inheritedWidget = context
        .dependOnInheritedWidgetOfExactType<InheritedWorkingRouter>();
    return inheritedWidget!.sailor;
  }

  late final WorkingRouterDelegate _rootDelegate;
  final WorkingRouteInformationParser _informationParser =
      WorkingRouteInformationParser();
  late final WorkingRouteInformationProvider _informationProvider =
      WorkingRouteInformationProvider(
        initialRouteInformation: RouteInformation(
          // ignore: deprecated_member_use
          uri: Uri.parse(
            WidgetsBinding.instance.platformDispatcher.defaultRouteName,
          ),
        ),
        consumeReplaceBrowserHistory: _consumeReplaceBrowserHistoryReport,
      );
  final GlobalKey<NavigatorState> _rootNavigatorKey;
  final WorkingRouterKey _rootRouterKey = WorkingRouterKey();

  late IList<RouteNode> _routeNodeTree;
  final List<LocationObserverState> _observers = [];
  final List<WorkingRouterDelegate> _nestedDelegates = [];

  /// Counter to track routing requests and prevent race conditions.
  /// Each routing request captures this value at start; if a newer request
  /// starts before async `beforeLeave` checks complete, older requests
  /// are discarded.
  int _routingVersion = 0;
  bool _replaceNextBrowserHistoryReport = false;

  @Deprecated(
    "Don't use this property directly. "
    "Get is using the data getter. Set it using _updateData.",
  )
  WorkingRouterData? _data;

  final TransitionDecider? _decideTransition;
  final int _redirectLimit;

  /// Rebuilds the routing tree used by this router instance.
  ///
  /// The callback receives the stable root [WorkingRouterKey] so callers can
  /// explicitly thread it into locations that need to target the root router.
  ///
  /// When using `@RouteNodes`, pass a closure here that builds the same route
  /// tree shape as the annotated generator entrypoint.
  final BuildRouteNodes buildRouteNodes;
  final LocationChildWrapper? wrapLocationChild;

  WorkingRouter({
    required this.buildRouteNodes,
    BuildPages? buildRootPages,
    required Widget noContentWidget,
    Widget Function(BuildContext context, Widget child)? wrapNavigator,
    this.wrapLocationChild,
    TransitionDecider? decideTransition,
    int redirectLimit = 5,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : assert(redirectLimit > 0, 'redirectLimit must be greater than 0.'),
       _rootNavigatorKey =
           navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root'),
       _decideTransition = decideTransition,
       _redirectLimit = redirectLimit {
    _routeNodeTree = _buildRouteNodeTree();
    _rootDelegate = WorkingRouterDelegate(
      debugLabel: "root",
      isRootDelegate: true,
      router: this,
      buildPages: buildRootPages,
      noContentWidget: noContentWidget,
      wrapNavigator: wrapNavigator,
      navigatorKey: _rootNavigatorKey,
      routerKey: _rootRouterKey,
    );
  }

  /// This is mainly provided so that [WorkingRouter] can implement
  /// [WorkingRouterDataSailor]. In almost all other cases [nullableData]
  /// should be used.
  @override
  @protected
  // ignore: deprecated_member_use_from_same_package
  WorkingRouterData get data => _data!;

  // ignore: deprecated_member_use_from_same_package
  WorkingRouterData? get nullableData => _data;

  WorkingRouteConfiguration? get nullableConfiguration {
    final data = nullableData;
    if (data == null) {
      return null;
    }
    return _configurationFromData(data);
  }

  @override
  BackButtonDispatcher? get backButtonDispatcher => RootBackButtonDispatcher();

  @override
  RouteInformationParser<WorkingRouteConfiguration>?
  get routeInformationParser => _informationParser;

  @override
  RouteInformationProvider? get routeInformationProvider {
    return _informationProvider;
  }

  @override
  RouterDelegate<WorkingRouteConfiguration> get routerDelegate => _rootDelegate;

  @internal
  GlobalKey<NavigatorState> get rootNavigatorKey => _rootDelegate.navigatorKey;

  @internal
  WorkingRouterKey get rootRouterKey => _rootRouterKey;

  /// Rebuilds the route node tree for this router instance.
  void refresh() {
    _routeNodeTree = _buildRouteNodeTree();
    final currentData = nullableData;
    if (currentData != null) {
      // The route-node tree was rebuilt, so old matched node instances must be
      // resolved again against the new tree. Use the full internal route state
      // because data.uri may omit hidden path segments or query parameters.
      _updateData(
        _buildDataForConfiguration(_configurationFromData(currentData)),
      );
    }
    for (final it in [_rootDelegate, ..._nestedDelegates]) {
      it.refresh();
    }
  }

  IList<RouteNode> _buildRouteNodeTree() {
    final nodes = buildRouteNodes(_rootRouterKey);
    return nodes.toIList();
  }

  @override
  void routeToUriString(String uriString) {
    routeTo(UriRouteTarget(Uri.parse(uriString)));
  }

  @override
  void routeToUri(Uri uri) {
    routeTo(UriRouteTarget(uri));
  }

  @override
  void routeTo(RouteTarget target) {
    _routeTo(
      targetData: _buildDataForTarget(
        target,
        currentData: nullableData,
      ),
      reason: RouteTransitionReason.programmatic,
    );
  }

  @internal
  void routeToConfigurationFromRouteInformation(
    WorkingRouteConfiguration configuration,
  ) {
    _routeTo(
      targetData: _buildDataForConfiguration(configuration),
      reason: RouteTransitionReason.routeInformation,
    );
  }

  @override
  void routeToId(
    AnyNodeId id, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  }) {
    routeTo(
      IdRouteTarget(
        id,
        writePathParameters: writePathParameters,
        writeQueryParameters: writeQueryParameters,
      ),
    );
  }

  @override
  void routeToChildWhere(
    bool Function(AnyLocation location) predicate, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  }) {
    routeTo(
      FirstChildRouteTarget(
        predicate,
        writePathParameters: writePathParameters,
        writeQueryParameters: writeQueryParameters,
      ),
    );
  }

  @override
  void routeToChild<T>({
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  }) {
    routeToChildWhere(
      (it) => it is T,
      writePathParameters: writePathParameters,
      writeQueryParameters: writeQueryParameters,
    );
  }

  @override
  void routeBack() {
    _routeBackUntil((it) => !it.shouldBeSkippedOnRouteBack);
  }

  /// Routes back within the navigator identified by [routerKey].
  ///
  /// Nested routers expose this through [NestedWorkingRouterSailor.routeBack],
  /// so `WorkingRouter.of(context).routeBack()` naturally removes the last
  /// active location owned by the nearest nested navigator. If that navigator
  /// has no active location, this falls back to the normal global [routeBack].
  void routeBackInNavigator(WorkingRouterKey routerKey) {
    final data = nullableData;
    if (data == null) {
      return;
    }
    final node = _rootDelegate.lastNodeForRouterKey(data, routerKey);
    if (node == null) {
      routeBack();
      return;
    }

    final overlay = _activeOverlayForNode(data, node);
    if (overlay != null) {
      _routeTo(
        targetData: _buildData(
          routeNodes: data.routeNodes,
          pathParameters: data.pathParameters,
          queryParameters: _resetOverlayConditions(
            data.queryParameters,
            overlay: overlay,
          ),
        ),
        reason: RouteTransitionReason.programmatic,
      );
      return;
    }

    final locationIndex = data.routeNodes.indexWhere(
      (current) => identical(current, node),
    );
    if (locationIndex == -1) {
      return;
    }

    final newNodes = data.routeNodes.removeAt(locationIndex);
    if (newNodes.locations.length == data.routeNodes.locations.length) {
      return;
    }
    if (newNodes.locations.isEmpty) {
      routeBack();
      return;
    }

    final newPathRouteNodes = newNodes.pathRouteNodes;
    final newPathParameters = data.pathParameters.keepKeys({
      for (final element in newPathRouteNodes)
        ...element.path.whereType<PathParam<dynamic>>().map(
          (it) => it.unboundParam,
        ),
    });
    final retainedQueryParameters = data.queryParameters.keepKeys(
      newPathRouteNodes
          .expand((element) => element.queryParameters.map((it) => it.name))
          .toSet(),
    );
    _routeTo(
      targetData: _buildData(
        routeNodes: newNodes,
        pathParameters: newPathParameters,
        queryParameters: retainedQueryParameters,
      ),
      reason: RouteTransitionReason.programmatic,
    );
  }

  @override
  void routeBackFrom(AnyLocation fromLocation) {
    _routeBackUntil(
      (it) => !it.shouldBeSkippedOnRouteBack,
      fromLocation: fromLocation,
    );
  }

  @override
  void routeBackUntil(bool Function(AnyLocation location) match) {
    _routeBackUntil(match);
  }

  void _routeBackUntil(
    bool Function(AnyLocation location) match, {
    AnyLocation? fromLocation,
  }) {
    final data = nullableData!;
    final locations = data.routeNodes.locations;
    if (locations.length <= 1) {
      // Nothing to go back to
      return;
    }

    final startIndex = switch (fromLocation) {
      null => locations.length - 2,
      _ => _routeBackStartIndex(
        locations: locations,
        fromLocation: fromLocation,
      ),
    };
    if (startIndex < 0) {
      // No ancestor remains to route back to from the requested location.
      return;
    }

    // Start from the previous location relative to the requested back source.
    int matchIndex = -1;
    for (var i = startIndex; i >= 0; i--) {
      if (match(locations[i])) {
        matchIndex = i;
        break;
      }
    }

    if (matchIndex == -1) {
      // No matching location found
      return;
    }

    // Keep everything up to and including the matched location
    final newLocations = locations.sublist(0, matchIndex + 1);
    final newNodes = _trimNodesToLastMatchingLocation(data, newLocations.last);
    final newPathRouteNodes = newNodes.pathRouteNodes;
    final newPathParameters = data.pathParameters.keepKeys({
      for (final element in newPathRouteNodes)
        ...element.path.whereType<PathParam<dynamic>>().map(
          (it) => it.unboundParam,
        ),
    });

    final retainedQueryParameters = data.queryParameters.keepKeys(
      newPathRouteNodes
          .expand((element) => element.queryParameters.map((it) => it.name))
          .toSet(),
    );
    _routeTo(
      targetData: _buildData(
        routeNodes: newNodes,
        pathParameters: newPathParameters,
        queryParameters: retainedQueryParameters,
      ),
      reason: RouteTransitionReason.programmatic,
    );
  }

  AnyOverlay? _activeOverlayForNode(
    WorkingRouterData data,
    RouteNode node,
  ) {
    for (final overlays in data.activeOverlaysByOwner.values) {
      for (final overlay in overlays) {
        if (identical(overlay, node)) {
          return overlay;
        }
      }
    }
    return null;
  }

  int _routeBackStartIndex({
    required IList<AnyLocation> locations,
    required AnyLocation fromLocation,
  }) {
    for (var i = locations.length - 1; i >= 0; i--) {
      if (identical(locations[i], fromLocation)) {
        return i - 1;
      }
    }
    return -1;
  }

  void _routeTo({
    required WorkingRouterData targetData,
    required RouteTransitionReason reason,
  }) {
    final myVersion = ++_routingVersion;
    final oldData = nullableData;

    final resolvedData = _resolveTransitionDecision(
      oldData: oldData,
      initialData: targetData,
      initialReason: reason,
    );
    if (resolvedData == null) {
      return;
    }

    unawaited(
      _guardBeforeLeave(
        routingVersion: myVersion,
        newLocations: resolvedData.routeNodes.locations,
        onAllowed: () {
          final oldLocations = oldData?.routeNodes.locations;
          _replaceNextBrowserHistoryReport = _shouldReplaceBrowserHistoryReport(
            oldData,
            resolvedData,
          );
          _updateData(resolvedData);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notifyObserversAfterRouteChange(
              oldLocations: oldLocations,
              newLocations: resolvedData.routeNodes.locations,
            );
          });
        },
      ).catchError((Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'working_router',
            context: ErrorDescription(
              'while resolving async LocationObserver.beforeLeave callbacks',
            ),
          ),
        );
      }),
    );
  }

  bool _shouldReplaceBrowserHistoryReport(
    WorkingRouterData? oldData,
    WorkingRouterData newData,
  ) {
    return (oldData?.routeNodes.replacesBrowserHistory ?? false) ||
        newData.routeNodes.replacesBrowserHistory;
  }

  bool _consumeReplaceBrowserHistoryReport() {
    final replace = _replaceNextBrowserHistoryReport;
    _replaceNextBrowserHistoryReport = false;
    return replace;
  }

  Future<void> _guardBeforeLeave({
    required int routingVersion,
    required IList<AnyLocation> newLocations,
    required void Function() onAllowed,
  }) async {
    final observers = _observers.reversed.toList(growable: false);

    // Get observers in reverse order so that the last added one
    // (i.e., the innermost LocationObserver) is called first.
    for (final observer in observers) {
      if (routingVersion != _routingVersion) {
        return;
      }

      final context = observer.context;
      if (!context.mounted) {
        continue;
      }

      final currentLocations = nullableData?.routeNodes.locations;
      if (currentLocations == null) {
        break;
      }

      final observedLocation = NearestLocation.of(context);
      if (currentLocations.contains(observedLocation) &&
          !newLocations.contains(observedLocation)) {
        if (!(await observer.widget.beforeLeave?.call() ?? true)) {
          return;
        }
      }
    }

    if (routingVersion != _routingVersion) {
      return;
    }

    onAllowed();
  }

  WorkingRouterData? _resolveTransitionDecision({
    required WorkingRouterData? oldData,
    required WorkingRouterData initialData,
    required RouteTransitionReason initialReason,
  }) {
    if (initialData.routeNodes.isEmpty) {
      return initialData;
    }

    final decideTransition = _decideTransition;
    if (decideTransition == null) {
      return initialData;
    }

    var currentData = initialData;
    var currentReason = initialReason;
    var redirects = 0;
    final visitedUris = <Uri>{currentData.uri};

    while (true) {
      final decision = decideTransition(
        this,
        RouteTransition(from: oldData, to: currentData, reason: currentReason),
      );

      switch (decision) {
        case AllowTransition():
          return currentData;
        case BlockTransition():
          return null;
        case RedirectTransition(:final to):
          // Re-run the decider for redirect targets so multi-hop redirects
          // like `/a -> /b -> /c` can resolve step by step.
          redirects += 1;
          if (redirects > _redirectLimit) {
            throw StateError(
              'Redirect limit of $_redirectLimit exceeded while resolving '
              'transition to ${initialData.uri}.',
            );
          }
          final previousUri = currentData.uri;
          currentData = _buildDataForTarget(
            to,
            currentData: currentData,
            retainSharedQueryParameters: false,
          );

          if (currentData.uri == previousUri) {
            return currentData;
          }

          if (!visitedUris.add(currentData.uri)) {
            throw StateError(
              'Redirect loop detected while resolving transition to '
              '${initialData.uri}. Looping URI: ${currentData.uri}',
            );
          }
          currentReason = RouteTransitionReason.redirect;
      }
    }
  }

  WorkingRouterData _buildDataForUri(Uri uri) {
    final queryParameters = uri.queryParameters.toIMap();
    final matchResult = _routeNodeTree.match(
      uri.pathSegments.toIList(),
      queryParameters: queryParameters,
    );
    if (matchResult.isEmpty) {
      return WorkingRouterData(
        uri: uri,
        routeNodes: const IListConst([]),
        activeOverlaysByOwner: const IMapConst({}),
        pathParameters: const IMapConst({}),
        queryParameters: const IMapConst({}),
      );
    }

    return _buildData(
      routeNodes: matchResult.routeNodes,
      pathParameters: matchResult.pathParameters,
      queryParameters: queryParameters,
    );
  }

  WorkingRouterData _buildDataForConfiguration(
    WorkingRouteConfiguration configuration,
  ) {
    return _buildDataForUri(configuration.matchingUri);
  }

  WorkingRouterData _buildDataForTarget(
    RouteTarget target, {
    required WorkingRouterData? currentData,
    bool retainSharedQueryParameters = true,
  }) {
    switch (target) {
      case UriRouteTarget(:final uri):
        return _buildDataForUri(uri);
      case IdRouteTarget(
        :final id,
        :final writePathParameters,
        :final writeQueryParameters,
      ):
        final matchedNodes = _routeNodeTree.matchId(id);
        final targetLocation = matchedNodes.locations.lastOrNull;
        if (targetLocation == null || targetLocation.id != id) {
          throw StateError(
            'routeToId($id) only supports ids declared on locations. '
            'The matched route node id does not belong to a location.',
          );
        }
        final matchedPathRouteNodes = matchedNodes.pathRouteNodes;
        final sharedQueryParameterKeys =
            !retainSharedQueryParameters || currentData == null
            ? <String>{}
            : currentData.routeNodes.pathRouteNodes
                  .expand(
                    (element) => element.queryParameters.map((it) => it.name),
                  )
                  .toSet()
                  .intersection(
                    matchedPathRouteNodes
                        .expand(
                          (element) =>
                              element.queryParameters.map((it) => it.name),
                        )
                        .toSet(),
                  );
        final retainedQueryParameters = retainSharedQueryParameters
            ? currentData?.queryParameters.keepKeys(
                sharedQueryParameterKeys,
              )
            : null;

        return _buildData(
          routeNodes: matchedNodes,
          pathParameters: _resolvePathParameterWrites(
            nodes: matchedPathRouteNodes,
            writePathParameters: writePathParameters,
          ).toIMap(),
          queryParameters: _mergeQueryParameterWrites(
            initialQueryParameters: retainedQueryParameters,
            nodes: matchedPathRouteNodes,
            writeQueryParameters: writeQueryParameters,
          ),
        );
      case ChildRouteTarget(
        :final start,
        :final resolveChildPathNodes,
        :final writePathParameters,
        :final writeQueryParameters,
      ):
        final data = currentData!;
        final startIndex = data.routeNodes.indexWhere(
          (node) => identical(node, start),
        );
        if (startIndex == -1) {
          return data;
        }

        final matchedNodes = resolveChildPathNodes();
        if (matchedNodes == null || matchedNodes.isEmpty) {
          return data;
        }
        final routeNodes = data.routeNodes
            .take(startIndex + 1)
            .toIList()
            .addAll(matchedNodes);

        final queryParameters = _mergeQueryParameterWrites(
          initialQueryParameters: data.queryParameters,
          nodes: routeNodes.pathRouteNodes,
          writeQueryParameters: writeQueryParameters,
        );
        return _buildData(
          routeNodes: routeNodes,
          pathParameters: data.pathParameters.addAll(
            _resolvePathParameterWrites(
              nodes: routeNodes.pathRouteNodes,
              writePathParameters: writePathParameters,
            ).toIMap(),
          ),
          queryParameters: queryParameters,
        );
      case OverlayRouteTarget(
        :final owner,
        :final overlay,
      ):
        final data = currentData!;
        if (!data.routeNodes.any((node) => identical(node, owner))) {
          return data;
        }
        final ownerOverlays = switch (owner) {
          final PathRouteNode pathOwner => pathOwner.pathRouteOverlays,
          _ => const <AnyOverlay>[],
        };
        if (!ownerOverlays.any((node) => identical(node, overlay))) {
          return data;
        }

        var queryParameters = data.queryParameters;
        for (final condition in overlay.conditions) {
          queryParameters = _writeQueryValue(
            queryParameters,
            condition.parameter,
            condition.value,
          );
        }
        return _buildData(
          routeNodes: data.routeNodes,
          pathParameters: data.pathParameters,
          queryParameters: queryParameters,
        );
      case FirstChildRouteTarget(
        :final predicate,
        :final writePathParameters,
        :final writeQueryParameters,
      ):
        final data = currentData!;
        final currentLocation = data.leaf;
        if (currentLocation == null) {
          return data;
        }

        final matchedNodes = currentLocation.matchRelative(predicate);
        if (matchedNodes.isEmpty) {
          return data;
        }

        final routeNodes = data.routeNodes.addAll(matchedNodes);

        return _buildData(
          routeNodes: routeNodes,
          pathParameters: data.pathParameters.addAll(
            _resolvePathParameterWrites(
              nodes: routeNodes.pathRouteNodes,
              writePathParameters: writePathParameters,
            ).toIMap(),
          ),
          queryParameters: _mergeQueryParameterWrites(
            initialQueryParameters: data.queryParameters,
            nodes: routeNodes.pathRouteNodes,
            writeQueryParameters: writeQueryParameters,
          ),
        );
    }
  }

  WorkingRouterData _buildData({
    required IList<RouteNode> routeNodes,
    required IMap<UnboundPathParam<dynamic>, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    assert(routeNodes.pathRouteNodes.isNotEmpty);

    final activeOverlaysByOwner = _activeOverlaysByOwner(
      routeNodes: routeNodes,
      queryParameters: queryParameters,
    );
    final effectiveQueryParameters = _applyOverlayConditions(
      queryParameters,
      activeOverlaysByOwner.values.expand((it) => it),
    );
    final uri = _uriFromRouteNodes(
      routeNodes: routeNodes,
      queryParameters: effectiveQueryParameters,
      pathParameters: pathParameters,
    );

    return WorkingRouterData(
      uri: uri,
      routeNodes: routeNodes,
      activeOverlaysByOwner: activeOverlaysByOwner,
      pathParameters: pathParameters,
      queryParameters: effectiveQueryParameters,
    );
  }

  IMap<RouteNode, IList<AnyOverlay>> _activeOverlaysByOwner({
    required IList<RouteNode> routeNodes,
    required IMap<String, String> queryParameters,
  }) {
    final overlaysByOwner = <RouteNode, IList<AnyOverlay>>{};
    for (final owner in routeNodes) {
      final activeOverlays = <AnyOverlay>[];
      final ownerOverlays = switch (owner) {
        final PathRouteNode pathOwner => pathOwner.pathRouteOverlays,
        _ => const <AnyOverlay>[],
      };
      for (final overlayNode in ownerOverlays) {
        if (!_overlayConditionsMatch(overlayNode.conditions, queryParameters)) {
          continue;
        }
        activeOverlays.add(overlayNode);
      }
      if (activeOverlays.isNotEmpty) {
        overlaysByOwner[owner] = activeOverlays.toIList();
      }
    }
    return overlaysByOwner.toIMap();
  }

  IMap<String, String> _applyOverlayConditions(
    IMap<String, String> queryParameters,
    Iterable<AnyOverlay> overlays,
  ) {
    var result = queryParameters;
    for (final overlay in overlays) {
      for (final condition in overlay.conditions) {
        result = _writeQueryValue(
          result,
          condition.parameter,
          condition.value,
        );
      }
    }
    return result;
  }

  IMap<String, String> _resetOverlayConditions(
    IMap<String, String> queryParameters, {
    required AnyOverlay overlay,
  }) {
    var result = queryParameters;
    for (final condition in overlay.conditions) {
      result = _writeQueryValue(
        result,
        condition.parameter,
        condition.parameter.defaultValue,
      );
    }
    return result;
  }

  IMap<String, String> _writeQueryValue<T>(
    IMap<String, String> queryParameters,
    QueryParam<T> parameter,
    T value,
  ) {
    if (parameter case final DefaultQueryParam<T> defaultParameter) {
      if (defaultParameter.defaultValue == value) {
        return queryParameters.remove(parameter.name);
      }
    }
    return queryParameters.add(parameter.name, parameter.codec.encode(value));
  }

  void addObserver(LocationObserverState observer) {
    _observers.add(observer);
  }

  void removeObserver(LocationObserverState observer) {
    _observers.remove(observer);
  }

  Uri _uriFromRouteNodes({
    required IList<RouteNode> routeNodes,
    required IMap<UnboundPathParam<dynamic>, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    final visibleQueryParameters = _visibleQueryParameters(
      routeNodes: routeNodes,
      queryParameters: queryParameters,
    );
    return Uri(
      path: _visiblePathRouteNodes(routeNodes).buildPath(pathParameters),
      queryParameters: visibleQueryParameters.isEmpty
          ? null
          : visibleQueryParameters.unlock,
    );
  }

  WorkingRouteConfiguration _configurationFromData(WorkingRouterData data) {
    return WorkingRouteConfiguration(
      uri: data.uri,
      hiddenPathSegments: _hiddenPathSegments(
        routeNodes: data.routeNodes,
        pathParameters: data.pathParameters,
      ),
      hiddenQueryParameters: _hiddenQueryParameters(
        routeNodes: data.routeNodes,
        queryParameters: data.queryParameters,
      ),
    );
  }

  Iterable<PathRouteNode> _visiblePathRouteNodes(
    Iterable<RouteNode> routeNodes,
  ) sync* {
    PathRouteNode? hiddenAncestor;

    for (final node in routeNodes) {
      if (node is! PathRouteNode) {
        continue;
      }

      if (hiddenAncestor case final ancestor?
          when !ancestor.containsNode(node)) {
        hiddenAncestor = null;
      }

      final inheritedHidden = hiddenAncestor != null;
      final hidesOwnSubtree = node.pathVisibility == UriVisibility.hidden;
      if (!inheritedHidden && hidesOwnSubtree) {
        hiddenAncestor = node;
      }
      if (!inheritedHidden && !hidesOwnSubtree) {
        yield node;
      }
    }
  }

  IList<String> _hiddenPathSegments({
    required IList<RouteNode> routeNodes,
    required IMap<UnboundPathParam<dynamic>, String> pathParameters,
  }) {
    final allSegments = _buildPathSegments(
      routeNodes.pathRouteNodes,
      pathParameters,
    );
    final visibleSegments = _buildPathSegments(
      _visiblePathRouteNodes(routeNodes),
      pathParameters,
    );
    if (visibleSegments.length >= allSegments.length) {
      return const IListConst([]);
    }
    return allSegments.skip(visibleSegments.length).toIList();
  }

  IList<String> _buildPathSegments(
    Iterable<PathRouteNode> routeNodes,
    IMap<UnboundPathParam<dynamic>, String> pathParameters,
  ) {
    final uriPathSegments = <String>[];
    for (final routeNode in routeNodes) {
      for (final pathSegment in routeNode.path) {
        switch (pathSegment) {
          case LiteralPathSegment():
            uriPathSegments.add(pathSegment.value);
          case PathParam():
            final rawValue = pathParameters[pathSegment.unboundParam];
            if (rawValue == null) {
              throw StateError(
                'Missing value for path parameter `$pathSegment` on '
                '${routeNode.runtimeType}.',
              );
            }
            uriPathSegments.add(rawValue);
        }
      }
    }

    return uriPathSegments.toIList();
  }

  IMap<String, String> _visibleQueryParameters({
    required Iterable<RouteNode> routeNodes,
    required IMap<String, String> queryParameters,
  }) {
    final hiddenNames = _hiddenQueryParameterNames(routeNodes);
    if (hiddenNames.isEmpty) {
      return queryParameters;
    }
    return queryParameters.keepKeys(
      queryParameters.keys.toSet().difference(hiddenNames),
    );
  }

  IMap<String, String> _hiddenQueryParameters({
    required Iterable<RouteNode> routeNodes,
    required IMap<String, String> queryParameters,
  }) {
    final hiddenNames = _hiddenQueryParameterNames(routeNodes);
    if (hiddenNames.isEmpty) {
      return const IMapConst({});
    }
    return queryParameters.keepKeys(hiddenNames);
  }

  Set<String> _hiddenQueryParameterNames(Iterable<RouteNode> routeNodes) {
    final hiddenNames = <String>{};
    final hiddenNamesInheritedByKey = <String>{};

    for (final node in routeNodes) {
      if (node is! PathRouteNode) {
        continue;
      }

      for (final queryParameter in node.queryParameters) {
        if (queryParameter.uriVisibility == UriVisibility.hidden) {
          hiddenNames.add(queryParameter.name);
          hiddenNamesInheritedByKey.add(queryParameter.name);
          continue;
        }

        if (hiddenNamesInheritedByKey.contains(queryParameter.name)) {
          hiddenNames.add(queryParameter.name);
        }
      }
    }

    return hiddenNames;
  }

  IList<RouteNode> _trimNodesToLastMatchingLocation(
    WorkingRouterData data,
    AnyLocation lastRemainingLocation,
  ) {
    final lastRemainingNodeIndex = data.routeNodes.indexWhere(
      (node) => identical(node, lastRemainingLocation),
    );
    return data.routeNodes.take(lastRemainingNodeIndex + 1).toIList();
  }

  Map<UnboundPathParam<dynamic>, String> _resolvePathParameterWrites({
    required Iterable<PathRouteNode> nodes,
    required WritePathParameters? writePathParameters,
  }) {
    if (writePathParameters == null) {
      return const {};
    }

    final resolved = <UnboundPathParam<dynamic>, String>{};
    for (final node in nodes) {
      writePathParameters(
        node,
        <T>(PathParam<T> parameter, T value) {
          final isDeclared = node.path.any(
            (segment) {
              if (segment is! PathParam<dynamic>) {
                return false;
              }
              return identical(segment.unboundParam, parameter.unboundParam);
            },
          );
          if (!isDeclared) {
            throw StateError(
              'The path parameter `$parameter` is not declared by '
              '${node.runtimeType}.',
            );
          }
          resolved[parameter.unboundParam] = parameter.codec.encode(value);
        },
      );
    }
    return resolved;
  }

  IMap<String, String> _mergeQueryParameterWrites({
    required IMap<String, String>? initialQueryParameters,
    required Iterable<PathRouteNode> nodes,
    required WriteQueryParameters? writeQueryParameters,
  }) {
    final currentQueryParameters =
        initialQueryParameters ?? IMap<String, String>();
    final resolved = _resolveQueryParameterWrites(
      nodes,
      writeQueryParameters,
    );
    final withoutDefaultValueWrites = resolved.defaultValueKeys.isEmpty
        ? currentQueryParameters
        : currentQueryParameters.keepKeys(
            currentQueryParameters.keys.toSet().difference(
              resolved.defaultValueKeys,
            ),
          );
    return withoutDefaultValueWrites.addAll(resolved.values.toIMap());
  }

  ({Map<String, String> values, Set<String> defaultValueKeys})
  _resolveQueryParameterWrites(
    Iterable<PathRouteNode> locations,
    WriteQueryParameters? writeQueryParameters,
  ) {
    if (writeQueryParameters == null) {
      return (values: const {}, defaultValueKeys: const <String>{});
    }

    final values = <String, String>{};
    final defaultValueKeys = <String>{};
    for (final node in locations) {
      writeQueryParameters(
        node,
        <T>(QueryParam<T> parameter, T value) {
          final isDeclared = node.queryParameters.any(
            (declaredParameter) => identical(
              declaredParameter.unboundParam,
              parameter.unboundParam,
            ),
          );
          if (!isDeclared) {
            throw StateError(
              'The query parameter `$parameter` is not declared by '
              '${node.runtimeType}.',
            );
          }

          if (parameter case final DefaultQueryParam<T> defaultParameter) {
            if (defaultParameter.defaultValue == value) {
              values.remove(parameter.name);
              defaultValueKeys.add(parameter.name);
              return;
            }
          }

          defaultValueKeys.remove(parameter.name);
          values[parameter.name] = parameter.codec.encode(value);
        },
      );
    }
    return (values: values, defaultValueKeys: defaultValueKeys);
  }

  /// Notifies all location observers after a route change.
  void _notifyObserversAfterRouteChange({
    required IList<AnyLocation>? oldLocations,
    required IList<AnyLocation> newLocations,
  }) {
    if (oldLocations?.isEmpty ?? true) {
      return;
    }

    final observers = _observers.reversed.toList(growable: false);

    // Get observers in reverse order so that the last added one
    // (i.e., the innermost LocationObserver) is called first.
    for (final observer in observers) {
      final context = observer.context;
      if (!context.mounted) {
        continue;
      }
      final observedLocation = NearestLocation.of(context);
      if (oldLocations!.contains(observedLocation)) {
        if (newLocations.contains(observedLocation)) {
          observer.widget.afterUpdate?.call();
        }
      } else {
        if (newLocations.contains(observedLocation)) {
          observer.widget.afterEnter?.call();
        }
      }
    }
  }

  void _updateData(WorkingRouterData data) {
    // ignore: deprecated_member_use_from_same_package
    _data = data;
    _rootDelegate.updateData(data);
    notifyListeners();
  }

  void addNestedDelegate(WorkingRouterDelegate delegate) {
    _nestedDelegates.add(delegate);
  }

  void removeNestedDelegate(WorkingRouterDelegate delegate) {
    _nestedDelegates.remove(delegate);
  }
}

bool _overlayConditionsMatch(
  List<OverlayCondition<dynamic>> conditions,
  IMap<String, String> queryParameters,
) {
  for (final condition in conditions) {
    final rawValue = queryParameters[condition.parameter.name];
    final value = rawValue == null
        ? condition.parameter.defaultValue
        : condition.parameter.codec.decode(rawValue);
    if (value != condition.value) {
      return false;
    }
  }
  return true;
}

class NestedWorkingRouterSailor extends ChangeNotifier
    implements WorkingRouterDataSailor {
  final WorkingRouter router;
  WorkingRouterKey routerKey;

  NestedWorkingRouterSailor({
    required this.router,
    required this.routerKey,
  }) {
    router.addListener(notifyListeners);
  }

  @override
  WorkingRouterData get data => router.data;

  @override
  void routeTo(RouteTarget target) {
    router.routeTo(target);
  }

  @override
  void routeToUriString(String uriString) {
    router.routeToUriString(uriString);
  }

  @override
  void routeToUri(Uri uri) {
    router.routeToUri(uri);
  }

  @override
  void routeToId(
    AnyNodeId id, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  }) {
    router.routeToId(
      id,
      writePathParameters: writePathParameters,
      writeQueryParameters: writeQueryParameters,
    );
  }

  @override
  void routeToChildWhere(
    bool Function(AnyLocation location) predicate, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  }) {
    router.routeToChildWhere(
      predicate,
      writePathParameters: writePathParameters,
      writeQueryParameters: writeQueryParameters,
    );
  }

  @override
  void routeToChild<T>({
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  }) {
    router.routeToChild<T>(
      writePathParameters: writePathParameters,
      writeQueryParameters: writeQueryParameters,
    );
  }

  @override
  void routeBack() {
    router.routeBackInNavigator(routerKey);
  }

  @override
  void routeBackFrom(AnyLocation fromLocation) {
    router.routeBackFrom(fromLocation);
  }

  @override
  void routeBackUntil(bool Function(AnyLocation location) match) {
    router.routeBackUntil(match);
  }

  @override
  void dispose() {
    router.removeListener(notifyListeners);
    super.dispose();
  }
}

/// A synchronous callback that decides how to handle a route transition.
///
/// Keep this callback fast and side-effect free.
typedef TransitionDecider =
    TransitionDecision Function(
      WorkingRouter router,
      RouteTransition transition,
    );
