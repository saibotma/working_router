import 'package:working_router/src/working_router_data.dart';

/// Why this transition was triggered.
enum RouteTransitionReason {
  /// Application code explicitly routed (e.g. routeToUri, routeBack, routeToId).
  programmatic,

  /// A transition callback redirected to a new URI.
  redirect,

  /// Route information changed externally (e.g. browser back/forward).
  routeInformation,
}

/// Immutable transition context passed to transition callbacks.
class RouteTransition<ID> {
  final WorkingRouterData<ID>? from;
  final WorkingRouterData<ID> to;
  final RouteTransitionReason reason;

  const RouteTransition({
    required this.from,
    required this.to,
    required this.reason,
  });
}

/// The result of a transition callback.
sealed class TransitionDecision<ID> {
  const TransitionDecision();
}

final class AllowTransition<ID> extends TransitionDecision<ID> {
  const AllowTransition();
}

final class BlockTransition<ID> extends TransitionDecision<ID> {
  const BlockTransition();
}

sealed class RedirectTarget<ID> {
  const RedirectTarget();
}

final class RedirectToUri<ID> extends RedirectTarget<ID> {
  final Uri uri;

  const RedirectToUri(this.uri);
}

final class RedirectToId<ID> extends RedirectTarget<ID> {
  final ID id;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;

  const RedirectToId(
    this.id, {
    this.pathParameters = const {},
    this.queryParameters = const {},
  });
}

final class RedirectTransition<ID> extends TransitionDecision<ID> {
  final RedirectTarget<ID> to;

  const RedirectTransition(this.to);

  factory RedirectTransition.toUriString(String uriString) {
    return RedirectTransition.toUri(Uri.parse(uriString));
  }

  factory RedirectTransition.toUri(Uri uri) {
    return RedirectTransition(RedirectToUri(uri));
  }

  factory RedirectTransition.toId(
    ID id, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    return RedirectTransition(
      RedirectToId(
        id,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
      ),
    );
  }
}
