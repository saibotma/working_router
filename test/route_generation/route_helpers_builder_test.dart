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
  _RootLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [];
}

class _ItemLocation extends Location<AppRouteId> {
  _ItemLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => [
    PathSegment.literal('item'),
    PathSegment.param<String>('id', codec: StringRouteParamCodec(),
    ),
  ];

  @override
  get queryParameters => const {
    'keep': QueryParamConfig(StringRouteParamCodec()),
  };
}

class _ItemDetailsLocation extends Location<AppRouteId> {
  _ItemDetailsLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [PathSegment.literal('details')];

  @override
  get queryParameters => const {
    'detail': QueryParamConfig(StringRouteParamCodec()),
  };
}

List<Location<AppRouteId>> buildItemChildren() => [
  _ItemDetailsLocation(
    id: AppRouteId.itemDetails,
    children: const [],
  ),
];

final _appLocationTree = _RootLocation(
  id: AppRouteId.root,
  children: [
    _ItemLocation(
      id: AppRouteId.item,
      children: [
        ...buildItemChildren(),
      ],
    ),
  ],
);

@WorkingRouterLocationTree()
Location<AppRouteId> get appLocationTree => _appLocationTree;
''',
      },
      outputs: {
        'working_router|lib/app_routes.working_router.g.part': decodedMatches(
          allOf(
            allOf(
              contains('extension AppLocationTreeGeneratedRoutes'),
              contains('void routeToRoot()'),
              contains(
                'void routeToItem({required String id, required String keep}) {',
              ),
              contains(
                'void routeToChildItem({required String id, required String keep}) {',
              ),
              contains('routeToChild<_ItemLocation>('),
              contains("StringRouteParamCodec().encode(id)"),
            ),
            allOf(
              contains(
                'void routeToItemDetails({\n'
                '    required String id,\n'
                '    required String keep,\n'
                '    required String detail,\n'
                '  }) {',
              ),
              contains(
                'void routeToChildItemDetails({required String detail}) {',
              ),
              contains('routeToChild<_ItemDetailsLocation>('),
              contains("StringRouteParamCodec().encode(keep)"),
              contains("StringRouteParamCodec().encode(detail)"),
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
  _RootLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [];
}

class _ChildLocation extends Location<StaticRouteId> {
  _ChildLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [PathSegment.literal('child')];
}

class AppRoutes {
  static final _tree = _RootLocation(
    id: StaticRouteId.root,
    children: [
      _ChildLocation(id: StaticRouteId.child),
    ],
  );

  static Location<StaticRouteId> get tree => _tree;
}

@WorkingRouterLocationTree()
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
    'supports static children declared inside the location constructor',
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
  RootLocation() : super(children: [LessonLocation(id: ConstructorRouteId.lesson)]);

  @override
  List<PathSegment> get path => const [];
}

class LessonLocation extends Location<ConstructorRouteId> {
  LessonLocation({required super.id})
      : super(children: [LessonEditLocation(id: ConstructorRouteId.lessonEdit)]);

  @override
  List<PathSegment> get path => const [PathSegment.literal('lessons')];

  @override
  get queryParameters => const {
    'coursePeriodId': QueryParamConfig(StringRouteParamCodec()),
    'sourceDateTime': QueryParamConfig(StringRouteParamCodec()),
  };
}

class LessonEditLocation extends Location<ConstructorRouteId> {
  LessonEditLocation({required super.id});

  @override
  List<PathSegment> get path => const [PathSegment.literal('edit')];
}

@WorkingRouterLocationTree()
final Location<ConstructorRouteId> appLocationTree = RootLocation();
''',
        },
        outputs: {
          'working_router|lib/constructor_children_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToLesson({'),
                  contains("StringRouteParamCodec().encode(coursePeriodId)"),
                  contains("StringRouteParamCodec().encode(sourceDateTime)"),
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
  List<PathSegment> get path => const [PathSegment.literal('lessons')];

  @override
  get queryParameters => const {
    coursePeriodIdKey: QueryParamConfig(StringRouteParamCodec()),
    sourceDateTimeKey: QueryParamConfig(StringRouteParamCodec()),
  };
}

@WorkingRouterLocationTree()
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
  ItemLocation({required super.id});

  @override
  List<PathSegment> get path => [
    PathSegment.literal('items'),
    PathSegment.param<int>('itemId', codec: IntRouteParamCodec(),
    ),
  ];

  @override
  get queryParameters => const {
    'filter': QueryParamConfig(
      EnumNameRouteParamCodec(ItemFilter.values),
    ),
    'page': QueryParamConfig(
      IntRouteParamCodec(),
      optional: true,
    ),
  };
}

