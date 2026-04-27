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
    implements RouterConfig<Uri>, WorkingRouterDataSailor {
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

  Uri? get nullableConfiguration => nullableData?.uri;

  @override
  BackButtonDispatcher? get backButtonDispatcher => RootBackButtonDispatcher();

  @override
  RouteInformationParser<Uri>? get routeInformationParser => _informationParser;

  @override
  RouteInformationProvider? get routeInformationProvider {
    return _informationProvider;
  }

  @override
  RouterDelegate<Uri> get routerDelegate => _rootDelegate;

  @internal
  GlobalKey<NavigatorState> get rootNavigatorKey => _rootDelegate.navigatorKey;

  @internal
  WorkingRouterKey get rootRouterKey => _rootRouterKey;

  /// Rebuilds the route node tree for this router instance.
  void refresh() {
    _routeNodeTree = _buildRouteNodeTree();
    final currentData = nullableData;
    if (currentData != null) {
      // Delegate refresh only rebuilds pages from the current router data.
      // After the tree changes, rematch the current uri so stale active
      // locations are dropped when that route no longer exists.
      _updateData(_buildDataForUri(currentData.uri));
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
  void routeToUriFromRouteInformation(Uri uri) {
    _routeTo(
      targetData: _buildDataForUri(uri),
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
  void slideIn(AnyNodeId id) {
    final idMatches = _routeNodeTree.matchId(id);
    final targetLocation = idMatches.locations.lastOrNull;
    final currentLocation = nullableData?.leaf;
    if (targetLocation == null || currentLocation == null) {
      return;
    }

    final relativeMatchNodes = targetLocation.matchRelative(
      (location) => location.runtimeType == currentLocation.runtimeType,
    );

    _routeTo(
      targetData: _buildData(
        routeNodes: idMatches.addAll(relativeMatchNodes),
        fallback: null,
        pathParameters: nullableData!.pathParametersForRouter,
        queryParameters: nullableData!.queryParameters,
      ),
      reason: RouteTransitionReason.programmatic,
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
    final location = _rootDelegate.lastLocationForRouterKey(data, routerKey);
    if (location == null) {
      routeBack();
      return;
    }

    final locationIndex = data.routeNodes.indexWhere(
      (node) => identical(node, location),
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
    final newPathParameters = data.pathParametersForRouter.keepKeys({
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
    final newQueryParameters = _resetRemovedQueryFilters(
      retainedQueryParameters,
      oldRouteNodes: data.routeNodes,
      newRouteNodes: newNodes,
    );

    _routeTo(
      targetData: _buildData(
        routeNodes: newNodes,
        fallback: null,
        pathParameters: newPathParameters,
        queryParameters: newQueryParameters,
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
    final newPathParameters = data.pathParametersForRouter.keepKeys({
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
    final newQueryParameters = _resetRemovedQueryFilters(
      retainedQueryParameters,
      oldRouteNodes: data.routeNodes,
      newRouteNodes: newNodes,
    );

    _routeTo(
      targetData: _buildData(
        routeNodes: newNodes,
        fallback: null,
        pathParameters: newPathParameters,
        queryParameters: newQueryParameters,
      ),
      reason: RouteTransitionReason.programmatic,
    );
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
    return _buildData(
      routeNodes: matchResult.routeNodes,
      fallback: matchResult.isEmpty ? uri : null,
      pathParameters: matchResult.pathParameters,
      queryParameters: queryParameters,
    );
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
          fallback: null,
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
        final routeNodes = _mergeQueryFilterChildTarget(
          currentRouteNodes: data.routeNodes,
          startIndex: startIndex,
          matchedNodes: matchedNodes,
        );

        return _buildData(
          routeNodes: routeNodes,
          fallback: null,
          pathParameters: data.pathParametersForRouter.addAll(
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
          fallback: null,
          pathParameters: data.pathParametersForRouter.addAll(
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

  IList<RouteNode> _mergeQueryFilterChildTarget({
    required IList<RouteNode> currentRouteNodes,
    required int startIndex,
    required IList<RouteNode> matchedNodes,
  }) {
    final targetRouteNodes = currentRouteNodes
        .take(startIndex + 1)
        .toIList()
        .addAll(matchedNodes);
    if (!matchedNodes.every(_isPathlessQueryFilterNode)) {
      return targetRouteNodes;
    }
    final retainedDescendants = currentRouteNodes
        .skip(startIndex + 1)
        .where((node) => !matchedNodes.any((target) => identical(target, node)))
        .toIList();
    return targetRouteNodes.addAll(retainedDescendants);
  }

  bool _isPathlessQueryFilterNode(RouteNode node) {
    return node is PathRouteNode &&
        node.path.isEmpty &&
        node.queryFilters.isNotEmpty;
  }

  WorkingRouterData _buildData({
    required IList<RouteNode> routeNodes,
    required Uri? fallback,
    required IMap<UnboundPathParam<dynamic>, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    final pathRouteNodes = routeNodes.pathRouteNodes;
    assert(
      pathRouteNodes.isNotEmpty || (fallback != null),
      'Fallback must not be null when locations are empty.',
    );

    final filteredQueryParameters = _applyQueryFilters(
      queryParameters,
      routeNodes,
    );
    final uri =
        fallback ??
        _uriFromRouteNodes(
          routeNodes: routeNodes,
          queryParameters: filteredQueryParameters,
          pathParameters: pathParameters,
        );

    return WorkingRouterData(
      uri: uri,
      routeNodes: routeNodes,
      pathParameters: pathRouteNodes.isEmpty
          ? const IMapConst({})
          : pathParameters,
      queryParameters: pathRouteNodes.isEmpty
          ? fallback!.queryParameters.toIMap()
          : filteredQueryParameters,
    );
  }

  IMap<String, String> _applyQueryFilters(
    IMap<String, String> queryParameters,
    IList<RouteNode> routeNodes,
  ) {
    var result = queryParameters;
    for (final filter in routeNodes.pathRouteNodes.expand(
      (node) => node.queryFilters,
    )) {
      result = _writeQueryValue(
        result,
        filter.parameter,
        filter.value,
      );
    }
    return result;
  }

  IMap<String, String> _resetRemovedQueryFilters(
    IMap<String, String> queryParameters, {
    required IList<RouteNode> oldRouteNodes,
    required IList<RouteNode> newRouteNodes,
  }) {
    final activeFilters = newRouteNodes.pathRouteNodes
        .expand((node) => node.queryFilters)
        .toList(growable: false);
    var result = queryParameters;
    for (final removedFilter
        in oldRouteNodes.pathRouteNodes
            .where((node) => !newRouteNodes.any((it) => identical(it, node)))
            .expand((node) => node.queryFilters)) {
      final isStillActive = activeFilters.any(
        (filter) => identical(
          filter.parameter.unboundParam,
          removedFilter.parameter.unboundParam,
        ),
      );
      if (isStillActive) {
        continue;
      }
      result = _writeQueryValue(
        result,
        removedFilter.parameter,
        removedFilter.parameter.defaultValue.value,
      );
    }
    return result;
  }

  IMap<String, String> _writeQueryValue<T>(
    IMap<String, String> queryParameters,
    QueryParam<T> parameter,
    T value,
  ) {
    if (parameter.defaultValue case final defaultValue?
        when defaultValue.value == value) {
      return queryParameters.remove(parameter.name);
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
    return Uri(
      path: routeNodes.visiblePathRouteNodes().buildPath(pathParameters),
      queryParameters: queryParameters.isEmpty ? null : queryParameters.unlock,
    );
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

          if (parameter.defaultValue case final defaultValue?
              when defaultValue.value == value) {
            values.remove(parameter.name);
            defaultValueKeys.add(parameter.name);
            return;
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
  void slideIn(AnyNodeId id) {
    router.slideIn(id);
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
