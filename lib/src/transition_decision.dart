import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/route_target.dart';
import 'package:working_router/src/working_router_data.dart';

/// Why this transition was triggered.
enum RouteTransitionReason {
  /// Application code explicitly routed (e.g. routeToUri, routeBack, routeToId).
  programmatic,

  /// A transition callback redirected to a new destination.
  redirect,

  /// Route information changed externally (e.g. browser back/forward).
  routeInformation,
}

/// Immutable transition context passed to transition callbacks.
class RouteTransition {
  final WorkingRouterData? from;
  final WorkingRouterData to;
  final RouteTransitionReason reason;

  const RouteTransition({
    required this.from,
    required this.to,
    required this.reason,
  });
}

/// The result of a transition callback.
sealed class TransitionDecision {
  const TransitionDecision();
}

final class AllowTransition extends TransitionDecision {
  const AllowTransition();
}

final class BlockTransition extends TransitionDecision {
  const BlockTransition();
}

/// Redirects to a new candidate destination.
///
/// The router does not stop immediately after this decision. Instead it
/// resolves the redirected target and runs the transition decider again with
/// [RouteTransition.reason] set to [RouteTransitionReason.redirect]. That
/// second pass is required for chained redirects.
final class RedirectTransition extends TransitionDecision {
  final RouteTarget to;

  const RedirectTransition(this.to);

  factory RedirectTransition.toUriString(String uriString) {
    return RedirectTransition.toUri(Uri.parse(uriString));
  }

  factory RedirectTransition.toUri(Uri uri) {
    return RedirectTransition(UriRouteTarget(uri));
  }

  factory RedirectTransition.toId(
    AnyNodeId id, {
    Map<String, String> queryParameters = const {},
    WritePathParameters? writePathParameters,
  }) {
    return RedirectTransition(
      IdRouteTarget(
        id,
        queryParameters: queryParameters,
        writePathParameters: writePathParameters,
      ),
    );
  }
}
