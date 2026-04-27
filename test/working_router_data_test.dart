import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

abstract final class _TestId {
  static final list = NodeId<_TestLocation>();
  static final paramOnly = NodeId<_ParamOnlyLocation>();
  static final detail = NodeId<_TestLocation>();
  static final query = NodeId<_QueryLocation>();
  static final queryRequired = NodeId<_BuilderRequiredQueryLocation>();
  static final queryNullable = NodeId<_NullableQueryLocation>();
  static final queryDefault = NodeId<_DefaultQueryLocation>();
  static final queryBuilderDefault = NodeId<_BuilderDefaultQueryLocation>();
  static final root = NodeId<_TestLocation>();
  static final parent = NodeId<_TestLocation>();
  static final child = NodeId<_TestLocation>();
  static final other = NodeId<_TestLocation>();
  static final bound = NodeId<_BoundParamLocation>();
  static final accounts = NodeId<_AccountsNode>();
}

final _typedRootId = NodeId<_TypedRootLocation>();
final _typedAddAccountId = NodeId<_TypedAddAccountLocation>();

void main() {
  group('WorkingRouterData path helpers', () {
    test('pathTemplateUpToNode ignores hydrated path parameter values', () {
      const itemId = UnboundPathParam(StringRouteParamCodec());
      final list = _TestLocation(id: _TestId.list, path: '/items');
      final detail = _ParamOnlyLocation(
        id: _TestId.paramOnly,
        parameter: itemId,
      );
      final boundItemId = detail.boundParameter;
      final data = WorkingRouterData(
        uri: Uri(path: '/items/123'),
        routeNodes: <RouteNode>[list, detail].toIList(),
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
      final data = WorkingRouterData(
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
      final data = WorkingRouterData(
        uri: Uri(path: '/query'),
        routeNodes: [location].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.param(boundTab), 'all');
    });

    test('query APIs expose required and default query param types', () {
      const unboundTab = DefaultUnboundQueryParam(
        'tab',
        StringRouteParamCodec(),
        defaultValue: Default('all'),
      );
      final requiredLocation = _BuilderRequiredQueryLocation(
        id: _TestId.queryRequired,
      );
      final boundLocation = _DefaultQueryLocation(
        id: _TestId.queryDefault,
        parameter: unboundTab,
      );
      final builtLocation = _BuilderDefaultQueryLocation(
        id: _TestId.queryBuilderDefault,
      );

      final RequiredQueryParam<String> requiredTab =
          requiredLocation.boundParameter;
      final DefaultQueryParam<String> boundTab = boundLocation.boundParameter;
      final DefaultQueryParam<String> builtTab = builtLocation.boundParameter;
      final data = WorkingRouterData(
        uri: Uri(path: '/query'),
        routeNodes: <RouteNode>[
          requiredLocation,
          boundLocation,
          builtLocation,
        ].toIList(),
        pathParameters: IMap(),
        queryParameters: {'required': 'present'}.lock,
      );

      expect(data.param(requiredTab), 'present');
      expect(data.param(boundTab), 'all');
      expect(data.param(builtTab), 'list');
    });

    test('queryParam error includes query key and current data', () {
      const tab = UnboundQueryParam('tab', StringRouteParamCodec());
      final location = _QueryLocation(id: _TestId.query, parameter: tab);
      final boundTab = location.boundParameter;
      final data = WorkingRouterData(
        uri: Uri(path: '/query', queryParameters: {'filter': 'active'}),
        routeNodes: [location].toIList(),
        pathParameters: IMap(),
        queryParameters: {'filter': 'active'}.lock,
      );

      expect(
        () => data.param(boundTab),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains('`tab`'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('/query?filter=active'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Available query values: `filter`'),
              ),
        ),
      );
    });

    test('queryParam inactive error includes query key and active keys', () {
      const tab = UnboundQueryParam('tab', StringRouteParamCodec());
      const filter = UnboundQueryParam('filter', StringRouteParamCodec());
      final location = _QueryLocation(id: _TestId.query, parameter: filter);
      final inactiveLocation = _QueryLocation(
        id: _TestId.query,
        parameter: tab,
      );
      final inactiveTab = inactiveLocation.boundParameter;
      final data = WorkingRouterData(
        uri: Uri(path: '/query', queryParameters: {'tab': 'all'}),
        routeNodes: [location].toIList(),
        pathParameters: IMap(),
        queryParameters: {'tab': 'all'}.lock,
      );

      expect(
        () => data.param(inactiveTab),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains('`tab`'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('/query?tab=all'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Active query params: `filter`'),
              ),
        ),
      );
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
        final data = WorkingRouterData(
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
        id: _TestId.bound,
        pathParameter: itemId,
        queryParameter: tab,
      );
      final data = WorkingRouterData(
        uri: Uri(path: '/items/123'),
        routeNodes: <RouteNode>[list, detail].toIList(),
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

    WorkingRouterData buildData(
      IList<AnyLocation> locations,
    ) {
      return WorkingRouterData(
        uri: Uri(path: '/parent/child'),
        routeNodes: locations.cast<RouteNode>().toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );
    }

    test('returns true when child is matched below parent', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation && node.id == _TestId.parent,
          child,
        ),
        isTrue,
      );
    });

    test('returns false when parent and child are the same location', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation && node.id == _TestId.parent,
          parent,
        ),
        isFalse,
      );
    });

    test('returns false when parent is below child', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation && node.id == _TestId.child,
          parent,
        ),
        isFalse,
      );
    });

    test('returns false when either location is not matched', () {
      final data = buildData([root, parent, child].toIList());

      expect(
        data.isChildOf(
          (node) => node is AnyLocation && node.id == _TestId.other,
          child,
        ),
        isFalse,
      );
      expect(
        data.isChildOf(
          (node) => node is AnyLocation && node.id == _TestId.parent,
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
        final data = WorkingRouterData(
          uri: Uri(path: '/accounts/detail'),
          routeNodes: <RouteNode>[accountsNode, detail].toIList(),
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
      final data = WorkingRouterData(
        uri: Uri(path: '/accounts/detail'),
        routeNodes: <RouteNode>[accountsNode, detail].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.isIdMatched(_TestId.accounts), isTrue);
      expect(
        data.isAnyIdMatched([_TestId.other, _TestId.accounts]),
        isTrue,
      );
      expect(
        data.matchingId([_TestId.other, _TestId.accounts]),
        _TestId.accounts,
      );
      expect(data.leaf, same(detail));
    });

    test('lastMatched returns the most specific matched node of a type', () {
      final root = _TestLocation(id: _TestId.root, path: '/');
      final parent = _TestLocation(id: _TestId.parent, path: '/parent');
      final child = _TestLocation(id: _TestId.child, path: '/child');
      final data = WorkingRouterData(
        uri: Uri(path: '/parent/child'),
        routeNodes: [root, parent, child].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.lastMatched<_TestLocation>(), same(child));
      expect(
        data.lastMatched<_TestLocation>(
          (location) => location.id != _TestId.child,
        ),
        same(parent),
      );
      expect(data.lastMatched<_AccountsNode>(), isNull);
    });

    test('typed node ids can resolve matched and leaf nodes directly', () {
      final root = _TypedRootLocation();
      final addAccount = _TypedAddAccountLocation();
      final data = WorkingRouterData(
        uri: Uri(path: '/add-account'),
        routeNodes: <RouteNode>[root, addAccount].toIList(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.leafWithId(_typedAddAccountId), same(addAccount));
      expect(data.leafWithId(_typedRootId), isNull);
      expect(data.lastMatchedWithId(_typedRootId), same(root));
      expect(data.lastMatchedWithId(_typedAddAccountId), same(addAccount));
    });
  });
}

class _TestLocation extends AbstractLocation<_TestLocation> {
  final List<PathSegment> _segments;

  _TestLocation({required NodeId<_TestLocation> id, required String path})
    : _segments = _pathSegments(path),
      super(id: id);

  @override
  void build(LocationBuilder builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
  }
}

class _ParamOnlyLocation extends AbstractLocation<_ParamOnlyLocation> {
  final UnboundPathParam<String> parameter;
  late final PathParam<String> boundParameter =
      definition.pathParameters.single as PathParam<String>;

  _ParamOnlyLocation({
    required NodeId<_ParamOnlyLocation> id,
    required this.parameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindParam(parameter);
  }
}

class _QueryLocation extends AbstractLocation<_QueryLocation> {
  final UnboundQueryParam<String> parameter;
  late final QueryParam<String> boundParameter =
      definition.queryParameters.single as QueryParam<String>;

  _QueryLocation({required NodeId<_QueryLocation> id, required this.parameter})
    : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindParam(parameter);
  }
}

class _NullableQueryLocation extends AbstractLocation<_NullableQueryLocation> {
  final UnboundQueryParam<DateTime?> parameter;
  late final QueryParam<DateTime?> boundParameter =
      definition.queryParameters.single as QueryParam<DateTime?>;

  _NullableQueryLocation({
    required NodeId<_NullableQueryLocation> id,
    required this.parameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindParam(parameter);
  }
}

class _DefaultQueryLocation extends AbstractLocation<_DefaultQueryLocation> {
  final DefaultUnboundQueryParam<String> parameter;
  late final DefaultQueryParam<String> boundParameter =
      definition.queryParameters.single as DefaultQueryParam<String>;

  _DefaultQueryLocation({
    required NodeId<_DefaultQueryLocation> id,
    required this.parameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindDefaultQueryParam(parameter);
  }
}

class _BuilderDefaultQueryLocation
    extends AbstractLocation<_BuilderDefaultQueryLocation> {
  late final DefaultQueryParam<String> boundParameter =
      definition.queryParameters.single as DefaultQueryParam<String>;

  _BuilderDefaultQueryLocation({
    required NodeId<_BuilderDefaultQueryLocation> id,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.defaultStringQueryParam(
      'display',
      defaultValue: const Default('list'),
    );
  }
}

class _BuilderRequiredQueryLocation
    extends AbstractLocation<_BuilderRequiredQueryLocation> {
  late final RequiredQueryParam<String> boundParameter =
      definition.queryParameters.single as RequiredQueryParam<String>;

  _BuilderRequiredQueryLocation({
    required NodeId<_BuilderRequiredQueryLocation> id,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.stringQueryParam('required');
  }
}

class _NoIdSegmentLocation extends AbstractLocation<_NoIdSegmentLocation> {
  final List<PathSegment> _segments;

  _NoIdSegmentLocation({required String path})
    : _segments = _pathSegments(path);

  @override
  void build(LocationBuilder builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
  }
}

class _BoundParamLocation extends AbstractLocation<_BoundParamLocation> {
  final UnboundPathParam<String> pathParameter;
  final UnboundQueryParam<String> queryParameter;

  _BoundParamLocation({
    required NodeId<_BoundParamLocation> id,
    required this.pathParameter,
    required this.queryParameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindParam(pathParameter);
    builder.bindParam(queryParameter);
  }
}

class _AccountsNode extends AbstractShell<_AccountsNode> {
  _AccountsNode({required super.id});

  @override
  void build(ShellBuilder builder) {
    builder.pathLiteral('accounts');
  }
}

class _TypedRootLocation extends AbstractLocation<_TypedRootLocation> {
  _TypedRootLocation() : super(id: _typedRootId);

  @override
  void build(LocationBuilder builder) {}
}

class _TypedAddAccountLocation
    extends AbstractLocation<_TypedAddAccountLocation> {
  _TypedAddAccountLocation() : super(id: _typedAddAccountId);

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('add-account');
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
