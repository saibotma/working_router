import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../working_router.dart';

abstract class WorkingRouterSailor<ID> {
  Future<void> routeToUriString(
    String uriString, {
    bool isRedirect = false,
  });

  Future<void> routeToUri(
    Uri uri, {
    bool isRedirect = false,
  });

  Future<void> routeToId(
    ID id, {
    IMap<String, String> pathParameters = const IMapConst({}),
    IMap<String, String> queryParameters = const IMapConst({}),
    bool isRedirect = false,
  });

  Future<void> slideIn(
    ID id, {
    bool isRedirect = false,
  });

  Future<void> routeToRelative(
    bool Function(Location<ID> location) match, {
    IMap<String, String> pathParameters = const IMapConst({}),
    IMap<String, String> queryParameters = const IMapConst({}),
    bool isRedirect = false,
  });

  // Routes back one to the previous location.
  Future<void> routeBack();

  /// Routes back until [match] returns true.
  /// Selects path and query parameters of the destination location
  /// depending on how [Location.selectQueryParameters] and
  /// [Location.selectPathParameters] are implemented.
  Future<void> routeBackUntil(bool Function(Location<ID> location) match);
}
