import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/overlay.dart';
import 'package:working_router/src/route_node.dart';

sealed class RouteTarget {
  const RouteTarget();
}

/// A non-terminal route prefix that can be combined with a relative URI.
///
/// Route bases are intentionally not [RouteTarget]s. They describe a route
/// prefix such as a shell or scope, and only become routable after [append]
/// supplies the remaining relative path.
abstract interface class RouteBase {
  RouteTarget append(Uri relativeUri);
}

/// Resolves an id-addressed route prefix before appending a relative URI.
///
/// This is intended for generated `...RouteBase` helpers.
base class IdRouteBase implements RouteBase {
  final AnyRouteNodeId id;

  /// Writes typed path parameter values for the matched route prefix.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand.
  final WritePathParameters? writePathParameters;

  /// Writes typed query parameter values for the matched route prefix.
  ///
  /// This is intended for generated route helpers. Prefer using those helpers
  /// instead of writing this callback by hand.
  final WriteQueryParameters? writeQueryParameters;

  const IdRouteBase(
    this.id, {
    this.writePathParameters,
    this.writeQueryParameters,
  });

  @override
  RouteTarget append(Uri relativeUri) {
    return BaseAppendedRouteTarget(
      base: this,
      relativeUri: relativeUri,
    );
  }
}

/// Routes to [relativeUri] appended below [base].
///
/// Application code normally creates this through generated
/// `SomeRouteBase(...).append(relativeUri)` helpers.
final class BaseAppendedRouteTarget extends RouteTarget {
  final IdRouteBase base;
  final Uri relativeUri;

  const BaseAppendedRouteTarget({
    required this.base,
    required this.relativeUri,
  });
}

/// Routes to [fallback] unless the current route is already inside [base].
///
/// This lets callers enter a route scope without replacing an already active
/// descendant of that same scope.
final class ScopedRouteTarget extends RouteTarget {
  final IdRouteBase base;
  final RouteTarget fallback;

  const ScopedRouteTarget({
    required this.base,
    required this.fallback,
  });
}

extension IdRouteBaseScope on IdRouteBase {
  RouteTarget scope({required RouteTarget fallback}) {
    return ScopedRouteTarget(
      base: this,
      fallback: fallback,
    );
  }
}

/// Routes to a fixed serialized route.
///
/// Hidden path segments and hidden query parameters are included for route
/// state that is intentionally omitted from the browser-visible URI.
final class StaticRouteTarget extends RouteTarget {
  final Uri uri;
  final IList<String> hiddenPathSegments;
  final IMap<String, String> hiddenQueryParameters;

  const StaticRouteTarget(
    this.uri, {
    this.hiddenPathSegments = const IListConst([]),
    this.hiddenQueryParameters = const IMapConst({}),
  });
}

/// Resolves [target] and then trims it to the deepest route prefix rendered
/// inside the navigator subtree owned by [locationId].
///
/// If no matched prefix is rendered inside that navigator subtree, [fallback]
/// is resolved instead. Resolution is intentionally delayed until navigation
/// time so responsive route-tree changes are respected.
final class NavigatorConstrainedRouteTarget extends RouteTarget {
  final RouteTarget target;
  final AnyRouteNodeId locationId;
  final RouteTarget fallback;

  const NavigatorConstrainedRouteTarget({
    required this.target,
    required this.locationId,
    required this.fallback,
  });
}

extension RouteTargetNavigatorConstraint on RouteTarget {
  RouteTarget constrainToNavigator({
    required AnyRouteNodeId locationId,
    required RouteTarget fallback,
  }) {
    return NavigatorConstrainedRouteTarget(
      target: this,
      locationId: locationId,
      fallback: fallback,
    );
  }
}

base class IdRouteTarget extends RouteTarget {
  final AnyRouteNodeId id;

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

extension IdRouteTargetScope on IdRouteTarget {
  RouteTarget get scope {
    return ScopedRouteTarget(
      base: IdRouteBase(
        id,
        writePathParameters: writePathParameters,
        writeQueryParameters: writeQueryParameters,
      ),
      fallback: this,
    );
  }
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
