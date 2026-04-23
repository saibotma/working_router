import 'package:working_router/src/path_route_node.dart';

class ScopeBuilder extends PathRouteNodeBuilder {
  ScopeBuilder();
}

typedef BuildScope<Self extends AbstractScope<Self>> =
    void Function(ScopeBuilder builder, Self node);
typedef BuildAnonymousScope =
    void Function(ScopeBuilder builder, AnonymousScope node);

/// A non-rendering route scope that shares path, query, and child definitions.
///
/// A scope does not build a page and does not create a nested navigator. Use
/// it to factor shared route metadata, such as a common query parameter or path
/// prefix, across multiple child locations.
///
/// If the subtree needs its own page wrapper or nested navigator boundary, use
/// a [Shell] instead.
/// Override-based base class for reusable scope subclasses.
///
/// Use this when a scope is implemented by subclassing and overriding
/// [build], for example to package a shared subtree into a named type.
abstract class AbstractScope<Self extends AbstractScope<Self>>
    extends PathRouteNode<Self>
    implements BuildsWithScopeBuilder {
  AbstractScope({
    super.id,
    super.localId,
    super.parentRouterKey,
  });

  /// Mirrors the `node` callback parameter used by callback-based scopes.
  ///
  /// This makes override-based scopes easier to keep in sync with callback-
  /// based scopes when moving builder code between the two forms.
  Self get node => this as Self;

  @override
  ScopeBuilder createBuilder() => ScopeBuilder();
}

/// Main typed callback-based scope API.
///
/// Use this for lightweight named scope subclasses that simply forward a
/// `build:` callback.
class Scope<Self extends AbstractScope<Self>> extends AbstractScope<Self> {
  final BuildScope<Self> _build;

  Scope({
    super.id,
    super.localId,
    required BuildScope<Self> build,
    super.parentRouterKey,
  }) : _build = build;

  @override
  void build(ScopeBuilder builder) {
    _build(builder, this as Self);
  }
}

/// Callback-based convenience scope for anonymous inline route nodes.
///
/// This intentionally does not expose a self generic parameter. Use [Scope]
/// for the main typed callback-based API.
class AnonymousScope extends AbstractScope<AnonymousScope> {
  final BuildAnonymousScope _build;

  AnonymousScope({
    super.id,
    super.localId,
    required BuildAnonymousScope build,
    super.parentRouterKey,
  }) : _build = build;

  @override
  void build(ScopeBuilder builder) {
    _build(builder, this);
  }
}
