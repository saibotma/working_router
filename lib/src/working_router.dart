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
typedef BuildRouteNodes<ID extends Enum> =
    List<RouteNode<ID>> Function(WorkingRouterKey rootRouterKey);

class WorkingRouter<ID extends Enum> extends ChangeNotifier
    implements RouterConfig<Uri>, WorkingRouterDataSailor<ID> {
  /// Does not notify widgets at all.
  /// This is meant to be used for one off calls to the router,
  /// and not rebuilding a widget based router data changes.
  /// Use [WorkingRouterData.of] for this instead.
  static WorkingRouterDataSailor<ID> of<ID extends Enum>(
    BuildContext context,
  ) {
    final inheritedWidget = context
        .dependOnInheritedWidgetOfExactType<InheritedWorkingRouter<ID>>();
    return inheritedWidget!.sailor;
  }

  late final WorkingRouterDelegate<ID> _rootDelegate;
  final WorkingRouteInformationParser _informationParser =
      WorkingRouteInformationParser();
  final RouteInformationProvider _informationProvider =
      PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(
          // ignore: deprecated_member_use
          location: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
        ),
      );
  final GlobalKey<NavigatorState> _rootNavigatorKey;
  final WorkingRouterKey _rootRouterKey = WorkingRouterKey();

  late IList<RouteNode<ID>> _routeNodeTree;
  final List<LocationObserverState> _observers = [];
  final List<WorkingRouterDelegate<ID>> _nestedDelegates = [];

  /// Counter to track routing requests and prevent race conditions.
  /// Each routing request captures this value at start; if a newer request
  /// starts before async `beforeLeave` checks complete, older requests
  /// are discarded.
  int _routingVersion = 0;

  @Deprecated(
    "Don't use this property directly. "
    "Get is using the data getter. Set it using _updateData.",
  )
  WorkingRouterData<ID>? _data;

  final TransitionDecider<ID>? _decideTransition;
  final int _redirectLimit;

  /// Rebuilds the routing tree used by this router instance.
  ///
  /// The callback receives the stable root [WorkingRouterKey] so callers can
  /// explicitly thread it into locations that need to target the root router.
  ///
  /// When using `@RouteNodes`, pass a closure here that builds the same route
  /// tree shape as the annotated generator entrypoint.
  final BuildRouteNodes<ID> buildRouteNodes;
  final LocationChildWrapper<ID>? wrapLocationChild;

  WorkingRouter({
    required this.buildRouteNodes,
    BuildPages<ID>? buildRootPages,
    required Widget noContentWidget,
    Widget Function(BuildContext context, Widget child)? wrapNavigator,
    this.wrapLocationChild,
    TransitionDecider<ID>? decideTransition,
    int redirectLimit = 5,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : assert(redirectLimit > 0, 'redirectLimit must be greater than 0.'),
       _rootNavigatorKey =
           navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root'),
       _decideTransition = decideTransition,
       _redirectLimit = redirectLimit {
    _routeNodeTree = _buildRouteNodeTree();
    _rootDelegate = WorkingRouterDelegate<ID>(
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
  WorkingRouterData<ID> get data => _data!;

  // ignore: deprecated_member_use_from_same_package
  WorkingRouterData<ID>? get nullableData => _data;

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

  IList<RouteNode<ID>> _buildRouteNodeTree() {
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
  void routeTo(RouteTarget<ID> target) {
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
    _routeToUri(uri, reason: RouteTransitionReason.routeInformation);
  }

  void _routeToUri(Uri uri, {required RouteTransitionReason reason}) {
    final targetData = _buildDataForUri(uri);
    _routeTo(
      targetData: targetData,
      reason: reason,
    );
  }

  @override
  void routeToId(
    ID id, {
    Map<String, String> queryParameters = const {},
    WritePathParameters<ID>? writePathParameters,
  }) {
    routeTo(
      IdRouteTarget(
        id,
        queryParameters: queryParameters,
        writePathParameters: writePathParameters,
      ),
    );
  }

  @override
  void slideIn(ID id) {
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
    bool Function(AnyLocation<ID> location) predicate, {
    Map<String, String> queryParameters = const {},
    WritePathParameters<ID>? writePathParameters,
  }) {
    routeTo(
      FirstChildRouteTarget(
        predicate,
        queryParameters: queryParameters,
        writePathParameters: writePathParameters,
      ),
    );
  }

  @override
  void routeToChild<T>({
    Map<String, String> queryParameters = const {},
    WritePathParameters<ID>? writePathParameters,
  }) {
    routeToChildWhere(
      (it) => it is T,
      queryParameters: queryParameters,
      writePathParameters: writePathParameters,
    );
  }

  @override
  void routeBack() {
    _routeBackUntil((it) => !it.shouldBeSkippedOnRouteBack);
  }

  @override
  void routeBackFrom(AnyLocation<ID> fromLocation) {
    _routeBackUntil(
      (it) => !it.shouldBeSkippedOnRouteBack,
      fromLocation: fromLocation,
    );
  }

  @override
  void routeBackUntil(bool Function(AnyLocation<ID> location) match) {
    _routeBackUntil(match);
  }

  void _routeBackUntil(
    bool Function(AnyLocation<ID> location) match, {
    AnyLocation<ID>? fromLocation,
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

    final newQueryParameters = data.queryParameters.keepKeys(
      newPathRouteNodes
          .expand((element) => element.queryParameters.map((it) => it.name))
          .toSet(),
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
    required IList<AnyLocation<ID>> locations,
    required AnyLocation<ID> fromLocation,
  }) {
    for (var i = locations.length - 1; i >= 0; i--) {
      if (identical(locations[i], fromLocation)) {
        return i - 1;
      }
    }
    return -1;
  }

  void _routeTo({
    required WorkingRouterData<ID> targetData,
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

  Future<void> _guardBeforeLeave({
    required int routingVersion,
    required IList<AnyLocation<ID>> newLocations,
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

      final observedLocation = NearestLocation.of<ID>(context);
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

  WorkingRouterData<ID>? _resolveTransitionDecision({
    required WorkingRouterData<ID>? oldData,
    required WorkingRouterData<ID> initialData,
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

  WorkingRouterData<ID> _buildDataForUri(Uri uri) {
    final matchResult = _routeNodeTree.match(uri.pathSegments.toIList());
    return _buildData(
      routeNodes: matchResult.routeNodes,
      fallback: uri,
      pathParameters: matchResult.pathParameters,
      queryParameters: uri.queryParameters.toIMap(),
    );
  }

  WorkingRouterData<ID> _buildDataForTarget(
    RouteTarget<ID> target, {
    required WorkingRouterData<ID>? currentData,
    bool retainSharedQueryParameters = true,
  }) {
    switch (target) {
      case UriRouteTarget(:final uri):
        return _buildDataForUri(uri);
      case IdRouteTarget(
        :final id,
        :final queryParameters,
        :final writePathParameters,
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
        final keptQueryParameterKeys =
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

        return _buildData(
          routeNodes: matchedNodes,
          fallback: null,
          pathParameters: _resolvePathParameterWrites(
            matchedPathRouteNodes,
            writePathParameters,
          ).toIMap(),
          queryParameters:
              ((retainSharedQueryParameters
                          ? currentData?.queryParameters.keepKeys(
                              keptQueryParameterKeys,
                            )
                          : null) ??
                      IMap<String, String>())
                  .addAll(queryParameters.toIMap()),
        );
      case ChildRouteTarget(
        :final start,
        :final resolveChildPathNodes,
        :final queryParameters,
        :final writePathParameters,
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
        final routeNodes = data.routeNodes.take(startIndex + 1).toIList().addAll(
          matchedNodes,
        );

        return _buildData(
          routeNodes: routeNodes,
          fallback: null,
          pathParameters: data.pathParametersForRouter.addAll(
            _resolvePathParameterWrites(
              routeNodes.pathRouteNodes,
              writePathParameters,
            ).toIMap(),
          ),
          queryParameters: data.queryParameters.addAll(
            queryParameters.toIMap(),
          ),
        );
      case FirstChildRouteTarget(
        :final predicate,
        :final queryParameters,
        :final writePathParameters,
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
              routeNodes.pathRouteNodes,
              writePathParameters,
            ).toIMap(),
          ),
          queryParameters: data.queryParameters.addAll(
            queryParameters.toIMap(),
          ),
        );
    }
  }

  WorkingRouterData<ID> _buildData({
    required IList<RouteNode<ID>> routeNodes,
    required Uri? fallback,
    required IMap<UnboundPathParam<dynamic>, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    final pathRouteNodes = routeNodes.pathRouteNodes;
    assert(
      pathRouteNodes.isNotEmpty || (fallback != null),
      'Fallback must not be null when locations are empty.',
    );

    return WorkingRouterData(
      uri:
          fallback ??
          _uriFromLocations(
            locations: pathRouteNodes,
            queryParameters: queryParameters,
            pathParameters: pathParameters,
          ),
      routeNodes: routeNodes,
      pathParameters: pathRouteNodes.isEmpty
          ? const IMapConst({})
          : pathParameters,
      queryParameters: pathRouteNodes.isEmpty
          ? fallback!.queryParameters.toIMap()
          : queryParameters,
    );
  }

  void addObserver(LocationObserverState observer) {
    _observers.add(observer);
  }

  void removeObserver(LocationObserverState observer) {
    _observers.remove(observer);
  }

  Uri _uriFromLocations({
    required IList<PathRouteNode<ID>> locations,
    required IMap<UnboundPathParam<dynamic>, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    return Uri(
      path: locations.buildPath(pathParameters),
      queryParameters: queryParameters.isEmpty ? null : queryParameters.unlock,
    );
  }

  IList<RouteNode<ID>> _trimNodesToLastMatchingLocation(
    WorkingRouterData<ID> data,
    AnyLocation<ID> lastRemainingLocation,
  ) {
    final lastRemainingNodeIndex = data.routeNodes.indexWhere(
      (node) => identical(node, lastRemainingLocation),
    );
    return data.routeNodes.take(lastRemainingNodeIndex + 1).toIList();
  }

  Map<UnboundPathParam<dynamic>, String> _resolvePathParameterWrites(
    Iterable<PathRouteNode<ID>> locations,
    WritePathParameters<ID>? writePathParameters,
  ) {
    if (writePathParameters == null) {
      return const {};
    }

    final resolved = <UnboundPathParam<dynamic>, String>{};
    for (final location in locations) {
      writePathParameters(
        location,
        <T>(PathParam<T> parameter, T value) {
          final isDeclared = location.path.any(
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
              '${location.runtimeType}.',
            );
          }
          resolved[parameter.unboundParam] = parameter.codec.encode(value);
        },
      );
    }
    return resolved;
  }

  /// Notifies all location observers after a route change.
  void _notifyObserversAfterRouteChange({
    required IList<AnyLocation<ID>>? oldLocations,
    required IList<AnyLocation<ID>> newLocations,
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
      final observedLocation = NearestLocation.of<ID>(context);
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

  void _updateData(WorkingRouterData<ID> data) {
    // ignore: deprecated_member_use_from_same_package
    _data = data;
    _rootDelegate.updateData(data);
    notifyListeners();
  }

  void addNestedDelegate(WorkingRouterDelegate<ID> delegate) {
    _nestedDelegates.add(delegate);
  }

  void removeNestedDelegate(WorkingRouterDelegate<ID> delegate) {
    _nestedDelegates.remove(delegate);
  }
}

/// A synchronous callback that decides how to handle a route transition.
///
/// Keep this callback fast and side-effect free.
typedef TransitionDecider<ID extends Enum> =
    TransitionDecision<ID> Function(
      WorkingRouter<ID> router,
      RouteTransition<ID> transition,
    );
