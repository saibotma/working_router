import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/route_target.dart';
import 'package:working_router/src/widgets/location_observer.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';

/// What started a navigation attempt, or a resolver pass within one.
enum RouteTransitionTrigger {
  /// Application code explicitly routed (e.g. routeToStatic, routeBack, routeToId).
  programmatic,

  /// The currently mounted route was checked again against current state.
  revalidation,

  /// A transition resolver redirected to a new destination.
  ///
  /// Only [TransitionRequest.trigger] uses this value, for the resolver passes
  /// that follow a [RedirectTransition]. [RouteTransition.trigger] always
  /// names what started the attempt and lists redirects in
  /// [RouteTransition.redirects] instead.
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

/// A candidate destination that a [TransitionResolver] decides on.
///
/// A navigation attempt creates one request for its initial destination and
/// one more for every destination a [RedirectTransition] produces.
class TransitionRequest {
  final WorkingRouterData? from;
  final WorkingRouterData to;

  /// What produced this candidate.
  ///
  /// The initial request carries what started the attempt. Requests for
  /// redirected destinations carry [RouteTransitionTrigger.redirect].
  final RouteTransitionTrigger trigger;

  /// The policy of the attempt so far.
  ///
  /// A mandatory redirect makes all later requests of the attempt mandatory.
  final RouteTransitionPolicy policy;

  const TransitionRequest({
    required this.from,
    required this.to,
    required this.trigger,
    required this.policy,
  });
}

/// A redirect that a [TransitionResolver] applied during a navigation attempt.
class RouteRedirect {
  /// The candidate the resolver redirected away from.
  final WorkingRouterData from;

  /// The candidate the redirect produced.
  ///
  /// It is not necessarily the attempt's final destination, because the
  /// resolver runs again for it and may redirect once more.
  final WorkingRouterData to;

  /// The [RedirectTransition.cause] that the resolver gave for this redirect.
  final Object? cause;

  const RouteRedirect({
    required this.from,
    required this.to,
    required this.cause,
  });
}

/// A navigation attempt that went through.
///
/// The router reports it to `WorkingRouter.onTransitionCompleted` and, for
/// locations that the attempt removed, to [LocationObserver.afterLeave].
/// Attempts that the resolver blocks, that a leave guard declines, or that a
/// newer attempt supersedes never produce one.
class RouteTransition {
  final WorkingRouterData? from;

  /// The route data the attempt resolved to, after all [redirects].
  final WorkingRouterData to;

  /// What started the attempt.
  ///
  /// This is never [RouteTransitionTrigger.redirect]; see [redirects] for the
  /// redirects that were applied on the way to [to].
  final RouteTransitionTrigger trigger;

  /// The final policy of the attempt, including mandatory redirects.
  final RouteTransitionPolicy policy;

  /// Every redirect applied during the attempt, in the order the resolver
  /// returned them, including redirects without a cause.
  final IList<RouteRedirect> redirects;

  /// Whether the attempt committed new route state.
  ///
  /// It is false when the resolved destination equals the current route data,
  /// for example when the resolver redirects a link back to the current
  /// route. The router then neither notifies its listeners nor runs leave
  /// callbacks, but still reports the attempt as completed.
  ///
  /// A `WorkingRouter.refresh` always commits its rebuilt route-node tree, so
  /// it reports true even when the resolved data equals the current data.
  final bool changed;

  const RouteTransition({
    required this.from,
    required this.to,
    required this.trigger,
    required this.policy,
    required this.redirects,
    required this.changed,
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
/// [TransitionRequest.trigger] set to [RouteTransitionTrigger.redirect]. That
/// second pass is required for chained redirects.
final class RedirectTransition extends TransitionDecision {
  final RouteTarget to;
  final RouteTransitionPolicy policy;

  /// Why the resolver redirected, for example to show a notice once the
  /// redirect has completed.
  ///
  /// working_router never interprets this value. It is not part of the route
  /// data or the URI, it is not delivered to the target page, and it does not
  /// survive a reload or a later revalidation. The router only hands it back
  /// through [RouteRedirect.cause] in [RouteTransition.redirects] once the
  /// attempt has completed. Do not use it to pass data to the target page;
  /// encode such data in the route target instead.
  final Object? cause;

  const RedirectTransition(
    this.to, {
    this.policy = RouteTransitionPolicy.standard,
    this.cause,
  });

  factory RedirectTransition.toUriString(
    String uriString, {
    RouteTransitionPolicy policy = RouteTransitionPolicy.standard,
    Object? cause,
  }) {
    return RedirectTransition.toUri(
      Uri.parse(uriString),
      policy: policy,
      cause: cause,
    );
  }

  factory RedirectTransition.toUri(
    Uri uri, {
    RouteTransitionPolicy policy = RouteTransitionPolicy.standard,
    Object? cause,
  }) {
    return RedirectTransition(
      StaticRouteTarget(uri),
      policy: policy,
      cause: cause,
    );
  }

  factory RedirectTransition.toId(
    AnyRouteNodeId id, {
    WritePathParameters? writePathParameters,
    WriteQueryParameters? writeQueryParameters,
    RouteTransitionPolicy policy = RouteTransitionPolicy.standard,
    Object? cause,
  }) {
    return RedirectTransition(
      IdRouteTarget(
        id,
        writePathParameters: writePathParameters,
        writeQueryParameters: writeQueryParameters,
      ),
      policy: policy,
      cause: cause,
    );
  }
}
