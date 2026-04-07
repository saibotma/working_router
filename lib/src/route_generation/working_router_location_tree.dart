/// Marks the canonical working-router location tree used for route helper
/// generation.
///
/// The annotation target must be a top-level field, getter, or function
/// returning `RouteNode<ID>`.
///
/// Example:
/// ```dart
/// part 'app_routes.g.dart';
///
/// @WorkingRouterLocationTree()
/// RouteNode<AppRouteId> buildRouteNodeTree() => _appRouteTree;
/// ```
///
/// Running `build_runner` generates `routeToX(...)` extension methods on
/// `WorkingRouterSailor<ID>` for every location in the tree that has a non-null
/// `id`.
///
/// The generated helper name is derived from the enum case in the `id`, and
/// its required parameters are the union of:
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
/// - inline constructor trees
/// - top-level or static helper fields and getters
/// - top-level, static, or local helper functions
/// - helper function arguments when the tree-relevant expressions remain
///   statically recoverable from source
/// - `PathParam` instance fields declared on the location class
/// - `QueryParam` instance fields when the location class mixes in the
///   generated `_LocationNameGenerated` mixin
/// - children passed directly to a location constructor
/// - children passed to `super(children: [...])` inside a location constructor
/// - collection `if` elements and spreads inside children lists
///
/// Not supported:
/// - annotating instance members or static class members directly
/// - loops or other arbitrary collection-building constructs
/// - resolving children from an overridden `children` getter
///
/// The generated extension targets `WorkingRouterSailor<ID>`.
class WorkingRouterLocationTree {
  const WorkingRouterLocationTree();
}
