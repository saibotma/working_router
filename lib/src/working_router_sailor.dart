import 'package:working_router/working_router.dart';

abstract class WorkingRouterSailor {
  void routeTo(RouteTarget target);

  void routeToUriString(String uriString);

  void routeToUri(Uri uri);

  /// Routes to a matched location by id.
  ///
  /// Route-node ids may exist on structural nodes as well, but `routeToId`
  /// intentionally stays location-only. Passing the id of a structural node
  /// throws.
  void routeToId(
    AnyNodeId id, {
    Map<String, String> queryParameters = const {},
    WritePathParameters? writePathParameters,
  });

  void slideIn(AnyNodeId id);

  /// Routes to the first child for which [predicate] returns
  /// true.
  ///
  /// Reuses the path parameters and query parameters
  /// from the parent and extends them with [writePathParameters]
  /// and [queryParameters], respectively. In case the same parameter
  /// is both in the parent parameters and in the passed in parameters
  /// the passed in parameter overrides the parent parameter.
  void routeToChildWhere(
    bool Function(AnyLocation location) predicate, {
    Map<String, String> queryParameters = const {},
    WritePathParameters? writePathParameters,
  });

  void routeToChild<T>({
    Map<String, String> queryParameters = const {},
    WritePathParameters? writePathParameters,
  });

  // Routes back one to the previous location.
  void routeBack();

  /// Routes back as if [fromLocation] were the current active location.
  ///
  /// This is useful when a deeper nested location is active, but the intended
  /// back action should start from an ancestor location instead, such as
  /// dismissing a modal location that hosts its own nested navigator.
  ///
  /// Pass the matched ancestor location from the current router data.
  void routeBackFrom(AnyLocation fromLocation);

  /// Routes back until [match] returns true.
  /// Retains path parameters required by the remaining route chain and
  /// query parameters declared by the remaining locations.
  void routeBackUntil(bool Function(AnyLocation location) match);
}
