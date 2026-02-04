import 'package:working_router/working_router.dart';

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
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
    bool isRedirect = false,
  });

  Future<void> slideIn(
    ID id, {
    bool isRedirect = false,
  });

  /// Routes to the first child for which [predicate] returns
  /// true.
  ///
  /// Reuses the path parameters and query parameters
  /// from the parent and extends them with [pathParameters]
  /// and [queryParameters], respectively. In case the same parameter
  /// is both in the parent parameters and in the passed in parameters
  /// the passed in parameter overrides the parent parameter.
  Future<void> routeToChildWhere(
    bool Function(Location<ID> location) predicate, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
    bool isRedirect = false,
  });

  Future<void> routeToChild<T>({
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
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
