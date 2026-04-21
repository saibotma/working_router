import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

enum _TestId {
  list,
  detail,
  query,
  queryNullable,
  root,
  parent,
  child,
  other,
  accounts,
}

void main() {
  group('WorkingRouterData path helpers', () {
    test('pathTemplateUpToNode ignores hydrated path parameter values', () {
      const itemId = UnboundPathParam(StringRouteParamCodec());
      final list = _TestLocation(id: _TestId.list, path: '/items');
      final detail = _ParamOnlyLocation(id: _TestId.detail, parameter: itemId);
      final boundItemId = detail.boundParameter;
      final data = WorkingRouterData<_TestId>(
        uri: Uri(path: '/items/123'),
        routeNodes: [list, detail].toIList(),
        pathParameters: {itemId: '123'}.lock,
        queryParameters: IMap(),
      );

      expect(data.pathUpToNode(detail), '/items/123');
      expect(data.pathTemplateUpToNode(detail), '/items/*');
      expect(data.param(boundItemId), '123');
    });

    test('path helpers use node identity for repeated no-id locations', () {
      final parent = _NoIdSegmentLocation(path: '/parent');
      final first = _NoIdSegmentLocation(path: '/first');
      final second = _NoIdSegmentLocation(path: '/second');
      final data = WorkingRouterData<_TestId>(
        uri: Uri(path: '/parent/first/second'),
        routeNodes: [parent, first, second].toIList(),
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
      const tab = UnboundQueryParam(
        'tab',
        StringRouteParamCodec(),
        defaultValue: Default('all'),
      );
      final location = _QueryLocation(id: _TestId.query, parameter: tab);
      final boundTab = location.boundParameter;
      final data = WorkingRouterData<_TestId>(
        uri: Uri(path: '/query'),
        routeNodes: [location].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.param(boundTab), 'all');
    });

    test(
      'queryParam supports Default(null) with a non-null codec for query params',
      () {
        const endDateTime = UnboundQueryParam<DateTime?>(
          'endDateTime',
          DateTimeIsoRouteParamCodec(),
          defaultValue: Default<DateTime?>(null),
        );
        final location = _NullableQueryLocation(
          id: _TestId.queryNullable,
          parameter: endDateTime,
        );
        final boundEndDateTime = location.boundParameter;
        final data = WorkingRouterData<_TestId>(
          uri: Uri(path: '/query'),
          routeNodes: [location].toIList(),
          pathParameters: IMap(),
          queryParameters: IMap(),
        );

        expect(data.param(boundEndDateTime), isNull);
      },
    );

    test('paramOrNull returns active values for unbound params only', () {
      const itemId = UnboundPathParam(StringRouteParamCodec());
      const tab = UnboundQueryParam(
        'tab',
        StringRouteParamCodec(),
        defaultValue: Default('all'),
      );
      final list = _TestLocation(id: _TestId.list, path: '/items');
      final detail = _BoundParamLocation(
        id: _TestId.detail,
        pathParameter: itemId,
        queryParameter: tab,
      );
      final data = WorkingRouterData<_TestId>(
        uri: Uri(path: '/items/123'),
        routeNodes: [list, detail].toIList(),
        pathParameters: {itemId: '123'}.lock,
        queryParameters: IMap(),
      );

      expect(data.paramOrNull(itemId), '123');
      expect(data.paramOrNull(tab), 'all');
    });
  });

  group('WorkingRouterData.isChildOf', () {
    final root = _TestLocation(id: _TestId.root, path: '/');
    final parent = _TestLocation(id: _TestId.parent, path: '/parent');
    final child = _TestLocation(id: _TestId.child, path: '/child');
    final other = _TestLocation(id: _TestId.other, path: '/other');

    WorkingRouterData<_TestId> buildData(
      IList<AnyLocation<_TestId>> locations,
    ) {
      return WorkingRouterData(
        uri: Uri(path: '/parent/child'),
        routeNodes: locations.cast<RouteNode<_TestId>>().toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );
    }

    test('returns true when child is matched below parent', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation<_TestId> && node.id == _TestId.parent,
          child,
        ),
        isTrue,
      );
    });

    test('returns false when parent and child are the same location', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation<_TestId> && node.id == _TestId.parent,
          parent,
        ),
        isFalse,
      );
    });

    test('returns false when parent is below child', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation<_TestId> && node.id == _TestId.child,
          parent,
        ),
        isFalse,
      );
    });

    test('returns false when either location is not matched', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation<_TestId> && node.id == _TestId.other,
          child,
        ),
        isFalse,
      );
      expect(
        data.isChildOf(
          (node) => node is AnyLocation<_TestId> && node.id == _TestId.parent,
          other,
        ),
        isFalse,
      );
    });
  });

  group('WorkingRouterData route node matching', () {
    test(
      'isMatched includes structural route nodes while leaf stays semantic',
      () {
        final accountsNode = _AccountsNode(id: _TestId.accounts);
        final detail = _TestLocation(id: _TestId.detail, path: '/detail');
        final data = WorkingRouterData<_TestId>(
          uri: Uri(path: '/accounts/detail'),
          routeNodes: [accountsNode, detail].toIList(),
          pathParameters: IMap(),
          queryParameters: IMap(),
        );

        expect(data.routeNodes, orderedEquals([accountsNode, detail]));
        expect(data.isMatched<_AccountsNode>(), isTrue);
        expect(
          data.isMatched<_TestLocation>(
            (location) => location.id == _TestId.detail,
          ),
          isTrue,
        );
        expect(data.leaf, same(detail));
      },
    );

    test('isIdMatched includes structural route node ids', () {
      final accountsNode = _AccountsNode(id: _TestId.accounts);
      final detail = _TestLocation(id: _TestId.detail, path: '/detail');
      final data = WorkingRouterData<_TestId>(
        uri: Uri(path: '/accounts/detail'),
        routeNodes: [accountsNode, detail].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.isIdMatched(_TestId.accounts), isTrue);
      expect(
        data.isAnyIdMatched([_TestId.other, _TestId.accounts]),
        isTrue,
      );
      expect(data.matchingId([_TestId.other, _TestId.accounts]), _TestId.accounts);
      expect(data.isIdLeaf(_TestId.accounts), isFalse);
      expect(data.leaf, same(detail));
    });
  });
}

