import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkingRouter transitions', () {
    testWidgets('emits typed route transitions when routing commits', (
      tester,
    ) async {
      final router = _buildRouter();
      final transitionsFuture = router.routeTransitions
          .take(2)
          .toList()
          .timeout(const Duration(seconds: 2));

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();
      router.routeToUri(Uri(path: '/a/b'));
      await tester.pump();
      await tester.pump();

      final transitions = await transitionsFuture;

      expect(transitions.length, 2);
      expect(transitions[0].from, isNull);
      expect(transitions[0].to.uri.path, '/a');
      expect(transitions[0].reason, RouteTransitionReason.programmatic);
      expect(transitions[1].from!.uri.path, '/a');
      expect(transitions[1].to.uri.path, '/a/b');
      expect(transitions[1].reason, RouteTransitionReason.programmatic);
    });

    testWidgets('blocks and allows transitions via TransitionDecider', (
      tester,
    ) async {
      final router = _buildRouter(
        decideTransition: (_, transition) {
          if (transition.to.uri.path == '/a') {
            return const BlockTransition();
          }
          return const AllowTransition();
        },
      );

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();
      expect(router.nullableData, isNull);

      router.routeToUri(Uri(path: '/c'));
      await tester.pump();
      expect(router.nullableData!.uri.path, '/c');
    });

    testWidgets('redirects transitions to URI and ID', (tester) async {
      final uriRouter = _buildRouter(
        decideTransition: (_, transition) {
          if (transition.to.uri.path == '/a') {
            return RedirectTransition.toUri(Uri(path: '/c'));
          }
          return const AllowTransition();
        },
      );

      uriRouter.routeToUri(Uri(path: '/a'));
      await tester.pump();
      expect(uriRouter.nullableData!.uri.path, '/c');

      final idRouter = _buildRouter(
        decideTransition: (_, transition) {
          if (transition.to.uri.path == '/a') {
            return RedirectTransition.toId(_Id.c);
          }
          return const AllowTransition();
        },
      );

      idRouter.routeToUri(Uri(path: '/a'));
      await tester.pump();
      expect(idRouter.nullableData!.uri.path, '/c');
    });

    testWidgets('throws on redirect loop', (tester) async {
      final router = _buildRouter(
        decideTransition: (_, transition) {
          if (transition.to.uri.path == '/a') {
            return RedirectTransition.toUri(Uri(path: '/a'));
          }
          return const AllowTransition();
        },
      );

      expect(() => router.routeToUri(Uri(path: '/a')), throwsStateError);
    });

    testWidgets('throws when redirect limit is exceeded', (tester) async {
      var redirectCount = 0;
      final router = _buildRouter(
        redirectLimit: 2,
        decideTransition: (_, transition) {
          redirectCount += 1;
          return RedirectTransition.toUri(Uri(path: '/r$redirectCount'));
        },
      );

      expect(() => router.routeToUri(Uri(path: '/a')), throwsStateError);
    });
  });

  group('WorkingRouter beforeLeave', () {
    testWidgets('blocks route change when beforeLeave resolves false', (
      tester,
    ) async {
      final leave = Completer<bool>();
      var callCount = 0;
      final router = _buildRouter(
        beforeLeave: () {
          callCount += 1;
          return leave.future;
        },
      );

      await _pumpApp(tester, router);
      router.routeToUri(Uri(path: '/a/b'));
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/a/b');

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();
      expect(router.nullableData!.uri.path, '/a/b');
      expect(callCount, 1);

      leave.complete(false);
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/a/b');
    });

    testWidgets('discards stale async beforeLeave request', (tester) async {
      final firstLeave = Completer<bool>();
      var callCount = 0;
      final router = _buildRouter(
        beforeLeave: () {
          callCount += 1;
          if (callCount == 1) {
            return firstLeave.future;
          }
          return Future.value(true);
        },
      );

      await _pumpApp(tester, router);
      router.routeToUri(Uri(path: '/a/b'));
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/a/b');

      router.routeToUri(Uri(path: '/a'));
      router.routeToUri(Uri(path: '/c'));
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/c');
      expect(callCount, 2);

      firstLeave.complete(true);
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/c');
    });

    testWidgets('allows route change when beforeLeave resolves true', (
      tester,
    ) async {
      final leave = Completer<bool>();
      final router = _buildRouter(beforeLeave: () => leave.future);

      await _pumpApp(tester, router);
      router.routeToUri(Uri(path: '/a/b'));
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/a/b');

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();
      expect(router.nullableData!.uri.path, '/a/b');

      leave.complete(true);
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/a');
    });
  });

  group('WorkingRouter multi-observer beforeLeave', () {
    testWidgets('runs all leaving beforeLeave callbacks when all allow', (
      tester,
    ) async {
      final calls = <String>[];
      final router = _buildOrderRouter(
        beforeLeaveA: () async {
          calls.add('a');
          return true;
        },
        beforeLeaveB: () async {
          calls.add('b');
          return true;
        },
      );

      await _pumpApp(tester, router);
      router.routeToUri(Uri(path: '/a/b'));
      await tester.pumpAndSettle();
      router.routeToUri(Uri(path: '/c'));
      await tester.pumpAndSettle();

      expect(calls, unorderedEquals(['a', 'b']));
      expect(router.nullableData!.uri.path, '/c');
    });

    testWidgets(
      'blocks transition when one leaving beforeLeave returns false',
      (
        tester,
      ) async {
        final calls = <String>[];
        final router = _buildOrderRouter(
          beforeLeaveA: () async {
            calls.add('a');
            return true;
          },
          beforeLeaveB: () async {
            calls.add('b');
            return false;
          },
        );

        await _pumpApp(tester, router);
        router.routeToUri(Uri(path: '/a/b'));
        await tester.pumpAndSettle();
        router.routeToUri(Uri(path: '/c'));
        await tester.pumpAndSettle();

        expect(calls, isNotEmpty);
        expect(calls, contains('b'));
        expect(router.nullableData!.uri.path, '/a/b');
      },
    );
  });

  group('WorkingRouter navigation behavior', () {
    testWidgets('initialUri seeds router data immediately', (tester) async {
      final router = _buildRouter(initialUri: Uri(path: '/a/b'));

      expect(router.nullableData!.uri.path, '/a/b');

      await _pumpApp(tester, router);
      expect(router.nullableData!.uri.path, '/a/b');
    });

    testWidgets('routeBack keeps selected query and path parameters', (
      tester,
    ) async {
      final router = _buildParamRouter();

      router.routeToUri(Uri.parse('/item/42/details?keep=1&drop=2'));
      await tester.pump();
      expect(router.nullableData!.uri.path, '/item/42/details');
      expect(router.nullableData!.pathParameters['id'], '42');

      router.routeBack();
      await tester.pump();
      expect(router.nullableData!.uri.path, '/item/42');
      expect(router.nullableData!.pathParameters['id'], '42');
      expect(router.nullableData!.queryParameters.unlock, {'keep': '1'});

      router.routeBack();
      await tester.pump();
      expect(router.nullableData!.uri.path, '/');
      expect(router.nullableData!.pathParameters.isEmpty, true);
      expect(router.nullableData!.queryParameters.isEmpty, true);
    });

    testWidgets('keeps fallback uri and empty locations for unknown path', (
      tester,
    ) async {
      final router = _buildRouter();

      router.routeToUri(
        Uri(path: '/does-not-exist', queryParameters: {'q': '1'}),
      );
      await tester.pump();

      final data = router.nullableData!;
      expect(data.locations, isEmpty);
      expect(data.uri.path, '/does-not-exist');
      expect(data.uri.queryParameters['q'], '1');
    });

    testWidgets('routeToChildWhere appends matching child stack', (
      tester,
    ) async {
      final router = _buildRouter();

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();
      expect(router.nullableData!.uri.path, '/a');

      router.routeToChildWhere((location) => location.id == _Id.b);
      await tester.pump();
      expect(router.nullableData!.uri.path, '/a/b');
    });

    testWidgets('navigator maybePop syncs router back once', (tester) async {
      final router = _buildRouter();
      await _pumpApp(tester, router);

      router.routeToUri(Uri(path: '/a/b'));
      await tester.pumpAndSettle();
      expect(router.nullableData!.uri.path, '/a/b');

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final didPop = await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(didPop, true);
      expect(router.nullableData!.uri.path, '/a');
    });
  });

  group('WorkingRouter lifecycle', () {
    testWidgets('disposing router closes route transition stream', (
      tester,
    ) async {
      final router = _buildRouter();
      final done = Completer<void>();
      router.routeTransitions.listen(
        (_) {},
        onDone: () {
          if (!done.isCompleted) {
            done.complete();
          }
        },
      );

      router.dispose();
      await done.future;
    });
  });
}

