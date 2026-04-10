import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

void main() {
  group('WorkingRouterData path helpers', () {
    test('pathTemplateUpToNode ignores hydrated path parameter values', () {
      const itemId = PathParam(StringRouteParamCodec());
      final list = _TestLocation(id: 'list', path: '/items');
      final detail = _ParamOnlyLocation(id: 'detail', parameter: itemId);
      final data = WorkingRouterData<String>(
        uri: Uri(path: '/items/123'),
        elements: [list, detail].toIList(),
        pathParameters: {itemId: '123'}.lock,
        queryParameters: IMap(),
      );

      expect(data.pathUpToNode(detail), '/items/123');
      expect(data.pathTemplateUpToNode(detail), '/items/*');
    });

    test('path helpers use node identity for repeated no-id locations', () {
      final parent = _NoIdSegmentLocation(path: '/parent');
      final first = _NoIdSegmentLocation(path: '/first');
      final second = _NoIdSegmentLocation(path: '/second');
      final data = WorkingRouterData<String>(
        uri: Uri(path: '/parent/first/second'),
        elements: [parent, first, second].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.pathUpToLocation(first), '/parent/first');
      expect(data.pathUpToNode(first), '/parent/first');
      expect(data.pathTemplateUpToNode(first), '/parent/first');
      expect(data.pathUpToLocation(second), '/parent/first/second');
      expect(data.pathUpToNode(second), '/parent/first/second');
      expect(data.pathTemplateUpToNode(second), '/parent/first/second');
    });
  });

  group('WorkingRouterData query param helpers', () {
    test('queryParam returns the configured default for missing values', () {
      const tab = QueryParam(
        'tab',
        StringRouteParamCodec(),
        defaultValue: Default('all'),
      );
      final location = _QueryLocation(id: 'query', parameter: tab);
      final data = WorkingRouterData<String>(
        uri: Uri(path: '/query'),
        elements: [location].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.queryParam(tab), 'all');
      expect(data.queryParamOrNull(tab), isNull);
    });

    test(
      'queryParam supports Default(null) with a non-null codec for query params',
      () {
        const endDateTime = QueryParam<DateTime?>(
          'endDateTime',
          DateTimeIsoRouteParamCodec(),
          defaultValue: Default<DateTime?>(null),
        );
        final location = _NullableQueryLocation(
          id: 'query-nullable',
          parameter: endDateTime,
        );
        final data = WorkingRouterData<String>(
          uri: Uri(path: '/query'),
          elements: [location].toIList(),
          pathParameters: IMap(),
          queryParameters: IMap(),
        );

        expect(data.queryParam(endDateTime), isNull);
        expect(data.queryParamOrNull(endDateTime), isNull);
      },
    );
  });

  group('WorkingRouterData.isChildOf', () {
    final root = _TestLocation(id: 'root', path: '/');
    final parent = _TestLocation(id: 'parent', path: '/parent');
    final child = _TestLocation(id: 'child', path: '/child');
    final other = _TestLocation(id: 'other', path: '/other');

    WorkingRouterData<String> buildData(IList<AnyLocation<String>> locations) {
      return WorkingRouterData(
        uri: Uri(path: '/parent/child'),
        elements: locations.cast<LocationTreeElement<String>>().toIList(),
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

class _TestLocation extends AbstractLocation<String, _TestLocation> {
  final List<PathSegment> _segments;

  _TestLocation({required String id, required String path})
    : _segments = _pathSegments(path),
      super(id: id);

  @override
  void build(LocationBuilder<String> builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
  }
}

class _ParamOnlyLocation
    extends AbstractLocation<String, _ParamOnlyLocation> {
  final PathParam<String> parameter;

  _ParamOnlyLocation({required String id, required this.parameter})
    : super(id: id);

  @override
  void build(LocationBuilder<String> builder) {
    builder.pathSegment(parameter);
  }
}

class _QueryLocation extends AbstractLocation<String, _QueryLocation> {
  final QueryParam<String> parameter;

  _QueryLocation({required String id, required this.parameter})
    : super(id: id);

  @override
  List<QueryParam<dynamic>> get queryParameters => [parameter];

  @override
  void build(LocationBuilder<String> builder) {}
}

class _NullableQueryLocation
    extends AbstractLocation<String, _NullableQueryLocation> {
  final QueryParam<DateTime?> parameter;

  _NullableQueryLocation({required String id, required this.parameter})
    : super(id: id);

  @override
  List<QueryParam<dynamic>> get queryParameters => [parameter];

  @override
  void build(LocationBuilder<String> builder) {}
}

class _NoIdSegmentLocation
    extends AbstractLocation<String, _NoIdSegmentLocation> {
  final List<PathSegment> _segments;

  _NoIdSegmentLocation({required String path})
    : _segments = _pathSegments(path);

  @override
  void build(LocationBuilder<String> builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
  }
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
        return LiteralPathSegment(segment);
      })
      .toList(growable: false);
}
