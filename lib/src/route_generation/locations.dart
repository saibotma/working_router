/// Marks the canonical working-router location tree used for route helper
/// generation.
///
/// The annotation target must be a top-level field, getter, or function
/// returning an `Iterable<LocationTreeElement<ID>>`.
///
/// Example:
/// ```dart
/// part 'app_routes.g.dart';
///
/// @Locations()
/// List<LocationTreeElement<AppRouteId>> buildLocations({
///   required WorkingRouterKey rootRouterKey,
/// }) => [_appRouteTree];
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
/// - named `Location<ID, Self>` subclasses
/// - direct `Shell(...)` nodes
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
class Locations {
  const Locations();
}
