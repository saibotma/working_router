import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

void main() {
  group('WorkingRouterData path helpers', () {
    test('pathTemplateUpToNode ignores hydrated path parameter values', () {
      final itemId = pathParam(const StringRouteParamCodec());
      final list = _TestLocation(id: 'list', path: '/items');
      final detail = _ParamOnlyLocation(id: 'detail', parameter: itemId);
      final data = WorkingRouterData<String>(
        uri: Uri(path: '/items/123'),
        nodes: [list, detail].toIList(),
        pathParameters: {itemId: '123'}.lock,
        queryParameters: IMap(),
      );

      expect(data.pathUpToNode(detail), '/items/123');
      expect(data.pathTemplateUpToNode(detail), '/items/*');
    });
  });

  group('WorkingRouterData.isChildOf', () {
    final root = _TestLocation(id: 'root', path: '/');
    final parent = _TestLocation(id: 'parent', path: '/parent');
    final child = _TestLocation(id: 'child', path: '/child');
    final other = _TestLocation(id: 'other', path: '/other');

    WorkingRouterData<String> buildData(IList<Location<String>> locations) {
      return WorkingRouterData(
        uri: Uri(path: '/parent/child'),
        nodes: locations.cast<RouteNode<String>>().toIList(),
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
  final List<PathSegment> path;

  _TestLocation({required super.id, required String path})
    : path = _pathSegments(path);
}

class _ParamOnlyLocation extends Location<String> {
  final PathParam<String> parameter;

  _ParamOnlyLocation({required super.id, required this.parameter});

  @override
  List<PathSegment> get path => [parameter];
}

List<PathSegment> _pathSegments(String path) {
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  if (normalizedPath.isEmpty) {
    return const [];
  }

  return normalizedPath
      .split('/')
      .map((segment) {
        if (segment.startsWith(':')) {
          throw UnsupportedError(
            'Use a PathParam field instead of inline dynamic path segments.',
          );
        }
        return PathSegment.literal(segment);
      })
      .toList(growable: false);
}
