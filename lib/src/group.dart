import 'package:working_router/src/path_location_tree_element.dart';

class GroupBuilder<ID> extends PathLocationTreeElementBuilder<ID> {
  GroupBuilder();
}

typedef BuildGroup<ID> = void Function(GroupBuilder<ID> builder);

class Group<ID> extends PathLocationTreeElement<ID>
    implements BuildsWithGroupBuilder<ID> {
  final BuildGroup<ID>? _build;

  Group({
    BuildGroup<ID>? build,
    super.parentRouterKey,
  }) : _build = build;

  @override
  GroupBuilder<ID> createBuilder() => GroupBuilder<ID>();

  @override
  void build(GroupBuilder<ID> builder) {
    final callback = _build;
    if (callback == null) {
      throw StateError(
        'Group $runtimeType must either override build(...) or provide '
        'a build callback.',
      );
    }
    callback(builder);
  }
}
