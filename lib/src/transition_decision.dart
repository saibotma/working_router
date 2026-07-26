import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/route_target.dart';
import 'package:working_router/src/working_router_data.dart';

/// Why this transition was triggered.
enum RouteTransitionReason {
  /// Application code explicitly routed (e.g. routeToStatic, routeBack, routeToId).
  programmatic,

  /// The currently mounted route was checked again against current state.
  revalidation,

  /// A transition callback redirected to a new destination.
  redirect,

  /// Route information changed externally (e.g. browser back/forward).
  routeInformation,
}

/// Whether a transition may be rejected by a location leave guard.
enum RouteTransitionPolicy {
  /// Honor all leave guards for locations removed by the transition.
  standard,

  /// The current route must be left even if a leave guard would reject it.
  mandatory,
}

/// Immutable transition context passed to transition callbacks.
class RouteTransition {
  final WorkingRouterData? from;
  final WorkingRouterData to;
  final RouteTransitionReason reason;
  final RouteTransitionPolicy policy;

  const RouteTransition({
    required this.from,
    required this.to,
    required this.reason,
    required this.policy,
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
/// resolves the redirected target and runs the transition resolver again with
/// [RouteTransition.reason] set to [RouteTransitionReason.redirect]. That
/// second pass is required for chained redirects.
final class RedirectTransition extends TransitionDecision {
  final RouteTarget to;
  final RouteTransitionPolicy policy;

  const RedirectTransition(
    this.to, {
    this.policy = RouteTransitionPolicy.standard,
  });

  factory RedirectTransition.toUriString(
    String uriString, {
    RouteTransitionPolicy policy = RouteTransitionPolicy.standard,
  }) {
    return RedirectTransition.toUri(Uri.parse(uriString), policy: policy);
  }

  factory RedirectTransition.toUri(
    Uri uri, {
    RouteTransitionPolicy policy = RouteTransitionPolicy.standard,
  }) {
    return RedirectTransition(StaticRouteTarget(uri), policy: policy);
  }

  factory RedirectTransition.toId(
    AnyRouteNodeId id, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
    RouteTransitionPolicy policy = RouteTransitionPolicy.standard,
  }) {
    return RedirectTransition(
      IdRouteTarget(
        id,
        writePathParameters: writePathParameters,
        writeQueryParameters: writeQueryParameters,
      ),
      policy: policy,
    );
  }
}
