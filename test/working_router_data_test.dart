import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

abstract final class _TestId {
  static final list = RouteNodeId<_TestLocation>();
  static final paramOnly = RouteNodeId<_ParamOnlyLocation>();
  static final detail = RouteNodeId<_TestLocation>();
  static final query = RouteNodeId<_QueryLocation>();
  static final queryRequired = RouteNodeId<_BuilderRequiredQueryLocation>();
  static final queryNullable = RouteNodeId<_NullableQueryLocation>();
  static final queryDefault = RouteNodeId<_DefaultQueryLocation>();
  static final queryBuilderDefault =
      RouteNodeId<_BuilderDefaultQueryLocation>();
  static final root = RouteNodeId<_TestLocation>();
  static final parent = RouteNodeId<_TestLocation>();
  static final child = RouteNodeId<_TestLocation>();
  static final other = RouteNodeId<_TestLocation>();
  static final bound = RouteNodeId<_BoundParamLocation>();
  static final accounts = RouteNodeId<_AccountsNode>();
}

final _typedRootId = RouteNodeId<_TypedRootLocation>();
final _typedAddAccountId = RouteNodeId<_TypedAddAccountLocation>();
final _branchOwnerId = RouteNodeId<_BranchOwnerLocation>();
final _firstOverlayId = RouteNodeId<_BranchOverlay>();
final _secondOverlayId = RouteNodeId<_BranchOverlay>();

