import 'package:working_router/working_router.dart';

abstract class WorkingRouterSailor<ID> {
  void routeToUriString(String uriString);

  void routeToUri(Uri uri);

  void routeToId(
    ID id, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  });

  void slideIn(ID id);

  /// Routes to the first child for which [predicate] returns
  /// true.
  ///
  /// Reuses the path parameters and query parameters
  /// from the parent and extends them with [pathParameters]
  /// and [queryParameters], respectively. In case the same parameter
  /// is both in the parent parameters and in the passed in parameters
  /// the passed in parameter overrides the parent parameter.
  void routeToChildWhere(
    bool Function(Location<ID> location) predicate, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  });

  void routeToChild<T>({
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  });

  // Routes back one to the previous location.
  void routeBack();

  /// Routes back until [match] returns true.
  /// Selects path and query parameters of the destination location
  /// depending on how [Location.selectQueryParameters] and
  /// [Location.selectPathParameters] are implemented.
  void routeBackUntil(bool Function(Location<ID> location) match);
}
