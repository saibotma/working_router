import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:working_router/src/route_generation/builder.dart';

void main() {
  test('generates routeToX helpers from a static location tree', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions(const {}),
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/app_routes.dart': '''
library app_routes;

import 'package:working_router/working_router.dart';

part 'app_routes.working_router.g.dart';

enum AppRouteId { root, item, itemDetails }

class _RootLocation extends Location<AppRouteId> {
  _RootLocation({required super.id});

  @override
  late final List<RouteNode<AppRouteId>> children = [
    _ItemLocation(id: AppRouteId.item),
  ];

  @override
  List<PathSegment> get path => const [];
}

class _ItemLocation extends Location<AppRouteId> {
  final itemId = pathParam(const StringRouteParamCodec());

  _ItemLocation({required super.id});

  @override
  late final List<RouteNode<AppRouteId>> children = [
    ...buildItemChildren(),
  ];

  @override
  List<PathSegment> get path => [
    literal('item'),
    itemId,
  ];

  @override
  get queryParameters => const [
    QueryParam('keep', StringRouteParamCodec()),
  ];
}

class _ItemDetailsLocation extends Location<AppRouteId> {
  _ItemDetailsLocation({required super.id});

  @override
  List<PathSegment> get path => [literal('details')];

  @override
  get queryParameters => const [
    QueryParam('detail', StringRouteParamCodec()),
  ];
}

List<RouteNode<AppRouteId>> buildItemChildren() => [
  _ItemDetailsLocation(
    id: AppRouteId.itemDetails,
  ),
];

final _appLocationTree = _RootLocation(id: AppRouteId.root);

@RouteNodes()
Location<AppRouteId> get appLocationTree => _appLocationTree;
''',
      },
      outputs: {
        'working_router|lib/app_routes.working_router.g.part': decodedMatches(
          allOf(
            allOf(
              allOf(
                contains(
                  'final class ItemRouteTarget extends IdRouteTarget<AppRouteId> {',
                ),
                contains(
                  'final class ChildItemRouteTarget extends ChildRouteTarget<AppRouteId> {',
                ),
                contains('extension AppLocationTreeGeneratedRoutes'),
                contains('void routeToRoot()'),
                contains(
                  'void routeToItem({required String itemId, required String keep}) {',
                ),
              ),
              allOf(
                contains(
                  'void routeToChildItem({required String itemId, required String keep}) {',
                ),
                contains(
                  'routeTo(ItemRouteTarget(itemId: itemId, keep: keep));',
                ),
                contains(
                  'routeTo(ChildItemRouteTarget(itemId: itemId, keep: keep));',
                ),
                contains('writePathParameters: (() {'),
                contains('path(location.itemId, itemId);'),
              ),
            ),
            allOf(
              contains(
                'void routeToItemDetails({\n'
                '    required String itemId,\n'
                '    required String keep,\n'
                '    required String detail,\n'
                '  }) {',
              ),
              contains(
                'void routeToChildItemDetails({required String detail}) {',
              ),
              contains(
                'final class ChildItemDetailsRouteTarget extends ChildRouteTarget<AppRouteId> {',
              ),
              contains(
                'routeTo(ChildItemDetailsRouteTarget(detail: detail));',
              ),
              contains('queryParameters: {'),
              contains("'keep': StringRouteParamCodec().encode(keep),"),
              contains(
                "'detail': StringRouteParamCodec().encode(detail),",
              ),
            ),
          ),
        ),
      },
      readerWriter: readerWriter,
    );
  });

  test('strips Param and Parameter suffixes from generated path names', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions(const {}),
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/param_suffix_routes.dart': '''
library param_suffix_routes;

import 'package:working_router/working_router.dart';

part 'param_suffix_routes.g.dart';

enum ParamSuffixRouteId { root, detail }

class RootLocation extends Location<ParamSuffixRouteId> {
  RootLocation();

  @override
  late final List<RouteNode<ParamSuffixRouteId>> children = [
    DetailLocation(id: ParamSuffixRouteId.detail),
  ];

  @override
  List<PathSegment> get path => const [];
}

class DetailLocation extends Location<ParamSuffixRouteId> {
  final idParam = pathParam(const StringRouteParamCodec());
  final slugParameter = pathParam(const StringRouteParamCodec());

  DetailLocation({required super.id});

  @override
  List<PathSegment> get path => [
    literal('detail'),
    idParam,
    slugParameter,
  ];
}

@RouteNodes()
Location<ParamSuffixRouteId> get appLocationTree => RootLocation();
''',
      },
      outputs: {
        'working_router|lib/param_suffix_routes.working_router.g.part':
            decodedMatches(
              allOf(
                contains(
                  'void routeToDetail({required String id, required String slug}) {',
                ),
                contains(
                  'DetailRouteTarget({required String id, required String slug})',
                ),
                contains('path(location.idParam, id);'),
                contains('path(location.slugParameter, slug);'),
              ),
            ),
      },
      readerWriter: readerWriter,
    );
  });

  test('supports inline DSL child locations with generated params', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions(const {}),
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/dsl_field_params_routes.dart': '''
library dsl_field_params_routes;

import 'package:working_router/working_router.dart';

part 'dsl_field_params_routes.g.dart';

enum FieldDslRouteId { root, item }

class RootLocation extends Location<FieldDslRouteId> {
  RootLocation();

  @override
  void build(LocationBuilder<FieldDslRouteId> builder) {
    builder.legacy();
    builder.location((builder) {
      builder.id(FieldDslRouteId.item);
      builder.pathLiteral('item');
      final itemId = builder.pathParam(const StringRouteParamCodec());
      final keep = builder.queryParam('keep', const StringRouteParamCodec());
      builder.legacy();
    });
  }
}

@RouteNodes()
Location<FieldDslRouteId> get appLocationTree => RootLocation();
''',
      },
      outputs: {
        'working_router|lib/dsl_field_params_routes.working_router.g.part': decodedMatches(
          allOf(
            contains(
              'void routeToItem({required String itemId, required String keep}) {',
            ),
            contains(
              'ItemRouteTarget({required String itemId, required String keep})',
            ),
            contains(
              'path(location.pathParameters[0] as PathParam<String>, itemId);',
            ),
            contains(
              "queryParameters: {'keep': const StringRouteParamCodec().encode(keep)}",
            ),
          ),
        ),
      },
      readerWriter: readerWriter,
    );
  });

  test('supports static helper declarations inside tree composition', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions(const {}),
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/static_routes.dart': '''
library static_routes;

import 'package:working_router/working_router.dart';

part 'static_routes.g.dart';

enum StaticRouteId { root, child }

class _RootLocation extends Location<StaticRouteId> {
  _RootLocation({required super.id});

  @override
  late final List<RouteNode<StaticRouteId>> children = [
    _ChildLocation(id: StaticRouteId.child),
  ];

  @override
  List<PathSegment> get path => const [];
}

class _ChildLocation extends Location<StaticRouteId> {
  _ChildLocation({required super.id});

  @override
  List<PathSegment> get path => [literal('child')];
}

class AppRoutes {
  static final _tree = _RootLocation(
    id: StaticRouteId.root,
  );

  static Location<StaticRouteId> get tree => _tree;
}

@RouteNodes()
Location<StaticRouteId> get appLocationTree => AppRoutes.tree;
''',
      },
      outputs: {
        'working_router|lib/static_routes.working_router.g.part':
            decodedMatches(
              allOf(
                contains('extension AppLocationTreeGeneratedRoutes'),
                contains('void routeToRoot()'),
                contains('void routeToChildChild()'),
              ),
            ),
      },
      readerWriter: readerWriter,
    );
  });

  test(
    'supports children declared on the location instance',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/constructor_children_routes.dart': '''
library constructor_children_routes;

import 'package:working_router/working_router.dart';

part 'constructor_children_routes.g.dart';

enum ConstructorRouteId { root, lesson, lessonEdit }

class RootLocation extends Location<ConstructorRouteId> {
  RootLocation();

  @override
  late final List<RouteNode<ConstructorRouteId>> children = [
    LessonLocation(id: ConstructorRouteId.lesson),
  ];

  @override
  List<PathSegment> get path => const [];
}

class LessonLocation extends Location<ConstructorRouteId> {
  LessonLocation({required super.id});

  @override
  late final List<RouteNode<ConstructorRouteId>> children = [
    LessonEditLocation(id: ConstructorRouteId.lessonEdit),
  ];

  @override
  List<PathSegment> get path => [literal('lessons')];

  @override
  get queryParameters => const [
    QueryParam('coursePeriodId', StringRouteParamCodec()),
    QueryParam('sourceDateTime', StringRouteParamCodec()),
  ];
}

class LessonEditLocation extends Location<ConstructorRouteId> {
  LessonEditLocation({required super.id});

  @override
  List<PathSegment> get path => [literal('edit')];
}

@RouteNodes()
final Location<ConstructorRouteId> appLocationTree = RootLocation();
''',
        },
        outputs: {
          'working_router|lib/constructor_children_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToLesson({'),
                  contains('queryParameters: {'),
                  contains(
                    "'coursePeriodId': StringRouteParamCodec().encode(coursePeriodId),",
                  ),
                  contains(
                    "'sourceDateTime': StringRouteParamCodec().encode(sourceDateTime),",
                  ),
                  contains('void routeToLessonEdit({'),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test('supports const string identifiers in query parameter sets', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions(const {}),
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/const_query_routes.dart': '''
library const_query_routes;

import 'package:working_router/working_router.dart';

part 'const_query_routes.g.dart';

enum ConstQueryRouteId { lesson }

const coursePeriodIdKey = 'coursePeriodId';
const sourceDateTimeKey = 'sourceDateTime';

class LessonLocation extends Location<ConstQueryRouteId> {
  LessonLocation({required super.id});

  @override
  List<PathSegment> get path => [literal('lessons')];

  @override
  get queryParameters => const [
    QueryParam(coursePeriodIdKey, StringRouteParamCodec()),
    QueryParam(sourceDateTimeKey, StringRouteParamCodec()),
  ];
}

@RouteNodes()
final Location<ConstQueryRouteId> appLocationTree =
    LessonLocation(id: ConstQueryRouteId.lesson);
''',
      },
      outputs: {
        'working_router|lib/const_query_routes.working_router.g.part':
            decodedMatches(
              allOf(
                contains('void routeToLesson({'),
                contains("required String coursePeriodId,"),
                contains("required String sourceDateTime,"),
              ),
            ),
      },
      readerWriter: readerWriter,
    );
  });

  test(
    'generates typed and optional parameters from codecs',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/typed_route_params_routes.dart': '''
library typed_route_params_routes;

import 'package:working_router/working_router.dart';

part 'typed_route_params_routes.g.dart';

enum TypedRouteId { item }
enum ItemFilter { all, active }

class ItemLocation extends Location<TypedRouteId> {
  final itemId = pathParam(const IntRouteParamCodec());

  ItemLocation({required super.id});

  @override
  List<PathSegment> get path => [
    literal('items'),
    itemId,
  ];

  @override
  get queryParameters => const [
    QueryParam(
      'filter',
      EnumNameRouteParamCodec(ItemFilter.values),
    ),
    QueryParam(
      'page',
      IntRouteParamCodec(),
      optional: true,
    ),
  ];
}

@RouteNodes()
final Location<TypedRouteId> appLocationTree =
    ItemLocation(id: TypedRouteId.item);
''',
        },
        outputs: {
          'working_router|lib/typed_route_params_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  allOf(
                    contains('required int itemId,'),
                    contains('required ItemFilter filter,'),
                    contains('int? page,'),
                  ),
                  allOf(
                    contains(
                      'final class ItemRouteTarget extends IdRouteTarget<TypedRouteId> {',
                    ),
                    contains('writePathParameters: (() {'),
                    contains('path(location.itemId, itemId);'),
                    contains('queryParameters: {'),
                    contains(
                      "'filter': EnumNameRouteParamCodec(ItemFilter.values).encode(filter),",
                    ),
                    contains(
                      "if (page != null) 'page': IntRouteParamCodec().encode(page),",
                    ),
                  ),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'uses explicit query parameter names from QueryParam fields',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/inferred_query_param_routes.dart': '''
library inferred_query_param_routes;

import 'package:working_router/working_router.dart';

part 'inferred_query_param_routes.g.dart';

enum InferredQueryParamRouteId { item }
enum ItemFilter { all, active }

class ItemLocation extends Location<InferredQueryParamRouteId> {
  final itemId = pathParam(const IntRouteParamCodec());
  final filterParam = queryParam(
    'filter',
    EnumNameRouteParamCodec(ItemFilter.values),
  );
  final pageParam = queryParam(
    'page',
    IntRouteParamCodec(),
    optional: true,
  );

  ItemLocation({required super.id});

  @override
  List<PathSegment> get path => [
    literal('items'),
    itemId,
  ];

  @override
  List<QueryParam<dynamic>> get queryParameters => [filterParam, pageParam];
}

@RouteNodes()
final Location<InferredQueryParamRouteId> appLocationTree =
    ItemLocation(id: InferredQueryParamRouteId.item);
''',
        },
        outputs: {
          'working_router|lib/inferred_query_param_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToItem({'),
                  contains('required int itemId,'),
                  contains('required ItemFilter filter,'),
                  contains('int? page,'),
                  isNot(contains('ItemLocationGenerated')),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'supports child ids derived from whether the parent id is null',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/derived_child_ids_routes.dart': '''
library derived_child_ids_routes;

import 'package:working_router/working_router.dart';

part 'derived_child_ids_routes.g.dart';

enum DerivedChildRouteId { chatChannel, chatChannelSend }

class ChatChannelLocation extends Location<DerivedChildRouteId> {
  final channelId = pathParam(const StringRouteParamCodec());

  ChatChannelLocation({super.id});

  @override
  late final List<RouteNode<DerivedChildRouteId>> children = [
    ChatChannelSendLocation(
      id: id != null ? DerivedChildRouteId.chatChannelSend : null,
    ),
  ];

  @override
  List<PathSegment> get path => [
    literal('channels'),
    channelId,
  ];
}

class ChatChannelSendLocation extends Location<DerivedChildRouteId> {
  ChatChannelSendLocation({super.id});

  @override
  List<PathSegment> get path => [literal('send')];
}

@RouteNodes()
final Location<DerivedChildRouteId> appLocationTree =
    ChatChannelLocation(id: DerivedChildRouteId.chatChannel);
''',
        },
        outputs: {
          'working_router|lib/derived_child_ids_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains(
                    'void routeToChatChannel({required String channelId}) {',
                  ),
                  contains(
                    'void routeToChatChannelSend({required String channelId}) {',
                  ),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'treats collection if branches as part of the generated route union',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/if_union_routes.dart': '''
library if_union_routes;

import 'package:working_router/working_router.dart';

part 'if_union_routes.g.dart';

enum IfUnionRouteId { root, always, maybe, maybeSpread, maybeElseA, maybeElseB }

bool get includeMaybe => throw UnimplementedError();
bool get includeSpread => throw UnimplementedError();

class RootLocation extends Location<IfUnionRouteId> {
  RootLocation() : super(id: IfUnionRouteId.root);

  @override
  late final List<RouteNode<IfUnionRouteId>> children = [
    _ChildLocation(
      id: IfUnionRouteId.always,
      path: [literal('always')],
    ),
    if (includeMaybe)
      _ChildLocation(
        id: IfUnionRouteId.maybe,
        path: [literal('maybe')],
      ),
    if (includeSpread) ...[
      _ChildLocation(
        id: IfUnionRouteId.maybeSpread,
        path: [literal('spread')],
      ),
    ],
    if (includeMaybe)
      _ChildLocation(
        id: IfUnionRouteId.maybeElseA,
        path: [literal('else-a')],
      )
    else
      _ChildLocation(
        id: IfUnionRouteId.maybeElseB,
        path: [literal('else-b')],
      ),
  ];

  @override
  List<PathSegment> get path => const [];
}

class _ChildLocation extends Location<IfUnionRouteId> {
  final List<PathSegment> _path;

  _ChildLocation({required super.id, required List<PathSegment> path})
      : _path = path;

  @override
  List<PathSegment> get path => _path;
}

@RouteNodes()
Location<IfUnionRouteId> buildLocationTree() => RootLocation();
''',
        },
        outputs: {
          'working_router|lib/if_union_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToAlways()'),
                  contains('void routeToMaybe()'),
                  contains('void routeToMaybeSpread()'),
                  contains('void routeToMaybeElseA()'),
                  contains('void routeToMaybeElseB()'),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'supports parameterized annotated builders, local helper functions, and forwarded children parameters',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/parameterized_builder_routes.dart': '''
library parameterized_builder_routes;

import 'package:working_router/working_router.dart';

part 'parameterized_builder_routes.g.dart';

enum ParameterizedRouteId { root, chat, channel, channelSend, search }

class Permissions {
  final bool maySeeExtra;

  const Permissions({required this.maySeeExtra});
}

class RootLocation extends Location<ParameterizedRouteId> {
  @override
  final List<RouteNode<ParameterizedRouteId>> children;

  RootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class ChatLocation extends Location<ParameterizedRouteId> {
  @override
  final List<RouteNode<ParameterizedRouteId>> children;

  ChatLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => [literal('chat')];
}

class ChatSearchLocation extends Location<ParameterizedRouteId> {
  @override
  final List<RouteNode<ParameterizedRouteId>> children;

  ChatSearchLocation({
    required ParameterizedRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [literal('search')];
}

class ChatChannelLocation extends Location<ParameterizedRouteId> {
  final channelId = pathParam(const StringRouteParamCodec());

  @override
  final List<RouteNode<ParameterizedRouteId>> children;

  ChatChannelLocation({
    super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => [
    literal('channels'),
    channelId,
  ];
}

class ChatChannelSendLocation extends Location<ParameterizedRouteId> {
  ChatChannelSendLocation({super.id});

  @override
  List<PathSegment> get path => [literal('send')];
}

class ExtraLocation extends Location<ParameterizedRouteId> {
  ExtraLocation();

  @override
  List<PathSegment> get path => [literal('extra')];
}

@RouteNodes()
Location<ParameterizedRouteId> buildLocationTree({
  required Permissions permissions,
}) {
  List<RouteNode<ParameterizedRouteId>> sharedChatLocations({
    required bool shouldSetIds,
  }) {
    return [
      ChatChannelLocation(
        id: shouldSetIds ? ParameterizedRouteId.channel : null,
        children: [
          ChatChannelSendLocation(
            id: shouldSetIds ? ParameterizedRouteId.channelSend : null,
          ),
        ],
      ),
    ];
  }

  return RootLocation(
    id: ParameterizedRouteId.root,
    children: [
      ChatLocation(
        id: ParameterizedRouteId.chat,
        children: [
          ...sharedChatLocations(shouldSetIds: true),
          ChatSearchLocation(
            id: ParameterizedRouteId.search,
            children: sharedChatLocations(shouldSetIds: false),
          ),
          if (permissions.maySeeExtra) ExtraLocation(),
        ],
      ),
    ],
  );
}
''',
        },
        outputs: {
          'working_router|lib/parameterized_builder_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('extension BuildLocationTreeGeneratedRoutes'),
                  contains('void routeToRoot()'),
                  contains('void routeToChat()'),
                  contains(
                    'void routeToChannel({required String channelId}) {',
                  ),
                  contains(
                    'void routeToChannelSend({required String channelId}) {',
                  ),
                  contains('void routeToSearch()'),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'resolves aliased children through helper and constructor forwarding chains',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/aliased_children_routes.dart': '''
library aliased_children_routes;

import 'package:working_router/working_router.dart';

part 'aliased_children_routes.g.dart';

enum AliasedChildrenRouteId { root, search, leaf }

class RootLocation extends Location<AliasedChildrenRouteId> {
  @override
  final List<RouteNode<AliasedChildrenRouteId>> children;

  RootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class SearchLocation extends Location<AliasedChildrenRouteId> {
  @override
  final List<RouteNode<AliasedChildrenRouteId>> children;

  SearchLocation({
    required AliasedChildrenRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [literal('search')];
}

class LeafLocation extends Location<AliasedChildrenRouteId> {
  LeafLocation({required super.id});

  @override
  List<PathSegment> get path => [literal('leaf')];
}

@RouteNodes()
Location<AliasedChildrenRouteId> buildLocationTree() {
  List<RouteNode<AliasedChildrenRouteId>> buildSearchBranch({
    required List<RouteNode<AliasedChildrenRouteId>> children,
  }) {
    return [
      SearchLocation(
        id: AliasedChildrenRouteId.search,
        children: children,
      ),
    ];
  }

  return RootLocation(
    id: AliasedChildrenRouteId.root,
    children: [
      ...buildSearchBranch(
        children: [
          LeafLocation(id: AliasedChildrenRouteId.leaf),
        ],
      ),
    ],
  );
}
''',
        },
        outputs: {
          'working_router|lib/aliased_children_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToRoot()'),
                  contains('void routeToSearch()'),
                  contains('void routeToLeaf()'),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'resolves default forwarded children through nested constructor chains',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions(const {}),
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/default_forwarded_children_routes.dart': '''
library default_forwarded_children_routes;

import 'package:working_router/working_router.dart';

part 'default_forwarded_children_routes.g.dart';

enum DefaultForwardedChildrenRouteId { root, parent, branch, leaf }

class RootLocation extends Location<DefaultForwardedChildrenRouteId> {
  @override
  final List<RouteNode<DefaultForwardedChildrenRouteId>> children;

  RootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class ParentLocation extends Location<DefaultForwardedChildrenRouteId> {
  @override
  final List<RouteNode<DefaultForwardedChildrenRouteId>> children;

  ParentLocation({
    required super.id,
    required this.children,
  });

  @override
  List<PathSegment> get path => [literal('parent')];
}

class BranchLocation extends Location<DefaultForwardedChildrenRouteId> {
  BranchLocation({required super.id});

  @override
  late final List<RouteNode<DefaultForwardedChildrenRouteId>> children = [
    LeafLocation(id: DefaultForwardedChildrenRouteId.leaf),
  ];

  @override
  List<PathSegment> get path => [literal('branch')];
}

class LeafLocation extends Location<DefaultForwardedChildrenRouteId> {
  @override
  final List<RouteNode<DefaultForwardedChildrenRouteId>> children;

  LeafLocation({
    required DefaultForwardedChildrenRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [literal('leaf')];
}

@RouteNodes()
Location<DefaultForwardedChildrenRouteId> buildLocationTree() {
  return RootLocation(
    id: DefaultForwardedChildrenRouteId.root,
    children: [
      ParentLocation(
        id: DefaultForwardedChildrenRouteId.parent,
        children: [
          BranchLocation(id: DefaultForwardedChildrenRouteId.branch),
        ],
      ),
    ],
  );
}
''',
        },
        outputs: {
          'working_router|lib/default_forwarded_children_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToRoot()'),
                  contains('void routeToParent()'),
                  contains('void routeToBranch()'),
                  contains('void routeToLeaf()'),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test('supports shell-rooted route trees', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions(const {}),
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/shell_root_routes.dart': '''
library shell_root_routes;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

part 'shell_root_routes.g.dart';

enum ShellRootRouteId { child }

class ChildLocation extends Location<ShellRootRouteId> {
  ChildLocation({required super.id});

  @override
  List<PathSegment> get path => [literal('child')];
}

@RouteNodes()
RouteNode<ShellRootRouteId> get appLocationTree => Shell<ShellRootRouteId>(
  navigatorKey: GlobalKey<NavigatorState>(),
  build: (builder) {
    builder.buildWidget((context, data, child) => child);
    builder.location((builder) {
      builder.id(ShellRootRouteId.child);
      builder.pathLiteral('child');
      builder.legacy();
    });
  },
);
''',
      },
      outputs: {
        'working_router|lib/shell_root_routes.working_router.g.part':
            decodedMatches(
              allOf(
                contains('extension AppLocationTreeGeneratedRoutes'),
                contains('void routeToChild()'),
                contains('void routeToChildChild()'),
                contains(
                  'final class ChildChildRouteTarget extends ChildRouteTarget<ShellRootRouteId> {',
                ),
                contains('routeTo(ChildChildRouteTarget());'),
              ),
            ),
      },
      readerWriter: readerWriter,
    );
  });
}
