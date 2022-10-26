import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import '../working_router.dart';

typedef BeforeRouting<ID> = Future<bool> Function(
  WorkingRouter<ID> router,
  WorkingRouterData<ID>? oldData,
  WorkingRouterData<ID> newData,
);

class WorkingRouter<ID> implements RouterConfig<Uri>, WorkingRouterSailor<ID> {
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

  final Location<ID> _locationTree;
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

  WorkingRouter({
    required Location<ID> locationTree,
    required BuildPages<ID> buildRootPages,
    required Widget noContentWidget,
    Widget Function(BuildContext context, Widget child)? wrapNavigator,
    BeforeRouting<ID>? beforeRouting,
  })  : _locationTree = locationTree,
        _beforeRouting = beforeRouting {
    _rootDelegate = WorkingRouterDelegate<ID>(
      isRootDelegate: true,
      router: this,
      buildPages: buildRootPages,
      noContentWidget: noContentWidget,
      wrapNavigator: wrapNavigator,
    );
  }

  // ignore: deprecated_member_use_from_same_package
  WorkingRouterData<ID>? get data => _data;

  @override
  BackButtonDispatcher? get backButtonDispatcher => null;

  @override
  RouteInformationParser<Uri>? get routeInformationParser => _informationParser;

  @override
  RouteInformationProvider? get routeInformationProvider {
    return _informationProvider;
  }

  @override
  RouterDelegate<Uri> get routerDelegate => _rootDelegate;

  void refresh() {
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
    final matches = matchResult.first;
    final pathParameters = matchResult.second;

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
    final relativeMatches = data!.locations.last.matchRelative(match);
    if (relativeMatches.isEmpty) {
      return;
    }

    await _routeTo(
      locations: data!.locations.addAll(relativeMatches),
      fallback: null,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      isRedirect: isRedirect,
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
      if (!(await _beforeRouting?.call(this, data, newData) ?? true)) {
        return;
      }

      if (await _guard(locations)) {
        return;
      }
    }

    _updateData(newData);
  }

  Future<void> pop() async {
    final newLocations = data!.locations.removeLast();
    final newPathParameters =
        newLocations.last.selectPathParameters(data!.pathParameters);
    final newQueryParameters =
        newLocations.last.selectQueryParameters(data!.queryParameters);

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
      pathSegments: locations
          .map((location) => location.pathSegments)
          .flattened
          .map((pathSegment) {
        if (pathSegment.startsWith(":")) {
          return pathParameters[pathSegment.replaceRange(0, 1, "")]!;
        }
        return pathSegment;
      }),
      queryParameters: queryParameters.isEmpty ? null : queryParameters.unlock,
    );
  }

  Future<bool> _guard(IList<Location<ID>> newLocations) async {
    for (final guard in _guards) {
      final guardedLocation = NearestLocation.of<ID>(guard.context);
      if (data!.locations.contains(guardedLocation) &&
          !newLocations.contains(guardedLocation)) {
        if (!(await guard.widget.mayLeave())) {
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
