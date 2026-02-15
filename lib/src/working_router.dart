import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:working_router/src/inherited_working_router.dart';
import 'package:working_router/working_router.dart';

class WorkingRouter<ID> extends ChangeNotifier
    implements RouterConfig<Uri>, WorkingRouterDataSailor<ID> {
  /// Does not notify widgets at all.
  /// This is meant to be used for one off calls to the router,
  /// and not rebuilding a widget based router data changes.
  /// Use [WorkingRouterData.of] for this instead.
  static WorkingRouterDataSailor<ID> of<ID>(BuildContext context) {
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

  Location<ID> _locationTree;
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
  final Location<ID> Function() buildLocationTree;

  WorkingRouter({
    required this.buildLocationTree,
    required BuildPages<ID> buildRootPages,
    required Widget noContentWidget,
    Widget Function(BuildContext context, Widget child)? wrapNavigator,
    TransitionDecider<ID>? decideTransition,
    int redirectLimit = 5,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : assert(redirectLimit > 0, 'redirectLimit must be greater than 0.'),
       _locationTree = buildLocationTree(),
       _decideTransition = decideTransition,
       _redirectLimit = redirectLimit {
    _rootDelegate = WorkingRouterDelegate<ID>(
      debugLabel: "root",
      isRootDelegate: true,
      router: this,
      buildPages: buildRootPages,
      noContentWidget: noContentWidget,
      wrapNavigator: wrapNavigator,
      navigatorKey: navigatorKey,
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

  void refresh() {
    _locationTree = buildLocationTree();
    for (final it in [_rootDelegate, ..._nestedDelegates]) {
      it.refresh();
    }
  }

  @override
  void routeToUriString(String uriString) {
    _routeToUri(
      Uri.parse(uriString),
      reason: RouteTransitionReason.programmatic,
    );
  }

  @override
  void routeToUri(Uri uri) {
    _routeToUri(uri, reason: RouteTransitionReason.programmatic);
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
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    final matches = _locationTree.matchId(id);
    _routeTo(
      targetData: _buildData(
        locations: matches,
        fallback: null,
        pathParameters: pathParameters.toIMap(),
        queryParameters: queryParameters.toIMap(),
      ),
      reason: RouteTransitionReason.programmatic,
    );
  }

  @override
  void slideIn(ID id) {
    final idMatches = _locationTree.matchId(id);
    final relativeMatches = idMatches.last.matchRelative(
      (location) =>
          location.runtimeType == nullableData!.locations.last.runtimeType,
    );

    _routeTo(
      targetData: _buildData(
        locations: idMatches.addAll(relativeMatches),
        fallback: null,
        pathParameters: nullableData!.pathParameters,
        queryParameters: nullableData!.queryParameters,
      ),
      reason: RouteTransitionReason.programmatic,
    );
  }

  @override
  void routeToChildWhere(
    bool Function(Location<ID> location) predicate, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    final data = nullableData!;
    final matches = data.locations.last.matchRelative(predicate);
    if (matches.isEmpty) {
      return;
    }

    _routeTo(
      targetData: _buildData(
        locations: data.locations.addAll(matches),
        fallback: null,
        pathParameters: data.pathParameters.addAll(pathParameters.toIMap()),
        queryParameters: data.queryParameters.addAll(queryParameters.toIMap()),
      ),
      reason: RouteTransitionReason.programmatic,
    );
  }

  @override
  void routeToChild<T>({
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    routeToChildWhere(
      (it) => it is T,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  @override
  void routeBack() {
    _routeBackUntil((it) => !it.shouldBeSkippedOnRouteBack);
  }

  @override
  void routeBackUntil(bool Function(Location<ID> location) match) {
    _routeBackUntil(match);
  }

  void _routeBackUntil(bool Function(Location<ID> location) match) {
    final data = nullableData!;
    final locations = data.locations;
    if (locations.length <= 1) {
      // Nothing to go back to
      return;
    }

    // Start from the *previous* location (skip the current/last one).
    int matchIndex = -1;
    for (var i = locations.length - 2; i >= 0; i--) {
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
    final newActiveLocation = newLocations.last;

    final newPathParameters = data.pathParameters.keepKeys(
      newLocations
          .expand((location) => location.pathSegments)
          .map(_findPathParameterKeyInPathSegment)
          .nonNulls
          .toSet(),
    );

    _routeTo(
      targetData: _buildData(
        locations: newLocations,
        fallback: null,
        pathParameters: newPathParameters,
        queryParameters: newActiveLocation.selectQueryParameters(
          data.queryParameters,
        ),
      ),
      reason: RouteTransitionReason.programmatic,
    );
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
        newLocations: resolvedData.locations,
        onAllowed: () {
          final oldLocations = oldData?.locations;
          _updateData(resolvedData);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notifyObserversAfterRouteChange(
              oldLocations: oldLocations,
              newLocations: resolvedData.locations,
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
    required IList<Location<ID>> newLocations,
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

      final currentLocations = nullableData?.locations;
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
          redirects += 1;
          if (redirects > _redirectLimit) {
            throw StateError(
              'Redirect limit of $_redirectLimit exceeded while resolving '
              'transition to ${initialData.uri}.',
            );
          }
          switch (to) {
            case RedirectToUri(:final uri):
              currentData = _buildDataForUri(uri);
            case RedirectToId(
              :final id,
              :final pathParameters,
              :final queryParameters,
            ):
              currentData = _buildData(
                locations: _locationTree.matchId(id),
                fallback: null,
                pathParameters: pathParameters.toIMap(),
                queryParameters: queryParameters.toIMap(),
              );
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
    final matchResult = _locationTree.match(uri.pathSegments.toIList());
    final matches = matchResult.$1;
    final pathParameters = matchResult.$2;
    return _buildData(
      locations: matches,
      fallback: uri,
      pathParameters: pathParameters,
      queryParameters: uri.queryParameters.toIMap(),
    );
  }

  WorkingRouterData<ID> _buildData({
    required IList<Location<ID>> locations,
    required Uri? fallback,
    required IMap<String, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    assert(
      locations.isNotEmpty || (fallback != null),
      'Fallback must not be null when locations are empty.',
    );

    return WorkingRouterData(
      uri: locations.isEmpty
          ? fallback!
          : _uriFromLocations(
              locations: locations,
              queryParameters: queryParameters,
              pathParameters: pathParameters,
            ),
      locations: locations,
      pathParameters: locations.isEmpty ? const IMapConst({}) : pathParameters,
      queryParameters: locations.isEmpty
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
    required IList<Location<ID>> locations,
    required IMap<String, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    return Uri(
      path: locations.buildPath(pathParameters),
      queryParameters: queryParameters.isEmpty ? null : queryParameters.unlock,
    );
  }

  /// Notifies all location observers after a route change.
  void _notifyObserversAfterRouteChange({
    required IList<Location<ID>>? oldLocations,
    required IList<Location<ID>> newLocations,
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
typedef TransitionDecider<ID> =
    TransitionDecision<ID> Function(
      WorkingRouter<ID> router,
      RouteTransition<ID> transition,
    );

String? _findPathParameterKeyInPathSegment(String pathSegment) {
  if (pathSegment.startsWith(':')) {
    return pathSegment.replaceRange(0, 1, '');
  }
  return null;
}
