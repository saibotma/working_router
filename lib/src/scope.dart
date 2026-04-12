import 'package:working_router/src/path_location_tree_element.dart';

class ScopeBuilder<ID> extends PathLocationTreeElementBuilder<ID> {
  ScopeBuilder();
}

typedef BuildScope<ID> = void Function(ScopeBuilder<ID> builder, Scope<ID> scope);

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
abstract class AbstractScope<ID> extends PathLocationTreeElement<ID>
    implements BuildsWithScopeBuilder<ID> {
  AbstractScope({
    super.parentRouterKey,
  });

  @override
  ScopeBuilder<ID> createBuilder() => ScopeBuilder<ID>();
}

/// Callback-based convenience scope.
///
/// Use this when the scope is defined inline with a `build:` callback.
class Scope<ID> extends AbstractScope<ID> {
  final BuildScope<ID> _build;

  Scope({
    required BuildScope<ID> build,
    super.parentRouterKey,
  }) : _build = build;

  @override
  void build(ScopeBuilder<ID> builder) {
    _build(builder, this);
  }
}
