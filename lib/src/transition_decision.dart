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
class RouteTransition<ID extends Enum> {
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
sealed class TransitionDecision<ID extends Enum> {
  const TransitionDecision();
}

final class AllowTransition<ID extends Enum> extends TransitionDecision<ID> {
  const AllowTransition();
}

final class BlockTransition<ID extends Enum> extends TransitionDecision<ID> {
  const BlockTransition();
}

/// Redirects to a new candidate destination.
///
/// The router does not stop immediately after this decision. Instead it
/// resolves the redirected target and runs the transition decider again with
/// [RouteTransition.reason] set to [RouteTransitionReason.redirect]. That
/// second pass is required for chained redirects.
final class RedirectTransition<ID extends Enum> extends TransitionDecision<ID> {
  final RouteTarget<ID> to;

  const RedirectTransition(this.to);

  factory RedirectTransition.toUriString(String uriString) {
    return RedirectTransition.toUri(Uri.parse(uriString));
  }

  factory RedirectTransition.toUri(Uri uri) {
    return RedirectTransition(UriRouteTarget<ID>(uri));
  }

  factory RedirectTransition.toId(
    ID id, {
    Map<String, String> queryParameters = const {},
    WritePathParameters<ID>? writePathParameters,
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