Future<void> _pumpApp(WidgetTester tester, WorkingRouter<_Id> router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

WorkingRouter<_Id> _buildRouter({
  TransitionDecider<_Id>? decideTransition,
  Future<bool> Function()? beforeLeave,
  int redirectLimit = 5,
  Uri? initialUri,
}) {
  final bPage = ChildLocationPageSkeleton<_Id>(
    child: LocationObserver(
      beforeLeave: beforeLeave,
      child: const Text('b'),
    ),
  );

  return WorkingRouter<_Id>(
    buildLocationTree: () {
      return _PathLocation(
        id: _Id.root,
        path: '',
        children: [
          _PathLocation(
            id: _Id.a,
            path: 'a',
            children: [
              _PathLocation(id: _Id.b, path: 'b', children: []),
            ],
          ),
          _PathLocation(id: _Id.c, path: 'c', children: []),
        ],
      );
    },
    buildRootPages: (_, location, _) {
      switch (location.id) {
        case _Id.root:
          return [ChildLocationPageSkeleton(child: const Text('root'))];
        case _Id.a:
          return [ChildLocationPageSkeleton(child: const Text('a'))];
        case _Id.b:
          return [bPage];
        case _Id.c:
          return [ChildLocationPageSkeleton(child: const Text('c'))];
        case null:
          return [];
      }
    },
    noContentWidget: const SizedBox.shrink(),
    decideTransition: decideTransition,
    redirectLimit: redirectLimit,
    initialUri: initialUri,
  );
}

WorkingRouter<_Id> _buildOrderRouter({
  Future<bool> Function()? beforeLeaveA,
  Future<bool> Function()? beforeLeaveB,
}) {
  return WorkingRouter<_Id>(
    buildLocationTree: () {
      return _PathLocation(
        id: _Id.root,
        path: '',
        children: [
          _PathLocation(
            id: _Id.a,
            path: 'a',
            children: [
              _PathLocation(id: _Id.b, path: 'b', children: []),
            ],
          ),
          _PathLocation(id: _Id.c, path: 'c', children: []),
        ],
      );
    },
    buildRootPages: (_, location, _) {
      switch (location.id) {
        case _Id.root:
          return [ChildLocationPageSkeleton(child: const Text('root'))];
        case _Id.a:
          return [
            ChildLocationPageSkeleton(
              child: LocationObserver(
                beforeLeave: beforeLeaveA,
                child: const Text('a'),
              ),
            ),
          ];
        case _Id.b:
          return [
            ChildLocationPageSkeleton(
              child: LocationObserver(
                beforeLeave: beforeLeaveB,
                child: const Text('b'),
              ),
            ),
          ];
        case _Id.c:
          return [ChildLocationPageSkeleton(child: const Text('c'))];
        case null:
          return [];
      }
    },
    noContentWidget: const SizedBox.shrink(),
  );
}

WorkingRouter<_ParamId> _buildParamRouter() {
  return WorkingRouter<_ParamId>(
    buildLocationTree: () {
      return _ParamRootLocation(
        id: _ParamId.root,
        children: [
          _ItemLocation(
            id: _ParamId.item,
            children: [
              _ParamPathLocation(id: _ParamId.details, path: 'details'),
            ],
          ),
        ],
      );
    },
    buildRootPages: (_, location, _) {
      return [
        ChildLocationPageSkeleton(
          child: Text('${location.id}'),
        ),
      ];
    },
    noContentWidget: const SizedBox.shrink(),
  );
}

enum _Id { root, a, b, c }

enum _ParamId { root, item, details }

class _PathLocation extends Location<_Id> {
  final String _path;

  _PathLocation({
    required _Id id,
    required String path,
    super.children = const [],
  }) : _path = path,
       super(id: id);

  @override
  String get path => _path;
}

class _ParamPathLocation extends Location<_ParamId> {
  final String _path;

  _ParamPathLocation({
    required _ParamId id,
    required String path,
    super.children = const [],
  }) : _path = path,
       super(id: id);

  @override
  String get path => _path;
}

class _ParamRootLocation extends _ParamPathLocation {
  _ParamRootLocation({
    required super.id,
    super.children = const [],
  }) : super(path: '');
}

class _ItemLocation extends _ParamPathLocation {
  _ItemLocation({
    required super.id,
    super.children = const [],
  }) : super(path: 'item/:id');

  @override
  IMap<String, String> selectQueryParameters(
    IMap<String, String> currentQueryParameters,
  ) {
    return currentQueryParameters.keepKeys({'keep'});
  }
}
