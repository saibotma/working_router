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
  ///
  /// Prefer generated `routeTo...` helpers in application code. The
  /// [writePathParameters] and [writeQueryParameters] callbacks are low-level
  /// hooks for those generated helpers and are discouraged for handwritten
  /// routing code. Use [routeToUri] when navigating to an already-encoded URI.
  void routeToId(
    AnyNodeId id, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  });

  void slideIn(AnyNodeId id);

  /// Routes to the first child for which [predicate] returns
  /// true.
  ///
  /// Reuses the path parameters and query parameters from the parent and extends
  /// them with [writePathParameters] and [writeQueryParameters]. In case the
  /// same parameter is both in the parent parameters and in the written
  /// parameters, the written parameter overrides the parent parameter.
  ///
  /// Query values written through [writeQueryParameters] are encoded and omitted
  /// when they equal the query parameter's non-null default value.
  ///
  /// Prefer generated child target helpers in application code. The
  /// [writePathParameters] and [writeQueryParameters] callbacks are low-level
  /// hooks for those generated helpers and are discouraged for handwritten
  /// routing code.
  void routeToChildWhere(
    bool Function(AnyLocation location) predicate, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  });

  /// Routes to the first child of type [T].
  ///
  /// Prefer generated child target helpers in application code. See
  /// [routeToChildWhere] for how [writePathParameters] and
  /// [writeQueryParameters] are applied by those helpers.
  void routeToChild<T>({
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
  });

  /// Routes back one location.
  ///
  /// When called through `WorkingRouter.of(context)` inside a nested navigator,
  /// this is navigator-aware: it removes the last active location owned by that
  /// nested navigator before falling back to the parent/global route back
  /// behavior. This lets a sidebar navigator close its own query-filtered page
  /// without popping a detail page rendered in a sibling navigator.
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
