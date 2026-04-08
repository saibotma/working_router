import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkingRouter transitions', () {
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

    testWidgets('re-evaluates redirected targets for chained redirects', (
      tester,
    ) async {
      final calls = <String>[];
      final router = _buildRouter(
        decideTransition: (_, transition) {
          calls.add('${transition.reason}:${transition.to.uri.path}');
          if (transition.to.uri.path == '/a') {
            return RedirectTransition.toUri(Uri(path: '/b'));
          }
          if (transition.to.uri.path == '/b') {
            return RedirectTransition.toUri(Uri(path: '/c'));
          }
          return const AllowTransition();
        },
      );

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();

      expect(router.nullableData!.uri.path, '/c');
      expect(calls, [
        'RouteTransitionReason.programmatic:/a',
        'RouteTransitionReason.redirect:/b',
        'RouteTransitionReason.redirect:/c',
      ]);
    });

    testWidgets('allows immediate self redirect as no-op', (tester) async {
      final router = _buildRouter(
        decideTransition: (_, transition) {
          if (transition.to.uri.path == '/a') {
            return RedirectTransition.toUri(Uri(path: '/a'));
          }
          return const AllowTransition();
        },
      );

      expect(() => router.routeToUri(Uri(path: '/a')), returnsNormally);
      await tester.pump();
      expect(router.nullableData!.uri.path, '/a');
    });

    testWidgets('throws on multi-step redirect loop', (tester) async {
      final router = _buildRouter(
        decideTransition: (_, transition) {
          if (transition.to.uri.path == '/a') {
            return RedirectTransition.toUri(Uri(path: '/b'));
          }
          if (transition.to.uri.path == '/b') {
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
    testWidgets('routeBack keeps selected query and path parameters', (
      tester,
    ) async {
      final router = _buildParamRouter();

      router.routeToUri(Uri.parse('/item/42/details?keep=1&drop=2'));
      await tester.pump();
      final itemLocation = router.nullableData!.locations
          .whereType<_ItemLocation>()
          .last;
      expect(router.nullableData!.uri.path, '/item/42/details');
      expect(
        router.nullableData!.pathParameters[itemLocation.idParameter],
        '42',
      );

      router.routeBack();
      await tester.pump();
      expect(router.nullableData!.uri.path, '/item/42');
      expect(
        router.nullableData!.pathParameters[itemLocation.idParameter],
        '42',
      );
      expect(router.nullableData!.queryParameters.unlock, {'keep': '1'});

      router.routeBack();
      await tester.pump();
      expect(router.nullableData!.uri.path, '/');
      expect(router.nullableData!.pathParameters.isEmpty, true);
      expect(router.nullableData!.queryParameters.isEmpty, true);
    });

    testWidgets(
      'routeToId keeps query parameters shared by current and target chains',
      (tester) async {
        final router = _buildParamRouter();

        router.routeToUri(Uri.parse('/item/42/details?keep=1&detail=2&drop=3'));
        await tester.pump();

        router.routeToId(
          _ParamId.item,
          writePathParameters: (location, path) {
            if (location is _ItemLocation) {
              path(location.idParameter, '42');
            }
          },
        );
        await tester.pump();

        expect(router.nullableData!.uri.path, '/item/42');
        expect(router.nullableData!.queryParameters.unlock, {'keep': '1'});
      },
    );

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
      expect(data.activeLocation, isNull);
      expect(data.uri.path, '/does-not-exist');
      expect(data.uri.queryParameters['q'], '1');
    });

    testWidgets('routeToChildWhere is a no-op for unknown path', (
      tester,
    ) async {
      final router = _buildRouter();

      router.routeToUri(Uri(path: '/does-not-exist'));
      await tester.pump();

      expect(
        () => router.routeToChildWhere((location) => location.id == _Id.b),
        returnsNormally,
      );
      await tester.pump();

      expect(router.nullableData!.locations, isEmpty);
      expect(router.nullableData!.uri.path, '/does-not-exist');
    });

    testWidgets('slideIn is a no-op for unknown path', (tester) async {
      final router = _buildRouter();

      router.routeToUri(Uri(path: '/does-not-exist'));
      await tester.pump();

      expect(() => router.slideIn(_Id.a), returnsNormally);
      await tester.pump();

      expect(router.nullableData!.locations, isEmpty);
      expect(router.nullableData!.uri.path, '/does-not-exist');
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

    testWidgets('buildPageKey receives the current router data', (
      tester,
    ) async {
      var sawExpectedData = false;
      final keys = <_Id, LocalKey>{};

      final router = WorkingRouter<_Id>(
        buildRouteNodes: () => [
          _PathLocation(
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
            ],
          ),
        ],
        buildRootPages: (_, location, _) {
          return [
            ChildLocationPageSkeleton<_Id>(
              buildPageKey: (keyLocation, data) {
                if (keyLocation.id == _Id.a) {
                  sawExpectedData =
                      data.uri.path == '/a/b' &&
                      data.activeLocation?.id == _Id.b &&
                      data.locations.contains(keyLocation);
                }
                final key = ValueKey('${keyLocation.id}:${data.uri.path}');
                keys[keyLocation.id!] = key;
                return key;
              },
              child: Text('${location.id}'),
            ),
          ];
        },
        noContentWidget: const SizedBox.shrink(),
      );

      router.routeToUri(Uri(path: '/a/b'));
      await tester.pump();

      expect(sawExpectedData, isTrue);
      expect(keys[_Id.a], const ValueKey('_Id.a:/a/b'));
    });

    testWidgets('wrapLocationChild receives the current router data', (
      tester,
    ) async {
      var sawExpectedData = false;

      final router = WorkingRouter<_Id>(
        buildRouteNodes: () => [
          _PathLocation(
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
            ],
          ),
        ],
        buildRootPages: (_, location, _) {
          return [
            ChildLocationPageSkeleton<_Id>(
              child: Text('${location.id}'),
            ),
          ];
        },
        noContentWidget: const SizedBox.shrink(),
        wrapLocationChild: (context, location, data, child) {
          if (location.id == _Id.b) {
            final inheritedData = WorkingRouterData.of<_Id>(context);
            sawExpectedData =
                identical(inheritedData, data) &&
                data.uri.path == '/a/b' &&
                data.activeLocation?.id == _Id.b;
          }
          return Column(
            children: [
              Text('wrapped ${location.id} at ${data.uri.path}'),
              child,
            ],
          );
        },
      );

      await _pumpApp(tester, router);
      router.routeToUri(Uri(path: '/a/b'));
      await tester.pumpAndSettle();

      expect(sawExpectedData, isTrue);
      expect(find.text('wrapped _Id.b at /a/b'), findsOneWidget);
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

    testWidgets(
      'refresh rebuilds the location tree and rematches the current uri',
      (
        tester,
      ) async {
        var includeB = true;
        final router = WorkingRouter<_Id>(
          buildRouteNodes: () => [
            _PathLocation(
              id: _Id.root,
              path: '',
              children: [
                _PathLocation(
                  id: _Id.a,
                  path: 'a',
                  children: includeB
                      ? [
                          _PathLocation(id: _Id.b, path: 'b', children: []),
                        ]
                      : const [],
                ),
              ],
            ),
          ],
          buildRootPages: (_, location, _) {
            return [
              ChildLocationPageSkeleton<_Id>(
                child: Text('${location.id}'),
              ),
            ];
          },
          noContentWidget: const SizedBox.shrink(),
        );

        router.routeToUri(Uri(path: '/a/b'));
        await tester.pump();
        expect(router.nullableData!.activeLocation?.id, _Id.b);

        includeB = false;
        router.refresh();
        await tester.pump();

        expect(router.nullableData!.locations, isEmpty);
        expect(router.nullableData!.uri.path, '/a/b');
      },
    );

    testWidgets(
      'supports self-built locations alongside legacy buildRootPages',
      (tester) async {
        final router = WorkingRouter<_MigratingId>(
          buildRouteNodes: () => [
            _MigratingRootLocation(
              id: _MigratingId.root,
              children: [
                _SelfBuiltAccountLocation(id: _MigratingId.account),
              ],
            ),
          ],
          buildRootPages: (_, location, _) {
            return switch (location.id) {
              _MigratingId.root => [
                ChildLocationPageSkeleton(
                  child: const Text('legacy-root'),
                ),
              ],
              _ => const [],
            };
          },
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(
          Uri(path: '/accounts/42', queryParameters: {'tab': 'overview'}),
        );
        await tester.pumpAndSettle();

        expect(find.text('legacy-root', skipOffstage: false), findsOneWidget);
        expect(find.text('42:overview'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpApp(WidgetTester tester, WorkingRouter<_Id> router) async {
  await _pumpRouterApp(tester, router);
}

Future<void> _pumpRouterApp<ID>(
  WidgetTester tester,
  WorkingRouter<ID> router,
) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

WorkingRouter<_Id> _buildRouter({
  TransitionDecider<_Id>? decideTransition,
  Future<bool> Function()? beforeLeave,
  int redirectLimit = 5,
}) {
  final bPage = ChildLocationPageSkeleton<_Id>(
    child: LocationObserver(
      beforeLeave: beforeLeave,
      child: const Text('b'),
    ),
  );

  return WorkingRouter<_Id>(
    buildRouteNodes: () => [
      _PathLocation(
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
      ),
    ],
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
  );
}

WorkingRouter<_Id> _buildOrderRouter({
  Future<bool> Function()? beforeLeaveA,
  Future<bool> Function()? beforeLeaveB,
}) {
  return WorkingRouter<_Id>(
    buildRouteNodes: () => [
      _PathLocation(
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
      ),
    ],
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
    buildRouteNodes: () => [
      _ParamRootLocation(
        id: _ParamId.root,
        children: [
          _ItemLocation(
            id: _ParamId.item,
            children: [
              _DetailLocation(id: _ParamId.details, path: 'details'),
            ],
          ),
        ],
      ),
    ],
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

enum _MigratingId { root, account }

class _PathLocation extends Location<_Id> {
  final List<PathSegment> _path;
  @override
  final List<RouteNode<_Id>> children;

  _PathLocation({
    required _Id id,
    required String path,
    this.children = const [],
  }) : _path = _pathSegments(path),
       super(id: id);

  @override
  List<PathSegment> get path => _path;
}

class _ParamPathLocation extends Location<_ParamId> {
  final List<PathSegment> _path;
  @override
  final List<RouteNode<_ParamId>> children;

  _ParamPathLocation({
    required _ParamId id,
    required String path,
    this.children = const [],
  }) : _path = _pathSegments(path),
       super(id: id);

  @override
  List<PathSegment> get path => _path;
}

class _ParamRootLocation extends _ParamPathLocation {
  _ParamRootLocation({
    required super.id,
    super.children = const [],
  }) : super(path: '');
}

class _ItemLocation extends _ParamPathLocation {
  final idParameter = pathParam(const StringRouteParamCodec());

  _ItemLocation({
    required super.id,
    super.children = const [],
  }) : super(path: 'item');

  @override
  List<PathSegment> get path => [
    ...super.path,
    idParameter,
  ];

  @override
  List<QueryParam<dynamic>> get queryParameters => const [
    QueryParam('keep', StringRouteParamCodec()),
  ];
}

class _DetailLocation extends _ParamPathLocation {
  _DetailLocation({
    required super.id,
    required super.path,
  });

  @override
  List<QueryParam<dynamic>> get queryParameters => const [
    QueryParam('detail', StringRouteParamCodec()),
  ];
}

class _MigratingRootLocation extends Location<_MigratingId> {
  @override
  final List<RouteNode<_MigratingId>> children;

  _MigratingRootLocation({
    required super.id,
    this.children = const [],
  });

  @override
  List<PathSegment> get path => const [];
}

class _SelfBuiltAccountLocation extends Location<_MigratingId> {
  final accountId = pathParam(const StringRouteParamCodec());
  final tab = queryParam('tab', const StringRouteParamCodec());

  _SelfBuiltAccountLocation({
    required super.id,
  });

  @override
  bool get buildsOwnPage => true;

  @override
  List<PathSegment> get path => [
    literal('accounts'),
    accountId,
  ];

  @override
  List<QueryParam<dynamic>> get queryParameters => [tab];

  @override
  Widget buildWidget(
    BuildContext context,
    WorkingRouterData<_MigratingId> data,
  ) {
    return Text('${data.pathParameter(accountId)}:${data.queryParameter(tab)}');
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
        return literal(segment);
      })
      .toList(growable: false);
}
