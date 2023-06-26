import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

import '../working_router.dart';

class WorkingRouterDataProvider<ID> extends InheritedWidget
    implements WorkingRouterDataSailor<ID> {
  final WorkingRouter<ID> _router;

  @override
  final WorkingRouterData<ID> data;

  const WorkingRouterDataProvider({
    required WorkingRouter<ID> router,
    required this.data,
    required Widget child,
  })  : _router = router,
        super(child: child);

  @override
  bool updateShouldNotify(
    covariant WorkingRouterDataProvider<ID> oldWidget,
  ) {
    return oldWidget.data != data;
  }

  @override
  Future<void> routeToId(
    ID id, {
    IMap<String, String> pathParameters = const IMapConst({}),
    IMap<String, String> queryParameters = const IMapConst({}),
    bool isRedirect = false,
  }) {
    return _router.routeToId(
      id,
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
  }) {
    return _router.routeToRelative(
      match,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      isRedirect: isRedirect,
    );
  }

  @override
  Future<void> routeToUri(Uri uri, {bool isRedirect = false}) {
    return _router.routeToUri(uri, isRedirect: isRedirect);
  }

  @override
  Future<void> routeToUriString(String uriString, {bool isRedirect = false}) {
    return _router.routeToUriString(uriString, isRedirect: isRedirect);
  }
}
