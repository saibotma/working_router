import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:working_router/src/route_generation/builder.dart';

void main() {
  test('generates routeToX helpers from a static location tree', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions.empty,
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

class _RootLocation extends Location<AppRouteId, _RootLocation> {
  _RootLocation({required super.id});

  @override
  late final List<LocationTreeElement<AppRouteId>> children = [
    _ItemLocation(id: AppRouteId.item),
  ];

  @override
  List<PathSegment> get path => const [];
}

class _ItemLocation extends Location<AppRouteId, _ItemLocation> {
  final itemId = PathParam(const StringRouteParamCodec());

  _ItemLocation({required super.id});

  @override
  late final List<LocationTreeElement<AppRouteId>> children = [
    ...buildItemChildren(),
  ];

  @override
  List<PathSegment> get path => [
    LiteralPathSegment('item'),
    itemId,
  ];

  @override
  get queryParameters => const [
    QueryParam('keep', StringRouteParamCodec()),
  ];
}

class _ItemDetailsLocation extends Location<AppRouteId, _ItemDetailsLocation> {
  _ItemDetailsLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('details')];

  @override
  get queryParameters => const [
    QueryParam('detail', StringRouteParamCodec()),
  ];
}

List<LocationTreeElement<AppRouteId>> buildItemChildren() => [
  _ItemDetailsLocation(
    id: AppRouteId.itemDetails,
  ),
];

final _appLocationTree = _RootLocation(id: AppRouteId.root);

@Locations()
LocationTreeElement<AppRouteId> get appLocationTree => _appLocationTree;
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
              ),
              allOf(
                contains('void routeToRoot()'),
                contains(
                  'void routeToItem({required String itemId, required String keep}) {',
                ),
                contains(
                  'void routeToChildItem({required String itemId, required String keep}) {',
                ),
              ),
              allOf(
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
              ),
              allOf(
                contains('queryParameters: {'),
                contains("'keep': StringRouteParamCodec().encode(keep),"),
                contains(
                  "'detail': StringRouteParamCodec().encode(detail),",
                ),
              ),
              allOf(
                contains(
                  'extension _ItemLocationGeneratedChildTargets on _ItemLocation {',
                ),
                contains(
                  'ChildRouteTarget<AppRouteId> childItemDetailsTarget({',
                ),
                contains(
                  'return ChildRouteTarget<AppRouteId>(',
                ),
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
      BuilderOptions.empty,
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

class RootLocation extends Location<ParamSuffixRouteId, RootLocation> {
  RootLocation();

  @override
  late final List<LocationTreeElement<ParamSuffixRouteId>> children = [
    DetailLocation(id: ParamSuffixRouteId.detail),
  ];

  @override
  List<PathSegment> get path => const [];
}

class DetailLocation extends Location<ParamSuffixRouteId, DetailLocation> {
  final idParam = PathParam(const StringRouteParamCodec());
  final slugParameter = PathParam(const StringRouteParamCodec());

  DetailLocation({required super.id});

  @override
  List<PathSegment> get path => [
    LiteralPathSegment('detail'),
    idParam,
    slugParameter,
  ];
}

@Locations()
LocationTreeElement<ParamSuffixRouteId> get appLocationTree => RootLocation();
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
      BuilderOptions.empty,
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

class RootLocation extends Location<FieldDslRouteId, RootLocation> {
  RootLocation();

  @override
  void build(
    LocationBuilder<FieldDslRouteId> builder,
  ) {
    builder.children = [
      ItemLocation(
        id: FieldDslRouteId.item,
        build: (builder, location) {
          builder.pathLiteral('item');
          final itemId = builder.stringPathParam();
          final keep = builder.stringQueryParam('keep');
        },
      ),
    ];
  }
}

class ItemLocation extends Location<FieldDslRouteId, ItemLocation> {
  ItemLocation({super.id, super.build});
}

@Locations()
LocationTreeElement<FieldDslRouteId> get appLocationTree => RootLocation();
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
      BuilderOptions.empty,
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

class _RootLocation extends Location<StaticRouteId, _RootLocation> {
  _RootLocation({required super.id});

  @override
  late final List<LocationTreeElement<StaticRouteId>> children = [
    _ChildLocation(id: StaticRouteId.child),
  ];

  @override
  List<PathSegment> get path => const [];
}

class _ChildLocation extends Location<StaticRouteId, _ChildLocation> {
  _ChildLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('child')];
}

