import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

void main() {
  group('WorkingRouterData.isChildOf', () {
    final root = _TestLocation(id: 'root', path: '/');
    final parent = _TestLocation(id: 'parent', path: '/parent');
    final child = _TestLocation(id: 'child', path: '/child');
    final other = _TestLocation(id: 'other', path: '/other');

    WorkingRouterData<String> buildData(IList<Location<String>> locations) {
      return WorkingRouterData(
        uri: Uri(path: '/parent/child'),
        locations: locations,
        pathParameters: IMap(),
        queryParameters: IMap(),
      );
    }

    test('returns true when child is matched below parent', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf((location) => location.id == 'parent', child),
        isTrue,
      );
    });

    test('returns false when parent and child are the same location', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf((location) => location.id == 'parent', parent),
        isFalse,
      );
    });

    test('returns false when parent is below child', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf((location) => location.id == 'child', parent),
        isFalse,
      );
    });

    test('returns false when either location is not matched', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf((location) => location.id == 'other', child),
        isFalse,
      );
      expect(
        data.isChildOf((location) => location.id == 'parent', other),
        isFalse,
      );
    });
  });
}

class _TestLocation extends Location<String> {
  @override
  final String? id;

  @override
  final String path;

  _TestLocation({required this.id, required this.path});
}