class _TestLocation extends AbstractLocation<_TestId, _TestLocation> {
  final List<PathSegment> _segments;

  _TestLocation({required _TestId id, required String path})
    : _segments = _pathSegments(path),
      super(id: id);

  @override
  void build(LocationBuilder<_TestId> builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
  }
}

class _ParamOnlyLocation
    extends AbstractLocation<_TestId, _ParamOnlyLocation> {
  final UnboundPathParam<String> parameter;
  late final PathParam<String> boundParameter =
      definition.pathParameters.single as PathParam<String>;

  _ParamOnlyLocation({required _TestId id, required this.parameter})
    : super(id: id);

  @override
  void build(LocationBuilder<_TestId> builder) {
    builder.bindParam(parameter);
  }
}

class _QueryLocation extends AbstractLocation<_TestId, _QueryLocation> {
  final UnboundQueryParam<String> parameter;
  late final QueryParam<String> boundParameter =
      definition.queryParameters.single as QueryParam<String>;

  _QueryLocation({required _TestId id, required this.parameter})
    : super(id: id);

  @override
  void build(LocationBuilder<_TestId> builder) {
    builder.bindParam(parameter);
  }
}

class _NullableQueryLocation
    extends AbstractLocation<_TestId, _NullableQueryLocation> {
  final UnboundQueryParam<DateTime?> parameter;
  late final QueryParam<DateTime?> boundParameter =
      definition.queryParameters.single as QueryParam<DateTime?>;

  _NullableQueryLocation({required _TestId id, required this.parameter})
    : super(id: id);

  @override
  void build(LocationBuilder<_TestId> builder) {
    builder.bindParam(parameter);
  }
}

class _NoIdSegmentLocation
    extends AbstractLocation<_TestId, _NoIdSegmentLocation> {
  final List<PathSegment> _segments;

  _NoIdSegmentLocation({required String path})
    : _segments = _pathSegments(path);

  @override
  void build(LocationBuilder<_TestId> builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
  }
}

class _BoundParamLocation
    extends AbstractLocation<_TestId, _BoundParamLocation> {
  final UnboundPathParam<String> pathParameter;
  final UnboundQueryParam<String> queryParameter;

  _BoundParamLocation({
    required _TestId id,
    required this.pathParameter,
    required this.queryParameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder<_TestId> builder) {
    builder.bindParam(pathParameter);
    builder.bindParam(queryParameter);
  }
}

class _AccountsNode extends AbstractShell<_TestId> {
  _AccountsNode({required super.id});

  @override
  void build(ShellBuilder<_TestId> builder) {
    builder.pathLiteral('accounts');
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
