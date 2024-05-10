import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import '../working_router.dart';

typedef BeforeRouting<ID> = Future<bool> Function(
  WorkingRouter<ID> router,
  WorkingRouterData<ID>? oldData,
  WorkingRouterData<ID> newData,
);

class WorkingRouter<ID>
    implements RouterConfig<Uri>, WorkingRouterDataSailor<ID> {
  static WorkingRouterDataProvider<ID> of<ID>(BuildContext context) {
    final WorkingRouterDataProvider<ID>? dataProvider = context
        .dependOnInheritedWidgetOfExactType<WorkingRouterDataProvider<ID>>();
    return dataProvider!;
  }

  late final WorkingRouterDelegate<ID> _rootDelegate;
  final WorkingRouteInformationParser _informationParser =
      WorkingRouteInformationParser();
  final RouteInformationProvider _informationProvider =
      PlatformRouteInformationProvider(
    initialRouteInformation: RouteInformation(
      location: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    ),
  );

  Location<ID> _locationTree;
  final List<LocationGuardState> _guards = [];
  final List<WorkingRouterDelegate<ID>> _nestedDelegates = [];

  @Deprecated(
    "Don't use this property directly. "
    "Get is using the data getter. Set it using _updateData.",
  )
  WorkingRouterData<ID>? _data;

  /// oldData is null when the route from the OS is set for the first
  /// time at router start up.
  final BeforeRouting<ID>? _beforeRouting;
  final Location<ID> Function() buildLocationTree;

  WorkingRouter({
    required this.buildLocationTree,
    required BuildPages<ID> buildRootPages,
    required Widget noContentWidget,
    Widget Function(BuildContext context, Widget child)? wrapNavigator,
    BeforeRouting<ID>? beforeRouting,
  })  : _locationTree = buildLocationTree(),
        _beforeRouting = beforeRouting {
    _rootDelegate = WorkingRouterDelegate<ID>(
      debugLabel: "root",
      isRootDelegate: true,
      router: this,
      buildPages: buildRootPages,
      noContentWidget: noContentWidget,
      wrapNavigator: wrapNavigator,
    );
  }

  /// This is mainly provided so that [WorkingRouter] can implement
  /// [WorkingRouterDataSailor]. In almost all other cases [nullableData]
  /// should be used.
  @override
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
    [_rootDelegate, ..._nestedDelegates].forEach((it) => it.refresh());
  }

  @override
  Future<void> routeToUriString(
    String uriString, {
    bool isRedirect = false,
  }) async {
    await routeToUri(Uri.parse(uriString), isRedirect: isRedirect);
  }

  @override
  Future<void> routeToUri(
    Uri uri, {
    bool isRedirect = false,
  }) async {
    final matchResult = _locationTree.match(uri.pathSegments.toIList());
    final matches = matchResult.$1;
    final pathParameters = matchResult.$2;

    await _routeTo(
      locations: matches,
      fallback: uri,
      pathParameters: pathParameters,
      queryParameters: uri.queryParameters.toIMap(),
      isRedirect: isRedirect,
    );
  }

  @override
  Future<void> routeToId(
    ID id, {
    IMap<String, String> pathParameters = const IMapConst({}),
    IMap<String, String> queryParameters = const IMapConst({}),
    bool isRedirect = false,
  }) async {
    final matches = _locationTree.matchId(id);
    await _routeTo(
      locations: matches,
      fallback: null,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      isRedirect: isRedirect,
    );
  }

  @override
  Future<void> routeToRelative(
    bool Function(Location<ID> location) match, {
    IMap<String, String> pathParameters = const IMapConst({}),
    IMap<String, String> queryParameters = const IMapConst({}),
    bool isRedirect = false,
  }) async {
    final relativeMatches = nullableData!.locations.last.matchRelative(match);
    if (relativeMatches.isEmpty) {
      return;
    }

    await _routeTo(
      locations: nullableData!.locations.addAll(relativeMatches),
      fallback: null,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      isRedirect: isRedirect,
    );
  }

  @override
  Future<void> popUntil(bool Function(Location<ID> location) match) async {
    final reversedLocations = nullableData!.locations.reversed;
    final index = reversedLocations.indexWhere(match);
    if (index == -1) {
      return;
    }

    final newLocations = reversedLocations.removeRange(0, index).reversed;
    final newActiveLocation = newLocations.last;
    await _routeTo(
      locations: newLocations,
      fallback: null,
      pathParameters:
          newActiveLocation.selectPathParameters(nullableData!.pathParameters),
      queryParameters: newActiveLocation
          .selectQueryParameters(nullableData!.queryParameters),
      isRedirect: false,
    );
  }

  Future<void> _routeTo({
    required IList<Location<ID>> locations,
    required Uri? fallback,
    required IMap<String, String> pathParameters,
    required IMap<String, String> queryParameters,
    required bool isRedirect,
  }) async {
    assert(
      locations.isNotEmpty || (fallback != null),
      "Fallback must not be null when locations are empty.",
    );

    final newData = WorkingRouterData(
      // Set the uri to fallback when locations are empty.
      // When locations are empty, then not found should be shown, but
      // the path in the browser URL bar should stay at the not found path value
      // entered by the user.
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

    if (!isRedirect) {
      if (!(await _beforeRouting?.call(this, nullableData, newData) ?? true)) {
        return;
      }

      if (await _guardBeforeLeave(locations)) {
        return;
      }
    }

    final oldLocations = nullableData?.locations;
    _updateData(newData);

    if (!isRedirect) {
      // We need to do this after rebuild as completed so that the user
      // can have access to the new router data.
      WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((_) {
        _guardAfter(oldLocations: oldLocations, newLocations: locations);
      });
    }
  }

  Future<void> pop() async {
    final newLocations = nullableData!.locations.removeLast();
    final newPathParameters =
        newLocations.last.selectPathParameters(nullableData!.pathParameters);
    final newQueryParameters =
        newLocations.last.selectQueryParameters(nullableData!.queryParameters);

    await _routeTo(
      locations: newLocations,
      fallback: null,
      queryParameters: newQueryParameters,
      pathParameters: newPathParameters,
      isRedirect: false,
    );
  }

  void addGuard(LocationGuardState guard) {
    _guards.add(guard);
  }

  void removeGuard(LocationGuardState guard) {
    _guards.remove(guard);
  }

  Uri _uriFromLocations({
    required IList<Location<ID>> locations,
    required IMap<String, String> pathParameters,
    required IMap<String, String> queryParameters,
  }) {
    return Uri(
      // Need to build the path by hand and can not use pathSegments,
      // because pathSegments does not add a leading slash. However in order
      // to be consistent with the information parser and to have a proper
      // representation for the root "/" a leading slash has to be added.
      path: "/" +
          locations
              .map((location) => location.pathSegments)
              .flattened
              .map((pathSegment) {
            if (pathSegment.startsWith(":")) {
              return pathParameters[pathSegment.replaceRange(0, 1, "")]!;
            }
            return pathSegment;
          }).join("/"),
      queryParameters: queryParameters.isEmpty ? null : queryParameters.unlock,
    );
  }

  /// Handles all guards starting with "after".
  void _guardAfter({
    required IList<Location<ID>>? oldLocations,
    required IList<Location<ID>> newLocations,
  }) {
    if (oldLocations?.isEmpty ?? true) {
      return;
    }
    for (final guard in _guards) {
      final guardedLocation = NearestLocation.of<ID>(guard.context);
      if (oldLocations!.contains(guardedLocation)) {
        if (newLocations.contains(guardedLocation)) {
          guard.widget.afterUpdate?.call();
        }
      } else {
        if (newLocations.contains(guardedLocation)) {
          guard.widget.afterEnter?.call();
        }
      }
    }
  }

  Future<bool> _guardBeforeLeave(IList<Location<ID>> newLocations) async {
    for (final guard in _guards) {
      final currentLocations = nullableData!.locations;
      final guardedLocation = NearestLocation.of<ID>(guard.context);

      // beforeLeave
      if (currentLocations.contains(guardedLocation) &&
          !newLocations.contains(guardedLocation)) {
        if (!(await guard.widget.beforeLeave?.call() ?? true)) {
          return true;
        }
      }
    }
    return false;
  }

  void _updateData(WorkingRouterData<ID> data) {
    // ignore: deprecated_member_use_from_same_package
    _data = data;
    _rootDelegate.updateData(data);
  }

  void addNestedDelegate(WorkingRouterDelegate<ID> delegate) {
    _nestedDelegates.add(delegate);
  }

  void removeNestedDelegate(WorkingRouterDelegate<ID> delegate) {
    _nestedDelegates.remove(delegate);
  }
}
