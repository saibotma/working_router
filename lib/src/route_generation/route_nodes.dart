/// Marks the canonical working-router route-node tree used for route helper
/// generation.
///
/// The annotation target must be a top-level field, getter, or function
/// returning an `Iterable<RouteNode>`.
///
/// Example:
/// ```dart
/// part 'route_nodes.g.dart';
///
/// @RouteNodes()
/// List<RouteNode> buildRouteNodes({
///   required WorkingRouterKey rootRouterKey,
/// }) => [_appRouteTree];
/// ```
///
/// Running `build_runner` generates `routeToX(...)` extension methods on
/// `WorkingRouterSailor` for every location in the route-node tree that has
/// a non-null `id`.
///
/// For start-anchored child routing it also generates:
/// - `childXTarget(...)` helpers on the owning location type
/// - `routeToChildX(BuildContext context, ...)` convenience helpers on the same
///   owning location type
/// - `routeToFirstChildX(BuildContext context, ...)` only when the start node
///   can
///   reach multiple matching descendants and the generator cannot prove a safe
///   `childXTarget(...)`
///
/// Prefer `node.routeToChildX(context, ...)` from widget code, and use
/// `node.childXTarget(...)` directly when you need to compose or pass around the
/// target object itself. When a child route is ambiguous, prefer the generated
/// `node.routeToFirstChildX(context, ...)` helper only if first-match semantics
/// are really what you want.
///
/// Generated `childXTarget(...)` helpers create a [ChildRouteTarget], which is
/// anchored at `this` and resolves the exact live descendant route-node chain
/// below that start node at navigation time. Generated `routeToFirstChildX(...)`
/// helpers use [FirstChildRouteTarget] instead, which keeps explicit
/// first-match descendant search semantics.
///
/// `routeToFirstChildX(...)` is intentionally limited: the generator only emits
/// it when every ambiguous matching descendant would still produce the same
/// generated parameter surface. That means the helper may be ambiguous about
/// which matching descendant is chosen at runtime, but it is not ambiguous
/// about which path/query parameters are required or how they are encoded.
///
/// Global route ids are commonly declared as top-level
/// `final NodeId<T>()` values, and local child ids as
/// `final LocalNodeId<T>()` values. The
/// tokens are intentionally non-const because ids are identity-based and the
/// same route-node type may need multiple distinct ids across repeated
/// occurrences in one tree. The
/// generated helper name is derived from the referenced identifier and strips
/// common trailing suffixes like `Id`, `NodeId`, and `LocalId`. Its required
/// parameters are the union of:
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
/// - named `Location<Self>`, `Scope<Self>`, `ShellLocation<Self>`, and
///   `MultiShellLocation<Self>` subclasses that override `build(...)`
/// - direct `Shell(...)` nodes
/// - top-level or static helper fields and getters
/// - top-level, static, or local helper functions
/// - helper function arguments when the tree-relevant expressions remain
///   statically recoverable from source
/// - `PathParam` instance fields declared on the location class
/// - children returned from `build(...)`
/// - children declared on the location or shell instance via a `children`
///   field or getter
/// - collection `if` elements and spreads inside children lists
///
/// Not supported:
/// - annotating instance members or static class members directly
/// - loops or other arbitrary collection-building constructs
///
/// The generated extension targets `WorkingRouterSailor`.
class RouteNodes {
  const RouteNodes();
}