class AppRoutes {
  static final _tree = _RootLocation(
    id: StaticRouteId.root,
  );

  static LocationTreeElement<StaticRouteId> get tree => _tree;
}

@Locations()
LocationTreeElement<StaticRouteId> get appLocationTree => AppRoutes.tree;
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
        BuilderOptions.empty,
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

class RootLocation extends Location<ConstructorRouteId, RootLocation> {
  RootLocation();

  @override
  late final List<LocationTreeElement<ConstructorRouteId>> children = [
    LessonLocation(id: ConstructorRouteId.lesson),
  ];

  @override
  List<PathSegment> get path => const [];
}

class LessonLocation extends Location<ConstructorRouteId, LessonLocation> {
  LessonLocation({required super.id});

  @override
  late final List<LocationTreeElement<ConstructorRouteId>> children = [
    LessonEditLocation(id: ConstructorRouteId.lessonEdit),
  ];

  @override
  List<PathSegment> get path => [LiteralPathSegment('lessons')];

  @override
  get queryParameters => const [
    QueryParam('coursePeriodId', StringRouteParamCodec()),
    QueryParam('sourceDateTime', StringRouteParamCodec()),
  ];
}

class LessonEditLocation
    extends Location<ConstructorRouteId, LessonEditLocation> {
  LessonEditLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('edit')];
}

@Locations()
final LocationTreeElement<ConstructorRouteId> appLocationTree = RootLocation();
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
      BuilderOptions.empty,
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

class LessonLocation extends Location<ConstQueryRouteId, LessonLocation> {
  LessonLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('lessons')];

  @override
  get queryParameters => const [
    QueryParam(coursePeriodIdKey, StringRouteParamCodec()),
    QueryParam(sourceDateTimeKey, StringRouteParamCodec()),
  ];
}

@Locations()
final LocationTreeElement<ConstQueryRouteId> appLocationTree =
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
        BuilderOptions.empty,
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

class ItemLocation extends Location<TypedRouteId, ItemLocation> {
  final itemId = PathParam(const IntRouteParamCodec());

  ItemLocation({required super.id});

  @override
  List<PathSegment> get path => [
    LiteralPathSegment('items'),
    itemId,
  ];

  @override
  get queryParameters => const [
    QueryParam(
      'filter',
      EnumRouteParamCodec(ItemFilter.values),
    ),
    QueryParam('page', IntRouteParamCodec(), defaultValue: Default(1)),
  ];
}

@Locations()
final LocationTreeElement<TypedRouteId> appLocationTree =
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
                      "'filter': EnumRouteParamCodec(ItemFilter.values).encode(filter),",
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
        BuilderOptions.empty,
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

class ItemLocation
    extends Location<InferredQueryParamRouteId, ItemLocation> {
  final itemId = PathParam(const IntRouteParamCodec());
  final filterParam = QueryParam(
    'filter',
    EnumRouteParamCodec(ItemFilter.values),
  );
  final pageParam = QueryParam(
    'page',
    IntRouteParamCodec(),
    defaultValue: Default(1),
  );

  ItemLocation({required super.id});

  @override
  List<PathSegment> get path => [
    LiteralPathSegment('items'),
    itemId,
  ];

  @override
  List<QueryParam<dynamic>> get queryParameters => [filterParam, pageParam];
}

@Locations()
final LocationTreeElement<InferredQueryParamRouteId> appLocationTree =
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
    'supports uri and enum param shortcut methods in the DSL',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/shortcut_param_routes.dart': '''
library shortcut_param_routes;

import 'package:working_router/working_router.dart';

part 'shortcut_param_routes.g.dart';

enum ShortcutRouteId { item }
enum ItemFilter { all, active }

class ItemLocation extends Location<ShortcutRouteId, ItemLocation> {
  ItemLocation({
    required super.id,
    required super.build,
  });
}

