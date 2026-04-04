/// Marks the static working-router location tree used for route helper
/// generation.
///
/// The annotation target must be a top-level field, getter, or zero-argument
/// function returning `Location<ID>`.
///
/// Example:
/// ```dart
/// part 'app_routes.g.dart';
///
/// @WorkingRouterLocationTree()
/// final Location<AppRouteId> appLocationTree = _appLocationTree;
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
/// Static helper members can still be used inside the tree composition as long
/// as the annotated entrypoint itself is top-level. The route topology itself
/// must stay static so the generator can recover it without executing
/// application code.
///
/// Supported static composition includes:
/// - inline constructor trees
/// - top-level or static helper fields, getters, and zero-argument functions
/// - children passed directly to a location constructor
/// - children passed to `super(children: [...])` inside a location constructor
///
/// Not supported:
/// - route topology that depends on runtime values
/// - annotating instance members or static class members directly
/// - resolving children from an overridden `children` getter
///
/// The generated extension targets `WorkingRouterSailor<ID>`.
class WorkingRouterLocationTree {
  const WorkingRouterLocationTree();
}