@WorkingRouterLocationTree()
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
                    contains("IntRouteParamCodec().encode(itemId)"),
                    contains(
                      "EnumNameRouteParamCodec(ItemFilter.values).encode(filter)",
                    ),
                    contains(
                      "if (page != null) 'page': IntRouteParamCodec().encode(page)",
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
  ChatChannelLocation({super.id})
      : super(
          children: [
            ChatChannelSendLocation(
              id: id != null ? DerivedChildRouteId.chatChannelSend : null,
            ),
          ],
        );

  @override
  List<PathSegment> get path => [
    PathSegment.literal('channels'),
    PathSegment.param<String>('channelId', codec: StringRouteParamCodec(),
    ),
  ];
}

class ChatChannelSendLocation extends Location<DerivedChildRouteId> {
  ChatChannelSendLocation({super.id});

  @override
  List<PathSegment> get path => const [PathSegment.literal('send')];
}

@WorkingRouterLocationTree()
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
  RootLocation()
      : super(
          id: IfUnionRouteId.root,
          children: [
            _ChildLocation(
              id: IfUnionRouteId.always,
              path: [PathSegment.literal('always')],
            ),
            if (includeMaybe)
              _ChildLocation(
                id: IfUnionRouteId.maybe,
                path: [PathSegment.literal('maybe')],
              ),
            if (includeSpread) ...[
              _ChildLocation(
                id: IfUnionRouteId.maybeSpread,
                path: [PathSegment.literal('spread')],
              ),
            ],
            if (includeMaybe)
              _ChildLocation(
                id: IfUnionRouteId.maybeElseA,
                path: [PathSegment.literal('else-a')],
              )
            else
              _ChildLocation(
                id: IfUnionRouteId.maybeElseB,
                path: [PathSegment.literal('else-b')],
              ),
          ],
        );

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

@WorkingRouterLocationTree()
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
  RootLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [];
}

class ChatLocation extends Location<ParameterizedRouteId> {
  ChatLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [PathSegment.literal('chat')];
}

class ChatSearchLocation extends Location<ParameterizedRouteId> {
  ChatSearchLocation({
    required ParameterizedRouteId id,
    List<Location<ParameterizedRouteId>> children = const [],
  }) : super(id: id, children: children);

  @override
  List<PathSegment> get path => const [PathSegment.literal('search')];
}

class ChatChannelLocation extends Location<ParameterizedRouteId> {
  ChatChannelLocation({super.id, super.children = const []});

  @override
  List<PathSegment> get path => [
    PathSegment.literal('channels'),
    PathSegment.param<String>('channelId', codec: StringRouteParamCodec(),
    ),
  ];
}

class ChatChannelSendLocation extends Location<ParameterizedRouteId> {
  ChatChannelSendLocation({super.id});

  @override
  List<PathSegment> get path => const [PathSegment.literal('send')];
}

class ExtraLocation extends Location<ParameterizedRouteId> {
  ExtraLocation();

  @override
  List<PathSegment> get path => const [PathSegment.literal('extra')];
}

@WorkingRouterLocationTree()
Location<ParameterizedRouteId> buildLocationTree({
  required Permissions permissions,
}) {
  List<Location<ParameterizedRouteId>> sharedChatLocations({
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
  RootLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [];
}

class SearchLocation extends Location<AliasedChildrenRouteId> {
  SearchLocation({
    required AliasedChildrenRouteId id,
    List<Location<AliasedChildrenRouteId>> children = const [],
  }) : super(id: id, children: children);

  @override
  List<PathSegment> get path => const [PathSegment.literal('search')];
}

class LeafLocation extends Location<AliasedChildrenRouteId> {
  LeafLocation({required super.id});

  @override
  List<PathSegment> get path => const [PathSegment.literal('leaf')];
}

@WorkingRouterLocationTree()
Location<AliasedChildrenRouteId> buildLocationTree() {
  List<Location<AliasedChildrenRouteId>> buildSearchBranch({
    required List<Location<AliasedChildrenRouteId>> children,
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
  RootLocation({required super.id, super.children = const []});

  @override
  List<PathSegment> get path => const [];
}

class ParentLocation extends Location<DefaultForwardedChildrenRouteId> {
  ParentLocation({required super.id, super.children});

  @override
  List<PathSegment> get path => const [PathSegment.literal('parent')];
}

class BranchLocation extends Location<DefaultForwardedChildrenRouteId> {
  BranchLocation({required super.id})
    : super(children: [LeafLocation(id: DefaultForwardedChildrenRouteId.leaf)]);

  @override
  List<PathSegment> get path => const [PathSegment.literal('branch')];
}

class LeafLocation extends Location<DefaultForwardedChildrenRouteId> {
  LeafLocation({
    required DefaultForwardedChildrenRouteId id,
    List<Location<DefaultForwardedChildrenRouteId>> children = const [],
  }) : super(id: id, children: children);

  @override
  List<PathSegment> get path => const [PathSegment.literal('leaf')];
}

@WorkingRouterLocationTree()
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
}
