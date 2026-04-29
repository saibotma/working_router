import 'package:working_router/src/path_route_node.dart';

class ScopeBuilder extends PathRouteNodeBuilder {
  ScopeBuilder();
}

/// A non-rendering route scope that shares path, query, and child definitions.
///
/// A scope does not build a page and does not create a nested navigator. Use
/// it to factor shared route metadata, such as a common query parameter or path
/// prefix, across multiple child locations.
///
/// If the subtree needs its own page wrapper or nested navigator boundary, use
/// a [Shell] instead.
///
/// Override-based base class for reusable scope subclasses.
///
/// Use this when a scope is implemented by subclassing and overriding
/// [build], for example to package a shared subtree into a named type.
abstract class Scope<Self extends Scope<Self>> extends PathRouteNode<Self>
    implements BuildsWithScopeBuilder {
  Scope({
    super.id,
    super.localId,
    super.parentRouterKey,
  });

  /// A typed reference to this node for child-factory code.
  Self get node => this as Self;

  @override
  ScopeBuilder createBuilder() => ScopeBuilder();
}
