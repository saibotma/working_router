import 'package:working_router/src/path_location_tree_element.dart';

class GroupBuilder<ID> extends PathLocationTreeElementBuilder<ID> {
  GroupBuilder();
}

typedef BuildGroup<ID> = void Function(GroupBuilder<ID> builder, Group<ID> group);

/// A non-rendering route scope that shares path, query, and child definitions.
///
/// A group does not build a page and does not create a nested navigator. Use
/// it to factor shared route metadata, such as a common query parameter or path
/// prefix, across multiple child locations.
///
/// If the subtree needs its own page wrapper or nested navigator boundary, use
/// a [Shell] instead.
/// Override-based base class for reusable group subclasses.
///
/// Use this when a group is implemented by subclassing and overriding
/// [build], for example to package a shared subtree into a named type.
abstract class AbstractGroup<ID> extends PathLocationTreeElement<ID>
    implements BuildsWithGroupBuilder<ID> {
  AbstractGroup({
    super.parentRouterKey,
  });

  @override
  GroupBuilder<ID> createBuilder() => GroupBuilder<ID>();
}

/// Callback-based convenience group.
///
/// Use this when the group is defined inline with a `build:` callback.
class Group<ID> extends AbstractGroup<ID> {
  final BuildGroup<ID> _build;

  Group({
    required BuildGroup<ID> build,
    super.parentRouterKey,
  }) : _build = build;

  @override
  void build(GroupBuilder<ID> builder) {
    _build(builder, this);
  }
}
