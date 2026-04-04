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
  String get path => '';
}

class _ItemLocation extends Location<AppRouteId> {
  _ItemLocation({required super.id, super.children = const []});

  @override
  String get path => 'item/:id';

  @override
  Set<String> get queryParameters => {'keep'};
}

class _ItemDetailsLocation extends Location<AppRouteId> {
  _ItemDetailsLocation({required super.id, super.children = const []});

  @override
  String get path => 'details';

  @override
  Set<String> get queryParameters => {'detail'};
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
            contains('extension AppLocationTreeGeneratedRoutes'),
            contains('void routeToRoot()'),
            contains(
              'void routeToItem({required String id, required String keep}) {',
            ),
            contains(
              "pathParameters: {'id': id},",
            ),
            contains(
              'void routeToItemDetails({\n'
              '    required String id,\n'
              '    required String keep,\n'
              '    required String detail,\n'
              '  }) {',
            ),
            contains(
              "queryParameters: {'keep': keep, 'detail': detail},",
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
  String get path => '';
}

class _ChildLocation extends Location<StaticRouteId> {
  _ChildLocation({required super.id, super.children = const []});

  @override
  String get path => 'child';
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
            contains('void routeToChild()'),
          ),
        ),
      },
      readerWriter: readerWriter,
    );
  });

  test('supports static children declared inside the location constructor', () async {
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
  String get path => '';
}

class LessonLocation extends Location<ConstructorRouteId> {
  LessonLocation({required super.id})
      : super(children: [LessonEditLocation(id: ConstructorRouteId.lessonEdit)]);

  @override
  String get path => 'lessons';

  @override
  Set<String> get queryParameters => {'coursePeriodId', 'sourceDateTime'};
}

class LessonEditLocation extends Location<ConstructorRouteId> {
  LessonEditLocation({required super.id});

  @override
  String get path => 'edit';
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
            contains(
              "queryParameters: {\n"
              "        'coursePeriodId': coursePeriodId,\n"
              "        'sourceDateTime': sourceDateTime,\n"
              '      },',
            ),
            contains('void routeToLessonEdit({'),
          ),
        ),
      },
      readerWriter: readerWriter,
    );
  });

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
  String get path => 'lessons';

  @override
  Set<String> get queryParameters => {coursePeriodIdKey, sourceDateTimeKey};
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

  test('supports child ids derived from whether the parent id is null', () async {
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
  String get path => 'channels/:channelId';
}

class ChatChannelSendLocation extends Location<DerivedChildRouteId> {
  ChatChannelSendLocation({super.id});

  @override
  String get path => 'send';
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
            contains('void routeToChatChannel({required String channelId}) {'),
            contains(
              'void routeToChatChannelSend({required String channelId}) {',
            ),
          ),
        ),
      },
      readerWriter: readerWriter,
    );
  });
}
