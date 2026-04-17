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
  void build(LocationBuilder<AppRouteId> builder) {
    builder.children = [
      _ItemLocation(id: AppRouteId.item),
    ];
  }
}

class _ItemLocation extends Location<AppRouteId, _ItemLocation> {
  _ItemLocation({required super.id});

  @override
  void build(LocationBuilder<AppRouteId> builder) {
    builder.pathLiteral('item');
    final itemId = builder.stringPathParam();
    final keep = builder.stringQueryParam('keep');
    builder.children = [
      ...buildItemChildren(),
    ];
  }
}

class _ItemDetailsLocation extends Location<AppRouteId, _ItemDetailsLocation> {
  _ItemDetailsLocation({required super.id});

  @override
  void build(LocationBuilder<AppRouteId> builder) {
    builder.pathLiteral('details');
    final detail = builder.stringQueryParam('detail');
  }
}

List<RouteNode<AppRouteId>> buildItemChildren() => [
  _ItemDetailsLocation(
    id: AppRouteId.itemDetails,
  ),
];

final _appLocationTree = _RootLocation(id: AppRouteId.root);

@RouteNodes()
RouteNode<AppRouteId> get appLocationTree => _appLocationTree;
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
                contains('extension AppLocationTreeGeneratedRoutes'),
              ),
              allOf(
                contains('void routeToRoot()'),
                contains(
                  'void routeToItem({required String itemId, required String keep}) {',
                ),
                isNot(contains('void routeToChildItem(')),
              ),
              allOf(
                contains(
                  'routeTo(ItemRouteTarget(itemId: itemId, keep: keep));',
                ),
                isNot(contains('routeTo(ChildItemRouteTarget(')),
                contains('writePathParameters: (() {'),
                contains(
                  'path(location.pathParameters[0] as PathParam<String>, itemId);',
                ),
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
                isNot(contains('void routeToChildItemDetails(')),
                isNot(contains('final class ChildItemDetailsRouteTarget')),
                isNot(contains('routeTo(ChildItemDetailsRouteTarget(')),
              ),
              allOf(
                contains('queryParameters: {'),
                contains("'keep': const StringRouteParamCodec().encode(keep),"),
                contains(
                  "'detail': const StringRouteParamCodec().encode(detail),",
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
  void build(LocationBuilder<ParamSuffixRouteId> builder) {
    builder.children = [
      DetailLocation(id: ParamSuffixRouteId.detail),
    ];
  }
}

class DetailLocation extends Location<ParamSuffixRouteId, DetailLocation> {
  DetailLocation({required super.id});

  @override
  void build(LocationBuilder<ParamSuffixRouteId> builder) {
    builder.pathLiteral('detail');
    final idParam = builder.stringPathParam();
    final slugParameter = builder.stringPathParam();
  }
}

@RouteNodes()
RouteNode<ParamSuffixRouteId> get appLocationTree => RootLocation();
''',
      },
      outputs: {
        'working_router|lib/param_suffix_routes.working_router.g.part': decodedMatches(
          allOf(
            contains(
              'void routeToDetail({required String id, required String slug}) {',
            ),
            contains(
              'DetailRouteTarget({required String id, required String slug})',
            ),
            contains(
              'path(location.pathParameters[0] as PathParam<String>, id);',
            ),
            contains(
              'path(location.pathParameters[1] as PathParam<String>, slug);',
            ),
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

@RouteNodes()
RouteNode<FieldDslRouteId> get appLocationTree => RootLocation();
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
  late final List<RouteNode<StaticRouteId>> children = [
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

  static RouteNode<StaticRouteId> get tree => _tree;
}

@RouteNodes()
RouteNode<StaticRouteId> get appLocationTree => AppRoutes.tree;
''',
      },
      outputs: {
        'working_router|lib/static_routes.working_router.g.part':
            decodedMatches(
              allOf(
                contains('extension AppLocationTreeGeneratedRoutes'),
                contains('void routeToRoot()'),
                contains('void routeToChild()'),
                isNot(contains('void routeToChildChild()')),
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
  void build(LocationBuilder<ConstructorRouteId> builder) {
    builder.children = [
      LessonLocation(id: ConstructorRouteId.lesson),
    ];
  }
}

class LessonLocation extends Location<ConstructorRouteId, LessonLocation> {
  LessonLocation({required super.id});

  @override
  void build(LocationBuilder<ConstructorRouteId> builder) {
    builder.pathLiteral('lessons');
    final coursePeriodId = builder.stringQueryParam('coursePeriodId');
    final sourceDateTime = builder.stringQueryParam('sourceDateTime');
    builder.children = [
      LessonEditLocation(id: ConstructorRouteId.lessonEdit),
    ];
  }
}

class LessonEditLocation
    extends Location<ConstructorRouteId, LessonEditLocation> {
  LessonEditLocation({required super.id});

  @override
  void build(LocationBuilder<ConstructorRouteId> builder) {
    builder.pathLiteral('edit');
  }
}

@RouteNodes()
final RouteNode<ConstructorRouteId> appLocationTree = RootLocation();
''',
        },
        outputs: {
          'working_router|lib/constructor_children_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToLesson({'),
                  contains('queryParameters: {'),
                  contains(
                    "'coursePeriodId': const StringRouteParamCodec().encode(coursePeriodId),",
                  ),
                  contains(
                    "'sourceDateTime': const StringRouteParamCodec().encode(sourceDateTime),",
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
  void build(LocationBuilder<ConstQueryRouteId> builder) {
    builder.pathLiteral('lessons');
    final coursePeriodId = builder.stringQueryParam(coursePeriodIdKey);
    final sourceDateTime = builder.stringQueryParam(sourceDateTimeKey);
  }
}

@RouteNodes()
final RouteNode<ConstQueryRouteId> appLocationTree =
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
  ItemLocation({required super.id});

  @override
  void build(LocationBuilder<TypedRouteId> builder) {
    builder.pathLiteral('items');
    final itemId = builder.intPathParam();
    final filter = builder.enumQueryParam('filter', ItemFilter.values);
    final page = builder.intQueryParam('page', defaultValue: Default(1));
  }
}

@RouteNodes()
final RouteNode<TypedRouteId> appLocationTree =
    ItemLocation(id: TypedRouteId.item);
''',
        },
        outputs: {
          'working_router|lib/typed_route_params_routes.working_router.g.part': decodedMatches(
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
                contains(
                  'path(location.pathParameters[0] as PathParam<int>, itemId);',
                ),
                contains('queryParameters: {'),
                contains(
                  "'filter': EnumRouteParamCodec(ItemFilter.values).encode(filter),",
                ),
                contains(
                  "if (page case final value?)\n"
                  "            'page': const IntRouteParamCodec().encode(value),",
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
    'uses explicit query parameter names from query declarations',
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
  ItemLocation({required super.id});

  @override
  void build(LocationBuilder<InferredQueryParamRouteId> builder) {
    builder.pathLiteral('items');
    final itemId = builder.intPathParam();
    final filterParam = builder.queryParam(
      'filter',
      EnumRouteParamCodec(ItemFilter.values),
    );
    final pageParam = builder.queryParam(
      'page',
      IntRouteParamCodec(),
      defaultValue: Default(1),
    );
  }
}

@RouteNodes()
final RouteNode<InferredQueryParamRouteId> appLocationTree =
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

@RouteNodes()
List<RouteNode<ShortcutRouteId>> buildRouteNodes() => [
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

      builder.content = Content.widget(const SizedBox.shrink());
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
                "if (from case final value?)\n"
                "            'from': const UriRouteParamCodec().encode(value),",
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

class ItemLocation extends Location<NullableQueryRouteId, ItemLocation> {
  ItemLocation({
    required super.id,
    required super.build,
  });
}

@RouteNodes()
List<RouteNode<NullableQueryRouteId>> buildRouteNodes() => [
  ItemLocation(
    id: NullableQueryRouteId.item,
    build: (builder, location) {
      builder.pathLiteral('items');
      final filter = builder.queryParam<String?>(
        'filter',
        const StringRouteParamCodec(),
        defaultValue: Default<String?>(null),
      );
      final from = builder.queryParam<Uri?>(
        'from',
        const UriRouteParamCodec(),
        defaultValue: Default<Uri?>(null),
      );

      builder.content = Content.widget(const SizedBox.shrink());
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
                  contains(
                    "if (filter case final value?)\n"
                    "            'filter': const StringRouteParamCodec().encode(value),",
                  ),
                  contains(
                    "if (from case final value?)\n"
                    "            'from': const UriRouteParamCodec().encode(value),",
                  ),
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
    'supports nullable query shortcut methods in the DSL',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/nullable_query_shortcuts_routes.dart': '''
library nullable_query_shortcuts_routes;

import 'package:working_router/working_router.dart';

part 'nullable_query_shortcuts_routes.g.dart';

enum NullableShortcutRouteId { item }

class ItemLocation extends Location<NullableShortcutRouteId, ItemLocation> {
  ItemLocation({
    required super.id,
    required super.build,
  });
}

@RouteNodes()
List<RouteNode<NullableShortcutRouteId>> buildRouteNodes() => [
  ItemLocation(
    id: NullableShortcutRouteId.item,
    build: (builder, location) {
      builder.pathLiteral('items');
      final enabled = builder.nullableBoolQueryParam('enabled');
      final endDateTime = builder.nullableDateTimeQueryParam('endDateTime');

      builder.content = Content.widget(const SizedBox.shrink());
    },
  ),
];
''',
        },
        outputs: {
          'working_router|lib/nullable_query_shortcuts_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains(
                    'ItemRouteTarget({bool? enabled, DateTime? endDateTime})',
                  ),
                  contains(
                    'void routeToItem({bool? enabled, DateTime? endDateTime})',
                  ),
                  contains(
                    "if (enabled case final value?)\n"
                    "            'enabled': const BoolRouteParamCodec().encode(value),",
                  ),
                  contains(
                    "if (endDateTime case final value?)\n"
                    "            'endDateTime': const DateTimeIsoRouteParamCodec().encode(value),",
                  ),
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

@RouteNodes()
List<RouteNode<GroupQueryRouteId>> buildRouteNodes() => [
  Scope(
    build: (builder, scope) {
      final languageCode = builder.stringQueryParam(
        'languageCode',
        defaultValue: Default('en'),
      );
      builder.children = [
        PrivacyLocation(
          id: GroupQueryRouteId.privacy,
          build: (builder, location) {
            builder.pathLiteral('privacy');
            builder.content = Content.widget(const SizedBox.shrink());
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
                    "if (languageCode case final value?)\n"
                    "            'languageCode': const StringRouteParamCodec().encode(value),",
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
  ChatChannelLocation({super.id});

  @override
  void build(LocationBuilder<DerivedChildRouteId> builder) {
    builder.pathLiteral('channels');
    final channelId = builder.stringPathParam();
    builder.children = [
      ChatChannelSendLocation(
        id: id != null ? DerivedChildRouteId.chatChannelSend : null,
      ),
    ];
  }
}

class ChatChannelSendLocation
    extends Location<DerivedChildRouteId, ChatChannelSendLocation> {
  ChatChannelSendLocation({super.id});

  @override
  void build(LocationBuilder<DerivedChildRouteId> builder) {
    builder.pathLiteral('send');
  }
}

@RouteNodes()
final RouteNode<DerivedChildRouteId> appLocationTree =
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
    'supports child ids derived from boolean aliases of whether the parent id is null',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/derived_child_alias_ids_routes.dart': '''
library derived_child_alias_ids_routes;

import 'package:working_router/working_router.dart';

part 'derived_child_alias_ids_routes.g.dart';

enum DerivedChildAliasRouteId { chatChannel, chatChannelSend }

class ChatChannelLocation
    extends Location<DerivedChildAliasRouteId, ChatChannelLocation> {
  ChatChannelLocation({super.id});

  @override
  void build(LocationBuilder<DerivedChildAliasRouteId> builder) {
    builder.pathLiteral('channels');
    final channelId = builder.stringPathParam();
    final hasIds = id != null;
    builder.children = [
      ChatChannelSendLocation(
        id: hasIds ? DerivedChildAliasRouteId.chatChannelSend : null,
      ),
    ];
  }
}

class ChatChannelSendLocation
    extends Location<DerivedChildAliasRouteId, ChatChannelSendLocation> {
  ChatChannelSendLocation({super.id});

  @override
  void build(LocationBuilder<DerivedChildAliasRouteId> builder) {
    builder.pathLiteral('send');
  }
}

@RouteNodes()
final RouteNode<DerivedChildAliasRouteId> appLocationTree =
    ChatChannelLocation(id: DerivedChildAliasRouteId.chatChannel);
''',
        },
        outputs: {
          'working_router|lib/derived_child_alias_ids_routes.working_router.g.part':
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
  late final List<RouteNode<IfUnionRouteId>> children = [
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

@RouteNodes()
RouteNode<IfUnionRouteId> buildLocationTree() => RootLocation();
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
  final List<RouteNode<ParameterizedRouteId>> children;

  RootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class ChatLocation extends Location<ParameterizedRouteId, ChatLocation> {
  @override
  final List<RouteNode<ParameterizedRouteId>> children;

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
  final List<RouteNode<ParameterizedRouteId>> children;

  ChatSearchLocation({
    required ParameterizedRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [LiteralPathSegment('search')];
}

class ChatChannelLocation
    extends Location<ParameterizedRouteId, ChatChannelLocation> {
  @override
  final List<RouteNode<ParameterizedRouteId>> children;

  ChatChannelLocation({
    super.id,
    this.children = const [],
  });

  @override
  void build(LocationBuilder<ParameterizedRouteId> builder) {
    builder.pathLiteral('channels');
    final channelId = builder.stringPathParam();
    builder.children = children;
  }
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

@RouteNodes()
RouteNode<ParameterizedRouteId> buildLocationTree({
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
                contains('// ignore_for_file: type=lint'),
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
    'supports path params assigned to node fields inside build methods',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/field_assigned_path_param_routes.dart': '''
library field_assigned_path_param_routes;

import 'package:working_router/working_router.dart';

part 'field_assigned_path_param_routes.g.dart';

enum FieldAssignedRouteId { dashboard }

class DashboardLocation
    extends Location<FieldAssignedRouteId, DashboardLocation> {
  DashboardLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('dashboard')];
}

class AccountShell extends AbstractShell<FieldAssignedRouteId> {
  late final PathParam<String> accountId;

  @override
  void build(ShellBuilder<FieldAssignedRouteId> builder) {
    builder.pathLiteral('accounts');
    accountId = builder.pathParam(const StringRouteParamCodec());
    builder.children = [
      DashboardLocation(id: FieldAssignedRouteId.dashboard),
    ];
  }
}

@RouteNodes()
RouteNode<FieldAssignedRouteId> get appLocationTree => AccountShell();
''',
        },
        outputs: {
          'working_router|lib/field_assigned_path_param_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains(
                    'void routeToDashboard({required String accountId}) {',
                  ),
                  contains(
                    'DashboardRouteTarget({required String accountId})',
                  ),
                  contains(
                    'location.pathParameters[0] as PathParam<String>,',
                  ),
                  contains(
                    'accountId,',
                  ),
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
  final List<RouteNode<AliasedChildrenRouteId>> children;

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
  final List<RouteNode<AliasedChildrenRouteId>> children;

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

@RouteNodes()
RouteNode<AliasedChildrenRouteId> buildLocationTree() {
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
  final List<RouteNode<DefaultForwardedChildrenRouteId>> children;

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
  final List<RouteNode<DefaultForwardedChildrenRouteId>> children;

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
  late final List<RouteNode<DefaultForwardedChildrenRouteId>> children = [
    LeafLocation(id: DefaultForwardedChildrenRouteId.leaf),
  ];

  @override
  List<PathSegment> get path => [LiteralPathSegment('branch')];
}

class LeafLocation
    extends Location<DefaultForwardedChildrenRouteId, LeafLocation> {
  @override
  final List<RouteNode<DefaultForwardedChildrenRouteId>> children;

  LeafLocation({
    required DefaultForwardedChildrenRouteId id,
    this.children = const [],
  }) : super(id: id);

  @override
  List<PathSegment> get path => [LiteralPathSegment('leaf')];
}

@RouteNodes()
RouteNode<DefaultForwardedChildrenRouteId> buildLocationTree() {
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

enum ShellRootRouteId { rootShell, child }

class ChildLocation extends Location<ShellRootRouteId, ChildLocation> {
  ChildLocation({required super.id});

  @override
  List<PathSegment> get path => [LiteralPathSegment('child')];
}

@RouteNodes()
RouteNode<ShellRootRouteId> get appLocationTree => Shell(
  id: ShellRootRouteId.rootShell,
  build: (builder, shell, routerKey) {
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
                isNot(contains('void routeToChildChildChild()')),
                isNot(contains('final class ChildChildChildRouteTarget')),
                isNot(contains('routeTo(ChildChildChildRouteTarget());')),
                isNot(contains('routeToRootShell')),
              ),
            ),
      },
      readerWriter: readerWriter,
    );
  });

  test(
    'supports instantiated route node subclasses with implicit zero-arg constructors',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/implicit_constructor_routes.dart': '''
library implicit_constructor_routes;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

part 'implicit_constructor_routes.g.dart';

enum ImplicitConstructorRouteId { privacy }

class LegalNode extends AbstractScope<ImplicitConstructorRouteId> {
  @override
  void build(ScopeBuilder<ImplicitConstructorRouteId> builder) {
    builder.children = [
      PrivacyLocation(
        id: ImplicitConstructorRouteId.privacy,
        build: (builder, location) {
          builder.pathLiteral('privacy');
          builder.content = Content.widget(const SizedBox.shrink());
        },
      ),
    ];
  }
}

class PrivacyLocation
    extends Location<ImplicitConstructorRouteId, PrivacyLocation> {
  PrivacyLocation({required super.id, required super.build});
}

@RouteNodes()
List<RouteNode<ImplicitConstructorRouteId>> buildRouteNodes() => [
  LegalNode(),
];
''',
        },
        outputs: {
          'working_router|lib/implicit_constructor_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToPrivacy()'),
                  contains('final class PrivacyRouteTarget'),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'supports imported instantiated route node subclasses with implicit zero-arg constructors inside collection if children',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/imported_legal_node.dart': '''
library imported_legal_node;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

enum ImportedLegalRouteId { home, privacy }

class LegalNode extends AbstractScope<ImportedLegalRouteId> {
  @override
  void build(ScopeBuilder<ImportedLegalRouteId> builder) {
    builder.children = [
      PrivacyLocation(
        id: ImportedLegalRouteId.privacy,
        build: (builder, location) {
          builder.pathLiteral('privacy');
          builder.content = Content.widget(const SizedBox.shrink());
        },
      ),
    ];
  }
}

class PrivacyLocation
    extends Location<ImportedLegalRouteId, PrivacyLocation> {
  PrivacyLocation({required super.id, required super.build});
}
''',
          'working_router|lib/imported_implicit_constructor_routes.dart': '''
library imported_implicit_constructor_routes;

import 'package:flutter/widgets.dart';
import 'package:working_router/imported_legal_node.dart';
import 'package:working_router/working_router.dart';

part 'imported_implicit_constructor_routes.g.dart';

class HomeLocation
    extends Location<ImportedLegalRouteId, HomeLocation> {
  HomeLocation({required super.id, required super.build});
}

@RouteNodes()
List<RouteNode<ImportedLegalRouteId>> buildRouteNodes() => [
  HomeLocation(
    id: ImportedLegalRouteId.home,
    build: (builder, location) {
      const includeLegal = true;
      builder.pathLiteral('home');
      builder.children = [
        if (includeLegal) LegalNode(),
      ];
    },
  ),
];
''',
        },
        outputs: {
          'working_router|lib/imported_implicit_constructor_routes.working_router.g.part':
              decodedMatches(
                allOf(
                  contains('void routeToHome()'),
                  contains('void routeToPrivacy()'),
                  contains('final class PrivacyRouteTarget'),
                ),
              ),
        },
        readerWriter: readerWriter,
      );
    },
  );

  test(
    'reports unsupported route tree expressions at the offending node',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      final logs = <({String level, String message})>[];
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/unsupported_route_tree_expression.dart': '''
library unsupported_route_tree_expression;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

part 'unsupported_route_tree_expression.g.dart';

enum UnsupportedRouteId { home, privacy }

class PrivacyLocation extends Location<UnsupportedRouteId, PrivacyLocation> {
  PrivacyLocation({required super.id, required super.build});
}

class HomeLocation extends Location<UnsupportedRouteId, HomeLocation> {
  HomeLocation({required super.id, required super.build});
}

@RouteNodes()
List<RouteNode<UnsupportedRouteId>> buildRouteNodes() => [
  HomeLocation(
    id: UnsupportedRouteId.home,
    build: (builder, location) {
      builder.pathLiteral('home');
      builder.children = [
        true
            ? PrivacyLocation(
                id: UnsupportedRouteId.privacy,
                build: (builder, location) {
                  builder.pathLiteral('privacy');
                  builder.content = Content.widget(const SizedBox.shrink());
                },
              )
            : PrivacyLocation(
                id: UnsupportedRouteId.privacy,
                build: (builder, location) {
                  builder.pathLiteral('privacy');
                  builder.content = Content.widget(const SizedBox.shrink());
                },
              ),
      ];
    },
  ),
];
''',
        },
        onLog: (log) => logs.add(
          (level: log.level.name, message: log.message),
        ),
        readerWriter: readerWriter,
      );

      final severeMessages = logs
          .where((log) => log.level == 'SEVERE')
          .map((log) => log.message)
          .join('\n');
      expect(
        severeMessages,
        allOf(
          contains(
            'Unsupported route tree expression `true ? PrivacyLocation(',
          ),
          contains('package:working_router/unsupported_route_tree_expression.dart:25:9'),
          contains('? PrivacyLocation('),
          isNot(contains('List<RouteNode<UnsupportedRouteId>> buildRouteNodes() => [')),
        ),
      );
    },
  );

  test(
    'suggests checking imports for unresolved route node constructor invocations',
    () async {
      final builder = workingRouterRouteHelpersBuilder(
        BuilderOptions.empty,
      );
      final readerWriter = TestReaderWriter(rootPackage: 'working_router');
      final logs = <({String level, String message})>[];
      await readerWriter.testing.loadIsolateSources();

      await testBuilder(
        builder,
        {
          'working_router|lib/missing_import_route_node.dart': '''
library missing_import_route_node;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

part 'missing_import_route_node.g.dart';

enum MissingImportRouteId { home }

class HomeLocation extends Location<MissingImportRouteId, HomeLocation> {
  HomeLocation({required super.id, required super.build});
}

@RouteNodes()
List<RouteNode<MissingImportRouteId>> buildRouteNodes() => [
  HomeLocation(
    id: MissingImportRouteId.home,
    build: (builder, location) {
      builder.pathLiteral('home');
      builder.children = [
        LegalNode(),
      ];
    },
  ),
];
''',
        },
        onLog: (log) => logs.add(
          (level: log.level.name, message: log.message),
        ),
        readerWriter: readerWriter,
      );

      final severeMessages = logs
          .where((log) => log.level == 'SEVERE')
          .map((log) => log.message)
          .join('\n');
      expect(
        severeMessages,
        allOf(
          contains('Unsupported route tree expression `LegalNode()`'),
          contains('`LegalNode()` could not be resolved here.'),
          contains('check that `LegalNode` is imported and visible'),
        ),
      );
    },
  );

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

@RouteNodes()
RouteNode<ShellParamsRouteId> get appLocationTree => Shell(
  build: (builder, shell, routerKey) {
    builder.pathLiteral('accounts');
    final accountId = builder.stringPathParam();
    final tab = builder.stringQueryParam('tab');
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
        'working_router|lib/shell_params_routes.working_router.g.part': decodedMatches(
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

  test('includes shell location params in generated helpers', () async {
    final builder = workingRouterRouteHelpersBuilder(
      BuilderOptions.empty,
    );
    final readerWriter = TestReaderWriter(rootPackage: 'working_router');
    await readerWriter.testing.loadIsolateSources();

    await testBuilder(
      builder,
      {
        'working_router|lib/shell_location_routes.dart': '''
library shell_location_routes;

import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

part 'shell_location_routes.g.dart';

enum ShellLocationRouteId { settings, theme }

class SettingsLocation
    extends ShellLocation<ShellLocationRouteId, SettingsLocation> {
  SettingsLocation({required super.id, required super.build});
}

class ThemeLocation extends Location<ShellLocationRouteId, ThemeLocation> {
  ThemeLocation({required super.id, required super.build});
}

@RouteNodes()
RouteNode<ShellLocationRouteId> get appLocationTree =>
    SettingsLocation(
      id: ShellLocationRouteId.settings,
      build: (builder, location, routerKey) {
        builder.pathLiteral('accounts');
        final accountId = builder.stringPathParam();
        final tab = builder.stringQueryParam('tab');
        builder.content = Content.widget(const SizedBox.shrink());
        builder.children = [
          ThemeLocation(
            id: ShellLocationRouteId.theme,
            build: (builder, location) {
              builder.pathLiteral('theme');
            },
          ),
        ];
      },
    );
''',
      },
      outputs: {
        'working_router|lib/shell_location_routes.working_router.g.part': decodedMatches(
          allOf(
            contains(
              'void routeToSettings({required String accountId, required String tab}) {',
            ),
            contains(
              'void routeToTheme({required String accountId, required String tab}) {',
            ),
            contains(
              'extension SettingsLocationGeneratedChildTargets on SettingsLocation {',
            ),
            contains(
              'ChildRouteTarget<ShellLocationRouteId> get childThemeTarget',
            ),
          ),
        ),
      },
      readerWriter: readerWriter,
    );
  });
}
