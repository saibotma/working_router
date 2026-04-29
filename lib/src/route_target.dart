import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/overlay.dart';
import 'package:working_router/src/route_node.dart';

sealed class RouteTarget {
  const RouteTarget();
}

final class UriRouteTarget extends RouteTarget {
  final Uri uri;

  const UriRouteTarget(this.uri);
}

base class IdRouteTarget extends RouteTarget {
  final AnyNodeId id;

  /// Writes typed path parameter values for the matched target route chain.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand.
  final WritePathParameters? writePathParameters;

  /// Writes typed query parameter values for the matched target route chain.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand. Values written here are encoded
  /// by the router and omitted when they equal the parameter's non-null default
  /// value.
  final WriteQueryParameters? writeQueryParameters;

  const IdRouteTarget(
    this.id, {
    this.writePathParameters,
    this.writeQueryParameters,
  });
}

/// A safe child route target anchored at a concrete start location instance.
///
/// Routing with this target starts from [start], not from the current active
/// leaf. The [resolveChildPathNodes] callback runs at navigation time and must
/// return the exact live descendant route-node chain below [start] that should
/// be appended to the route.
///
/// This is intentionally stronger than a leaf predicate. It avoids ambiguous
/// first-match routing when multiple descendants under the same subtree could
/// satisfy the same type, `id`, or `localId`-based match.
base class ChildRouteTarget extends RouteTarget {
  /// The concrete location instance that child routing starts from.
  final AnyLocation start;

  /// Resolves the exact live descendant route-node chain below [start].
  ///
  /// Generated `childXTarget(...)` helpers typically set this to a callback
  /// that walks `start.resolvedChildren` layer by layer and returns the
  /// intended child path for the current runtime tree shape.
  final IList<RouteNode>? Function() resolveChildPathNodes;

  /// Writes typed path parameter values for the matched target route chain.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand.
  final WritePathParameters? writePathParameters;

  /// Writes typed query parameter values for the matched target route chain.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand. Values written here are encoded
  /// by the router and omitted when they equal the parameter's non-null default
  /// value.
  final WriteQueryParameters? writeQueryParameters;

  const ChildRouteTarget({
    required this.start,
    required this.resolveChildPathNodes,
    this.writePathParameters,
    this.writeQueryParameters,
  });
}

/// Routes to a query-controlled overlay owned by an active route node.
///
/// Overlay routing keeps the primary route chain unchanged. Routing to an
/// overlay writes the overlay conditions into the query state and then rebuilds
/// router data from the current primary route chain.
base class OverlayRouteTarget extends RouteTarget {
  final RouteNode owner;
  final AnyOverlay overlay;

  const OverlayRouteTarget({
    required this.owner,
    required this.overlay,
  });
}

/// An explicit first-match child route target.
///
/// This starts from the current active leaf and walks descendants depth-first
/// until [predicate] matches. It is less precise than [ChildRouteTarget], but
/// useful when first-match semantics are intentional.
base class FirstChildRouteTarget extends RouteTarget {
  final bool Function(AnyLocation location) predicate;

  /// Writes typed path parameter values for the matched target route chain.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand.
  final WritePathParameters? writePathParameters;

  /// Writes typed query parameter values for the matched target route chain.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand. Values written here are encoded
  /// by the router and omitted when they equal the parameter's non-null default
  /// value.
  final WriteQueryParameters? writeQueryParameters;

  const FirstChildRouteTarget(
    this.predicate, {
    this.writePathParameters,
    this.writeQueryParameters,
  });
}