@Locations()
List<LocationTreeElement<ShortcutRouteId>> buildLocations() => [
  ItemLocation(
    id: ShortcutRouteId.item,
    build: (builder, location) {
      builder.pathLiteral('items');
      final itemUri = builder.uriPathParam();
      final filter = builder.enumQueryParam('filter', ItemFilter.values);
      final from = builder.uriQueryParam(
        'from',
        defaultValue: Default(Uri.parse('/home')),
      );

      builder.widget(const SizedBox.shrink());
    },
  ),
];
''',
        },
        outputs: {
          'working_router|lib/shortcut_param_routes.working_router.g.part': decodedMatches(
            allOf(
              contains('void routeToItem({'),
              contains('required Uri itemUri,'),
              contains('required ItemFilter filter,'),
              contains('Uri? from,'),
              contains(
                "'filter': EnumRouteParamCodec(ItemFilter.values).encode(filter),",
              ),
              contains(
                "if (from != null) 'from': const UriRouteParamCodec().encode(from),",
              ),
              contains(
                'path(location.pathParameters[0] as PathParam<Uri>, itemUri);',
              ),
            ),
          ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'does not generate double-nullable optional query parameter types',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/nullable_query_param_routes.dart': '''
library nullable_query_param_routes;

import 'package:working_router/working_router.dart';

part 'nullable_query_param_routes.g.dart';

enum NullableQueryRouteId { item }

class NullableStringRouteParamCodec extends RouteParamCodec<String?> {
  const NullableStringRouteParamCodec();

  @override
  String encode(String? value) => value ?? '';

  @override
  String? decode(String value) => value.isEmpty ? null : value;
}

class NullableUriRouteParamCodec extends RouteParamCodec<Uri?> {
  const NullableUriRouteParamCodec();

  @override
  String encode(Uri? value) => value?.toString() ?? '';

  @override
  Uri? decode(String value) => value.isEmpty ? null : Uri.parse(value);
}

class ItemLocation extends Location<NullableQueryRouteId, ItemLocation> {
  ItemLocation({
    required super.id,
    required super.build,
  });
}

@Locations()
List<LocationTreeElement<NullableQueryRouteId>> buildLocations() => [
  ItemLocation(
    id: NullableQueryRouteId.item,
    build: (builder, location) {
      builder.pathLiteral('items');
      final filter = builder.queryParam(
        'filter',
        const NullableStringRouteParamCodec(),
        defaultValue: Default<String?>(null),
      );
      final from = builder.queryParam(
        'from',
        const NullableUriRouteParamCodec(),
        defaultValue: Default<Uri?>(null),
      );

      builder.widget(const SizedBox.shrink());
    },
  ),
];
''',
        },
        outputs: {
          'working_router|lib/nullable_query_param_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('ItemRouteTarget({String? filter, Uri? from})'),
                  contains('void routeToItem({String? filter, Uri? from})'),
                  isNot(contains('String??')),
                  isNot(contains('Uri??')),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'inherits query parameters from groups into child route helpers',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/group_query_routes.dart': '''
library group_query_routes;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

part 'group_query_routes.g.dart';

enum GroupQueryRouteId { privacy }

class PrivacyLocation extends Location<GroupQueryRouteId, PrivacyLocation> {
  PrivacyLocation({
    required super.id,
    required super.build,
  });
}

