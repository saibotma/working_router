/// Marks the canonical working-router route-node tree used for route helper
/// generation.
///
/// The annotation target must be a top-level field, getter, or function
/// returning an `Iterable<RouteNode<ID>>`.
///
/// Example:
/// ```dart
/// part 'route_nodes.g.dart';
///
/// @RouteNodes()
/// List<RouteNode<AppRouteId>> buildRouteNodes({
///   required WorkingRouterKey rootRouterKey,
/// }) => [_appRouteTree];
/// ```
///
/// Running `build_runner` generates `routeToX(...)` extension methods on
/// `WorkingRouterSailor<ID>` for every location in the route-node tree that has
/// a non-null enum `id`.
///
/// For owner-bound child routing it also generates:
/// - `childXTarget(...)` helpers on the owning location type
/// - `routeToChildX(BuildContext context, ...)` convenience helpers on the same
///   owning location type
/// - `routeToFirstChildX(BuildContext context, ...)` only when the owner can
///   reach multiple matching descendants and the generator cannot prove a safe
///   `childXTarget(...)`
///
/// Prefer `node.routeToChildX(context, ...)` from widget code, and use
/// `node.childXTarget(...)` directly when you need to compose or pass around the
/// target object itself. When a child route is ambiguous, prefer the generated
/// `node.routeToFirstChildX(context, ...)` helper only if first-match semantics
/// are really what you want.
///
/// `routeToFirstChildX(...)` is intentionally limited: the generator only emits
/// it when every ambiguous matching descendant would still produce the same
/// generated parameter surface. That means the helper may be ambiguous about
/// which matching descendant is chosen at runtime, but it is not ambiguous
/// about which path/query parameters are required or how they are encoded.
///
/// Global route ids and local child ids are both enum-based. The generated
/// helper name is derived from the enum case in the `id` or `localId`, and its
/// required parameters are the union of:
/// - all path parameters from the full ancestor chain
/// - all query parameter keys from the full ancestor chain
///
/// Static helper members and local helper functions can still be used inside
/// the tree composition as long as the annotated entrypoint itself is top-level.
///
/// The generator works on the union of routes that can appear in this tree. In
/// collection literals it includes the branches of `if` elements without
/// evaluating their conditions, so runtime tree pruning still generates helpers
/// for the full route vocabulary.
///
/// Supported composition includes:
/// - named `Location<ID, Self>` subclasses
/// - named `ShellLocation<ID, Self>` subclasses
/// - direct `Shell(...)` nodes
/// - direct `ShellLocation(...)` nodes
/// - top-level or static helper fields and getters
/// - top-level, static, or local helper functions
/// - helper function arguments when the tree-relevant expressions remain
///   statically recoverable from source
/// - `PathParam` instance fields declared on the location class
/// - children returned from `build(...)` or a forwarded `builder:` callback
/// - children declared on the location or shell instance via a `children`
///   field or getter
/// - collection `if` elements and spreads inside children lists
///
/// Not supported:
/// - annotating instance members or static class members directly
/// - loops or other arbitrary collection-building constructs
///
/// The generated extension targets `WorkingRouterSailor<ID>`.
class RouteNodes {
  const RouteNodes();
}
