import 'package:working_router/working_router.dart';

abstract class WorkingRouterSailor<ID> {
  void routeTo(RouteTarget<ID> target);

  void routeToUriString(String uriString);

  void routeToUri(Uri uri);

  void routeToId(
    ID id, {
    Map<String, String> queryParameters = const {},
    WritePathParameters<ID>? writePathParameters,
  });

  void slideIn(ID id);

  /// Routes to the first child for which [predicate] returns
  /// true.
  ///
  /// Reuses the path parameters and query parameters
  /// from the parent and extends them with [writePathParameters]
  /// and [queryParameters], respectively. In case the same parameter
  /// is both in the parent parameters and in the passed in parameters
  /// the passed in parameter overrides the parent parameter.
  void routeToChildWhere(
    bool Function(Location<ID> location) predicate, {
    Map<String, String> queryParameters = const {},
    WritePathParameters<ID>? writePathParameters,
  });

  void routeToChild<T>({
    Map<String, String> queryParameters = const {},
    WritePathParameters<ID>? writePathParameters,
  });

  // Routes back one to the previous location.
  void routeBack();

  /// Routes back until [match] returns true.
  /// Retains path parameters required by the remaining route chain and
  /// query parameters declared by the remaining locations.
  void routeBackUntil(bool Function(Location<ID> location) match);
}