@Locations()
List<LocationTreeElement<GroupQueryRouteId>> buildLocations() => [
  Group(
    build: (builder) {
      final languageCode = builder.stringQueryParam(
        'languageCode',
        defaultValue: Default('en'),
      );
      builder.children = [
        PrivacyLocation(
          id: GroupQueryRouteId.privacy,
          build: (builder, location) {
            builder.pathLiteral('privacy');
            builder.widget(const SizedBox.shrink());
          },
        ),
      ];
    },
  ),
];
''',
        },
        outputs: {
          'working_router|lib/group_query_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToPrivacy({String? languageCode})'),
                  contains(
                    "'languageCode': const StringRouteParamCodec().encode(languageCode),",
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
        BuilderOptions.empty,
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

class ChatChannelLocation
    extends Location<DerivedChildRouteId, ChatChannelLocation> {
  final channelId = PathParam(const StringRouteParamCodec());

  ChatChannelLocation({super.id});

  @override
  late final List<LocationTreeElement<DerivedChildRouteId>> children = [
    ChatChannelSendLocation(
      id: id != null ? DerivedChildRouteId.chatChannelSend : null,
    ),
  ];

  @override
  List<PathSegment> get path => [
    LiteralPathSegment('channels'),
    channelId,
  ];
}

class ChatChannelSendLocation
    extends Location<DerivedChildRouteId, ChatChannelSendLocation> {
  ChatChannelSendLocation({super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('send')];
}

@Locations()
final LocationTreeElement<DerivedChildRouteId> appLocationTree =
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
        BuilderOptions.empty,
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

class RootLocation extends Location<IfUnionRouteId, RootLocation> {
  RootLocation() : super(id: IfUnionRouteId.root);

  @override
  late final List<LocationTreeElement<IfUnionRouteId>> children = [
    _ChildLocation(
      id: IfUnionRouteId.always,
      path: [LiteralPathSegment('always')],
    ),
    if (includeMaybe)
      _ChildLocation(
        id: IfUnionRouteId.maybe,
        path: [LiteralPathSegment('maybe')],
      ),
    if (includeSpread) ...[
      _ChildLocation(
        id: IfUnionRouteId.maybeSpread,
        path: [LiteralPathSegment('spread')],
      ),
    ],
    if (includeMaybe)
      _ChildLocation(
        id: IfUnionRouteId.maybeElseA,
        path: [LiteralPathSegment('else-a')],
      )
    else
      _ChildLocation(
        id: IfUnionRouteId.maybeElseB,
        path: [LiteralPathSegment('else-b')],
      ),
  ];

  @override
  List<PathSegment> get path => const [];
}

class _ChildLocation extends Location<IfUnionRouteId, _ChildLocation> {
  final List<PathSegment> _path;

  _ChildLocation({required super.id, required List<PathSegment> path})
      : _path = path;

  @override
  List<PathSegment> get path => _path;
}

@Locations()
LocationTreeElement<IfUnionRouteId> buildLocationTree() => RootLocation();
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
        BuilderOptions.empty,
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

class RootLocation extends Location<ParameterizedRouteId, RootLocation> {
  @override
  final List<LocationTreeElement<ParameterizedRouteId>> children;

  RootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class ChatLocation extends Location<ParameterizedRouteId, ChatLocation> {
  @override
  final List<LocationTreeElement<ParameterizedRouteId>> children;

  ChatLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => [LiteralPathSegment('chat')];
}

class ChatSearchLocation
    extends Location<ParameterizedRouteId, ChatSearchLocation> {
  @override
  final List<LocationTreeElement<ParameterizedRouteId>> children;

  ChatSearchLocation({
    required ParameterizedRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [LiteralPathSegment('search')];
}

class ChatChannelLocation
    extends Location<ParameterizedRouteId, ChatChannelLocation> {
  final channelId = PathParam(const StringRouteParamCodec());

  @override
  final List<LocationTreeElement<ParameterizedRouteId>> children;

  ChatChannelLocation({
    super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => [
    LiteralPathSegment('channels'),
    channelId,
  ];
}

class ChatChannelSendLocation
    extends Location<ParameterizedRouteId, ChatChannelSendLocation> {
  ChatChannelSendLocation({super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('send')];
}

class ExtraLocation extends Location<ParameterizedRouteId, ExtraLocation> {
  ExtraLocation();

  @override
  List<PathSegment> get path => [LiteralPathSegment('extra')];
}

@Locations()
LocationTreeElement<ParameterizedRouteId> buildLocationTree({
  required Permissions permissions,
}) {
  List<LocationTreeElement<ParameterizedRouteId>> sharedChatLocations({
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
        BuilderOptions.empty,
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

class RootLocation extends Location<AliasedChildrenRouteId, RootLocation> {
  @override
  final List<LocationTreeElement<AliasedChildrenRouteId>> children;

  RootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class SearchLocation
    extends Location<AliasedChildrenRouteId, SearchLocation> {
  @override
  final List<LocationTreeElement<AliasedChildrenRouteId>> children;

  SearchLocation({
    required AliasedChildrenRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [LiteralPathSegment('search')];
}

class LeafLocation extends Location<AliasedChildrenRouteId, LeafLocation> {
  LeafLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('leaf')];
}

@Locations()
LocationTreeElement<AliasedChildrenRouteId> buildLocationTree() {
  List<LocationTreeElement<AliasedChildrenRouteId>> buildSearchBranch({
    required List<LocationTreeElement<AliasedChildrenRouteId>> children,
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
        BuilderOptions.empty,
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

class RootLocation
    extends Location<DefaultForwardedChildrenRouteId, RootLocation> {
  @override
  final List<LocationTreeElement<DefaultForwardedChildrenRouteId>> children;

  RootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class ParentLocation
    extends Location<DefaultForwardedChildrenRouteId, ParentLocation> {
  @override
  final List<LocationTreeElement<DefaultForwardedChildrenRouteId>> children;

  ParentLocation({
    required super.id,
    required this.children,
  });

  @override
  List<PathSegment> get path => [LiteralPathSegment('parent')];
}

class BranchLocation
    extends Location<DefaultForwardedChildrenRouteId, BranchLocation> {
  BranchLocation({required super.id});

  @override
  late final List<LocationTreeElement<DefaultForwardedChildrenRouteId>> children = [
    LeafLocation(id: DefaultForwardedChildrenRouteId.leaf),
  ];

  @override
  List<PathSegment> get path => [LiteralPathSegment('branch')];
}

class LeafLocation
    extends Location<DefaultForwardedChildrenRouteId, LeafLocation> {
  @override
  final List<LocationTreeElement<DefaultForwardedChildrenRouteId>> children;

  LeafLocation({
    required DefaultForwardedChildrenRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [LiteralPathSegment('leaf')];
}

@Locations()
LocationTreeElement<DefaultForwardedChildrenRouteId> buildLocationTree() {
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
      BuilderOptions.empty,
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

class ChildLocation extends Location<ShellRootRouteId, ChildLocation> {
  ChildLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('child')];
}

@Locations()
LocationTreeElement<ShellRootRouteId> get appLocationTree => Shell(
  build: (builder, routerKey) {
    builder.widgetBuilder((context, data, child) => child);
    builder.children = [
      ChildChildLocation(
        id: ShellRootRouteId.child,
        build: (builder, location) {
          builder.pathLiteral('child');
        },
      ),
    ];
  },
);

class ChildChildLocation extends Location<ShellRootRouteId, ChildChildLocation> {
  ChildChildLocation({super.id, super.build});
}
''',
      },
      outputs: {
        'working_router|lib/shell_root_routes.working_router.g.part':
            decodedMatches(
              allOf(
                contains('extension AppLocationTreeGeneratedRoutes'),
                contains('void routeToChild()'),
                contains('void routeToChildChildChild()'),
                contains('final class ChildChildChildRouteTarget'),
                contains('routeTo(ChildChildChildRouteTarget());'),
              ),
            ),
      },
      readerWriter: readerWriter,
    );
  });

  test('includes shell path and query params in generated helpers', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions.empty,
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/shell_params_routes.dart': '''
library shell_params_routes;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

part 'shell_params_routes.g.dart';

enum ShellParamsRouteId { dashboard }

class DashboardLocation
    extends Location<ShellParamsRouteId, DashboardLocation> {
  DashboardLocation({super.id, required super.build});
}

@Locations()
LocationTreeElement<ShellParamsRouteId> get appLocationTree => Shell(
  build: (builder, routerKey) {
    builder.pathLiteral('accounts');
    final accountId = builder.stringPathParam();
    final tab = builder.stringQueryParam('tab');
    builder.widgetBuilder((context, data, child) => child);
    builder.children = [
      DashboardLocation(
        id: ShellParamsRouteId.dashboard,
        build: (builder, location) {
          builder.pathLiteral('dashboard');
        },
      ),
    ];
  },
);
''',
      },
      outputs: {
        'working_router|lib/shell_params_routes.working_router.g.part':
            decodedMatches(
          allOf(
            contains(
              'void routeToDashboard({required String accountId, required String tab}) {',
            ),
            contains(
              'DashboardRouteTarget({required String accountId, required String tab})',
            ),
            contains(
              'location.pathParameters[0] as PathParam<String>,',
            ),
            contains(
              'accountId,',
            ),
            contains(
              "queryParameters: {'tab': const StringRouteParamCodec().encode(tab)}",
            ),
          ),
        ),
      },
      readerWriter: readerWriter,
    );
  });
}