WorkingRouterData _workingRouterData({
  required Uri uri,
  required IList<RouteNode> routeNodes,
  required IMap<RouteNode, IList<AnyOverlay>> activeOverlaysByOwner,
  required IMap<UnboundPathParam<dynamic>, String> pathParameters,
  required IMap<String, String> queryParameters,
}) {
  return WorkingRouterData(
    uri: uri,
    routeNodes: routeNodes,
    activeOverlaysByOwner: activeOverlaysByOwner,
    pathParameters: pathParameters,
    queryParameters: queryParameters,
  );
}

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
      final data = _workingRouterData(
        uri: Uri(path: '/items/123'),
        routeNodes: <RouteNode>[list, detail].toIList(),
        activeOverlaysByOwner: IMap(),
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
      final data = _workingRouterData(
        uri: Uri(path: '/parent/first/second'),
        routeNodes: [parent, first, second].toIList(),
        activeOverlaysByOwner: IMap(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.pathUpToNode(first), '/parent/first');
      expect(data.pathTemplateUpToNode(first), '/parent/first');
      expect(data.pathUpToNode(second), '/parent/first/second');
      expect(data.pathTemplateUpToNode(second), '/parent/first/second');
    });
  });

  group('WorkingRouterData query param helpers', () {
    test('queryParam returns the configured default for missing values', () {
      const tab = DefaultUnboundQueryParam(
        'tab',
        StringRouteParamCodec(),
        defaultValue: 'all',
      );
      final location = _QueryLocation(id: _TestId.query, parameter: tab);
      final boundTab = location.boundParameter;
      final data = _workingRouterData(
        uri: Uri(path: '/query'),
        routeNodes: [location].toIList(),
        activeOverlaysByOwner: IMap(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.param(boundTab), 'all');
    });

    test('query APIs expose required and default query param types', () {
      const unboundTab = DefaultUnboundQueryParam(
        'tab',
        StringRouteParamCodec(),
        defaultValue: 'all',
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
      final data = _workingRouterData(
        uri: Uri(path: '/query'),
        routeNodes: <RouteNode>[
          requiredLocation,
          boundLocation,
          builtLocation,
        ].toIList(),
        activeOverlaysByOwner: IMap(),
        pathParameters: IMap(),
        queryParameters: {'required': 'present'}.lock,
      );

      expect(data.param(requiredTab), 'present');
      expect(data.param(boundTab), 'all');
      expect(data.param(builtTab), 'list');
    });

    test('queryParam error includes query key and current data', () {
      const tab = RequiredUnboundQueryParam('tab', StringRouteParamCodec());
      final location = _QueryLocation(id: _TestId.query, parameter: tab);
      final boundTab = location.boundParameter;
      final data = _workingRouterData(
        uri: Uri(path: '/query', queryParameters: {'filter': 'active'}),
        routeNodes: [location].toIList(),
        activeOverlaysByOwner: IMap(),
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
      const tab = RequiredUnboundQueryParam('tab', StringRouteParamCodec());
      const filter = RequiredUnboundQueryParam(
        'filter',
        StringRouteParamCodec(),
      );
      final location = _QueryLocation(id: _TestId.query, parameter: filter);
      final inactiveLocation = _QueryLocation(
        id: _TestId.query,
        parameter: tab,
      );
      final inactiveTab = inactiveLocation.boundParameter;
      final data = _workingRouterData(
        uri: Uri(path: '/query', queryParameters: {'tab': 'all'}),
        routeNodes: [location].toIList(),
        activeOverlaysByOwner: IMap(),
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
      'queryParam supports a null default with a non-null codec',
      () {
        const endDateTime = DefaultUnboundQueryParam<DateTime?>(
          'endDateTime',
          DateTimeIsoRouteParamCodec(),
          defaultValue: null,
        );
        final location = _NullableQueryLocation(
          id: _TestId.queryNullable,
          parameter: endDateTime,
        );
        final boundEndDateTime = location.boundParameter;
        final data = _workingRouterData(
          uri: Uri(path: '/query'),
          routeNodes: [location].toIList(),
          activeOverlaysByOwner: IMap(),
          pathParameters: IMap(),
          queryParameters: IMap(),
        );

        expect(data.param(boundEndDateTime), isNull);
      },
    );

    test('paramOrNull returns active values for unbound params only', () {
      const itemId = UnboundPathParam(StringRouteParamCodec());
      const tab = DefaultUnboundQueryParam(
        'tab',
        StringRouteParamCodec(),
        defaultValue: 'all',
      );
      final list = _TestLocation(id: _TestId.list, path: '/items');
      final detail = _BoundParamLocation(
        id: _TestId.bound,
        pathParameter: itemId,
        queryParameter: tab,
      );
      final data = _workingRouterData(
        uri: Uri(path: '/items/123'),
        routeNodes: <RouteNode>[list, detail].toIList(),
        activeOverlaysByOwner: IMap(),
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
      return _workingRouterData(
        uri: Uri(path: '/parent/child'),
        routeNodes: locations.cast<RouteNode>().toIList(),
        activeOverlaysByOwner: IMap(),
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
        final data = _workingRouterData(
          uri: Uri(path: '/accounts/detail'),
          routeNodes: <RouteNode>[accountsNode, detail].toIList(),
          activeOverlaysByOwner: IMap(),
          pathParameters: IMap(),
          queryParameters: IMap(),
        );

        expect(
          data.routeNodes,
          orderedEquals([accountsNode, detail]),
        );
        expect(data.isTypeMatched<_AccountsNode>(), isTrue);
        expect(
          data.isMatched(
            (node) => node is _TestLocation && node.id == _TestId.detail,
          ),
          isTrue,
        );
        expect(data.leaf, same(detail));
      },
    );

    test('isIdMatched includes structural route node ids', () {
      final accountsNode = _AccountsNode(id: _TestId.accounts);
      final detail = _TestLocation(id: _TestId.detail, path: '/detail');
      final data = _workingRouterData(
        uri: Uri(path: '/accounts/detail'),
        routeNodes: <RouteNode>[accountsNode, detail].toIList(),
        activeOverlaysByOwner: IMap(),
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
      final data = _workingRouterData(
        uri: Uri(path: '/parent/child'),
        routeNodes: [root, parent, child].toIList(),
        activeOverlaysByOwner: IMap(),
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
      final data = _workingRouterData(
        uri: Uri(path: '/add-account'),
        routeNodes: <RouteNode>[root, addAccount].toIList(),
        activeOverlaysByOwner: IMap(),
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.leafWithId(_typedAddAccountId), same(addAccount));
      expect(data.leafWithId(_typedRootId), isNull);
      expect(data.lastMatchedWithId(_typedRootId), same(root));
      expect(data.lastMatchedWithId(_typedAddAccountId), same(addAccount));
    });

    test('overlay helpers use declaration order without affecting leaf', () {
      final first = _BranchOverlay(id: _firstOverlayId);
      final second = _BranchOverlay(id: _secondOverlayId);
      final owner = _BranchOwnerLocation(
        first: first,
        second: second,
      );
      final data = _workingRouterData(
        uri: Uri(path: '/owner'),
        routeNodes: <RouteNode>[owner].toIList(),
        activeOverlaysByOwner: {
          owner: <AnyOverlay>[first, second].toIList(),
        }.lock,
        pathParameters: IMap(),
        queryParameters: IMap(),
      );

      expect(data.leaf, same(owner));
      expect(data.leaf, isNot(same(first)));
      expect(data.leaf, isNot(same(second)));
      expect(data.lastMatched<_BranchOverlay>(), same(second));
      expect(data.isIdMatched(_firstOverlayId), isTrue);
      expect(data.isIdMatched(_secondOverlayId), isTrue);
    });
  });
}

class _TestLocation extends Location<_TestLocation> {
  final List<PathSegment> _segments;

  _TestLocation({required RouteNodeId<_TestLocation> id, required String path})
    : _segments = _pathSegments(path),
      super(id: id);

  @override
  void build(LocationBuilder builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
  }
}

class _ParamOnlyLocation extends Location<_ParamOnlyLocation> {
  final UnboundPathParam<String> parameter;
  late final PathParam<String> boundParameter =
      definition.pathParameters.single as PathParam<String>;

  _ParamOnlyLocation({
    required RouteNodeId<_ParamOnlyLocation> id,
    required this.parameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindParam(parameter);
  }
}

class _QueryLocation extends Location<_QueryLocation> {
  final UnboundQueryParam<String> parameter;
  late final QueryParam<String> boundParameter =
      definition.queryParameters.single as QueryParam<String>;

  _QueryLocation({
    required RouteNodeId<_QueryLocation> id,
    required this.parameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindParam(parameter);
  }
}

class _NullableQueryLocation extends Location<_NullableQueryLocation> {
  final UnboundQueryParam<DateTime?> parameter;
  late final QueryParam<DateTime?> boundParameter =
      definition.queryParameters.single as QueryParam<DateTime?>;

  _NullableQueryLocation({
    required RouteNodeId<_NullableQueryLocation> id,
    required this.parameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindParam(parameter);
  }
}

class _DefaultQueryLocation extends Location<_DefaultQueryLocation> {
  final DefaultUnboundQueryParam<String> parameter;
  late final DefaultQueryParam<String> boundParameter =
      definition.queryParameters.single as DefaultQueryParam<String>;

  _DefaultQueryLocation({
    required RouteNodeId<_DefaultQueryLocation> id,
    required this.parameter,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.bindDefaultQueryParam(parameter);
  }
}

class _BuilderDefaultQueryLocation
    extends Location<_BuilderDefaultQueryLocation> {
  late final DefaultQueryParam<String> boundParameter =
      definition.queryParameters.single as DefaultQueryParam<String>;

  _BuilderDefaultQueryLocation({
    required RouteNodeId<_BuilderDefaultQueryLocation> id,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.defaultStringQueryParam(
      'display',
      defaultValue: 'list',
    );
  }
}

class _BuilderRequiredQueryLocation
    extends Location<_BuilderRequiredQueryLocation> {
  late final RequiredQueryParam<String> boundParameter =
      definition.queryParameters.single as RequiredQueryParam<String>;

  _BuilderRequiredQueryLocation({
    required RouteNodeId<_BuilderRequiredQueryLocation> id,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.stringQueryParam('required');
  }
}

class _NoIdSegmentLocation extends Location<_NoIdSegmentLocation> {
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

class _BoundParamLocation extends Location<_BoundParamLocation> {
  final UnboundPathParam<String> pathParameter;
  final UnboundQueryParam<String> queryParameter;

  _BoundParamLocation({
    required RouteNodeId<_BoundParamLocation> id,
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

class _TypedRootLocation extends Location<_TypedRootLocation> {
  _TypedRootLocation() : super(id: _typedRootId);

  @override
  void build(LocationBuilder builder) {}
}

class _TypedAddAccountLocation extends Location<_TypedAddAccountLocation> {
  _TypedAddAccountLocation() : super(id: _typedAddAccountId);

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('add-account');
  }
}

class _BranchOwnerLocation extends Location<_BranchOwnerLocation> {
  final _BranchOverlay first;
  final _BranchOverlay second;

  _BranchOwnerLocation({
    required this.first,
    required this.second,
  }) : super(id: _branchOwnerId);

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('owner');
    builder.overlays = [first, second];
  }
}

class _BranchOverlay extends AbstractOverlay<_BranchOverlay> {
  _BranchOverlay({required super.id});

  @override
  void build(OverlayBuilder builder) {
    builder.conditions = const [];
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
