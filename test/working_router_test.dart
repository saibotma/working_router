import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
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

    testWidgets('skips TransitionDecider for unmatched targets', (
      tester,
    ) async {
      final calls = <String>[];
      final router = _buildRouter(
        noContentWidget: const Text('no-content'),
        decideTransition: (_, transition) {
          calls.add(transition.to.uri.path);
          if (transition.to.uri.path == '/c') {
            return const AllowTransition();
          }
          return const BlockTransition();
        },
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(Uri(path: '/c'));
      await tester.pumpAndSettle();

      router.routeToUri(Uri(path: '/does-not-exist'));
      await tester.pumpAndSettle();

      expect(calls, contains('/c'));
      expect(calls, isNot(contains('/does-not-exist')));
      expect(router.nullableData!.uri.path, '/does-not-exist');
      expect(router.nullableData!.routeNodes, isEmpty);
      expect(find.text('no-content'), findsOneWidget);
    });

    testWidgets(
      'calls committed transition hook after redirects and before data update',
      (tester) async {
        final leave = Completer<bool>();
        final calls = <String>[];
        late final WorkingRouter router;
        router = _buildRouter(
          beforeLeave: () {
            calls.add('beforeLeave:${router.nullableData!.uri.path}');
            return leave.future;
          },
          decideTransition: (_, transition) {
            calls.add(
              'decide:${transition.to.uri.path}:${transition.reason.name}',
            );
            if (transition.to.uri.path == '/a') {
              return RedirectTransition.toUri(Uri(path: '/c'));
            }
            return const AllowTransition();
          },
          onTransitionCommitted: (transition) {
            final currentPath = router.nullableData?.uri.path ?? '<null>';
            calls.add(
              'committed:$currentPath->'
              '${transition.to.uri.path}:${transition.reason.name}',
            );
          },
        );
        router.addListener(() {
          calls.add('listener:${router.nullableData!.uri.path}');
        });

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/a/b'));
        await tester.pumpAndSettle();
        calls.clear();

        router.routeToUri(Uri(path: '/a'));
        await tester.pump();

        expect(calls, [
          'decide:/a:programmatic',
          'decide:/c:redirect',
          'beforeLeave:/a/b',
        ]);
        expect(router.nullableData!.uri.path, '/a/b');

        leave.complete(true);
        await tester.pumpAndSettle();

        expect(calls, [
          'decide:/a:programmatic',
          'decide:/c:redirect',
          'beforeLeave:/a/b',
          'committed:/a/b->/c:redirect',
          'listener:/c',
        ]);
      },
    );

    testWidgets(
      'calls TransitionDecider with null from after unmatched target',
      (
        tester,
      ) async {
        final fromValues = <WorkingRouterData?>[];
        final router = _buildRouter(
          noContentWidget: const Text('no-content'),
          decideTransition: (_, transition) {
            if (transition.to.uri.path == '/c') {
              fromValues.add(transition.from);
            }
            return const AllowTransition();
          },
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/does-not-exist'));
        await tester.pumpAndSettle();

        router.routeToUri(Uri(path: '/c'));
        await tester.pumpAndSettle();

        expect(fromValues.last, isNull);
        expect(router.nullableData!.uri.path, '/c');
        expect(find.text('c'), findsOneWidget);
      },
    );

    testWidgets('redirects transitions to URI and id targets', (tester) async {
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
            return RedirectTransition.toId(_PathId.c);
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

    testWidgets('replace browser history routes report as neglect', (
      tester,
    ) async {
      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                _BuilderLocation(
                  id: _Id.a,
                  build: (builder, location) {
                    builder.pathLiteral('remembered');
                    builder.content = Content.widget(
                      const Text('remembered'),
                    );
                  },
                ),
                _BuilderLocation(
                  id: _Id.b,
                  build: (builder, location) {
                    builder.browserHistory = RouteBrowserHistory.replace;
                    builder.pathLiteral('replaced');
                    builder.content = Content.widget(
                      const Text('replaced'),
                    );
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );
      final informationProvider =
          router.routeInformationProvider! as WorkingRouteInformationProvider;

      await _pumpRouterApp(tester, router);
      informationProvider.debugReportedTypes.clear();

      router.routeToUri(Uri(path: '/remembered'));
      await tester.pumpAndSettle();
      expect(
        informationProvider.debugReportedTypes.last,
        isNot(
          RouteInformationReportingType.neglect,
        ),
      );

      informationProvider.debugReportedTypes.clear();
      router.routeToUri(Uri(path: '/replaced'));
      await tester.pumpAndSettle();
      expect(
        informationProvider.debugReportedTypes.last,
        RouteInformationReportingType.neglect,
      );

      informationProvider.debugReportedTypes.clear();
      router.routeToUri(Uri(path: '/remembered'));
      await tester.pumpAndSettle();
      expect(
        informationProvider.debugReportedTypes.last,
        RouteInformationReportingType.neglect,
      );
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
      final itemLocation = router.nullableData!.routeNodes
          .whereType<_ItemLocation>()
          .last;
      expect(router.nullableData!.uri.path, '/item/42/details');
      expect(router.nullableData!.paramOrNull(itemLocation.idParameter), '42');

      router.routeBack();
      await tester.pump();
      expect(router.nullableData!.uri.path, '/item/42');
      expect(router.nullableData!.paramOrNull(itemLocation.idParameter), '42');
      expect(router.nullableData!.queryParameters.unlock, {'keep': '1'});

      router.routeBack();
      await tester.pump();
      expect(router.nullableData!.uri.path, '/');
      expect(
        router.nullableData!.paramOrNull(itemLocation.idParameter),
        isNull,
      );
      expect(router.nullableData!.queryParameters.isEmpty, true);
    });

    testWidgets('routeBackFrom ignores deeper active descendants', (
      tester,
    ) async {
      final router = _buildRouter();

      router.routeToUri(Uri.parse('/a/b'));
      await tester.pump();

      final ancestorLocation = router.nullableData!.routeNodes
          .whereType<_PathLocation>()
          .singleWhere((location) => location.id == _PathId.a);

      router.routeBackFrom(ancestorLocation);
      await tester.pump();

      expect(router.nullableData!.uri.path, '/');
      expect(
        router.nullableData!.routeNodes
            .whereType<AnyLocation>()
            .map((location) => location.id)
            .toList(),
        [_PathId.root],
      );
    });

    testWidgets(
      'non-rendering location leaves its parent page visible while staying active',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.content = Content.widget(const Text('root'));
                builder.children = [
                  _BuilderLocation(
                    id: _Id.a,
                    build: (builder, location) {
                      builder.pathLiteral('settings');
                      builder.content = Content.widget(const Text('settings'));
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          build: (builder, location) {
                            builder.pathLiteral('edit');
                            builder.content = const Content.none();
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/settings/edit'));
        await tester.pumpAndSettle();

        expect(find.text('settings'), findsOneWidget);
        expect(find.text('root'), findsNothing);
        expect(router.nullableData!.uri.path, '/settings/edit');
        expect(router.nullableData!.leaf?.id, _Id.b);
      },
    );

    testWidgets(
      'routeToId keeps query parameters shared by current and target chains',
      (tester) async {
        final router = _buildParamRouter();

        router.routeToUri(Uri.parse('/item/42/details?keep=1&detail=2&drop=3'));
        await tester.pump();

        router.routeToId(
          _ParamId.item,
          writePathParameters: (node, path) {
            if (node is _ItemLocation) {
              path(node.boundIdParameter, '42');
            }
          },
        );
        await tester.pump();

        expect(router.nullableData!.uri.path, '/item/42');
        expect(router.nullableData!.queryParameters.unlock, {'keep': '1'});
      },
    );

    testWidgets('routeToId throws for structural route node ids', (
      tester,
    ) async {
      final shellId = NodeId<Shell>();
      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.content = Content.widget(const Text('root'));
              builder.children = [
                Shell(
                  id: shellId,
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('shell');
                    builder.children = [
                      _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathLiteral('detail');
                          builder.content = Content.widget(
                            const Text('detail'),
                          );
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);

      expect(
        () => router.routeToId(shellId),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('only supports ids declared on locations'),
          ),
        ),
      );
    });

    testWidgets(
      'keeps unmatched uri and empty matched state for unknown path',
      (
        tester,
      ) async {
        final router = _buildRouter();

        router.routeToUri(
          Uri(path: '/does-not-exist', queryParameters: {'q': '1'}),
        );
        await tester.pump();

        final data = router.nullableData!;
        expect(data.routeNodes, isEmpty);
        expect(data.leaf, isNull);
        expect(data.uri.path, '/does-not-exist');
        expect(data.uri.queryParameters['q'], '1');
        expect(data.queryParameters, isEmpty);
      },
    );

    testWidgets('routeToChildWhere is a no-op for unknown path', (
      tester,
    ) async {
      final router = _buildRouter();

      router.routeToUri(Uri(path: '/does-not-exist'));
      await tester.pump();

      expect(
        () => router.routeToChildWhere((location) => location.id == _PathId.b),
        returnsNormally,
      );
      await tester.pump();

      expect(router.nullableData!.routeNodes, isEmpty);
      expect(router.nullableData!.uri.path, '/does-not-exist');
    });

    testWidgets('routeToChildWhere appends matching child stack', (
      tester,
    ) async {
      final router = _buildRouter();

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();
      expect(router.nullableData!.uri.path, '/a');

      router.routeToChildWhere((location) => location.id == _PathId.b);
      await tester.pump();
      expect(router.nullableData!.uri.path, '/a/b');
    });

    testWidgets('buildPageKey receives the current router data', (
      tester,
    ) async {
      var sawExpectedData = false;
      final keys = <Object, LocalKey>{};

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _PathLocation(
            id: _PathId.root,
            path: '',
            children: [
              _PathLocation(
                id: _PathId.a,
                path: 'a',
                child: const Text('a'),
                pageKey: PageKey.custom((data) {
                  sawExpectedData =
                      data.uri.path == '/a/b' &&
                      data.leaf?.id == _PathId.b &&
                      data.routeNodes.any((it) => it.id == _PathId.a);
                  final key = ValueKey('${_PathId.a}:${data.uri.path}');
                  keys[_PathId.a] = key;
                  return key;
                }),
                children: [
                  _PathLocation(
                    id: _PathId.b,
                    path: 'b',
                    child: const Text('b'),
                    children: [],
                  ),
                ],
              ),
            ],
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      router.routeToUri(Uri(path: '/a/b'));
      await tester.pump();

      expect(sawExpectedData, isTrue);
      expect(keys[_PathId.a], ValueKey('${_PathId.a}:/a/b'));
    });

    testWidgets('dsl buildPageKey receives the current router data', (
      tester,
    ) async {
      var sawExpectedData = false;
      LocalKey? pageKey;

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.content = Content.widget(const Text('root'));
              builder.children = [
                _BuilderLocation(
                  id: _Id.a,
                  build: (builder, location) {
                    builder.pathLiteral('a');
                    builder.pageKey = PageKey.custom((data) {
                      sawExpectedData =
                          data.uri.path == '/a' && data.leaf?.id == _Id.a;
                      return ValueKey('dsl:${data.uri.path}');
                    });
                    builder.content = Content.widget(const Text('a'));
                    builder.page = (key, child) {
                      pageKey = key;
                      return MaterialPage<dynamic>(key: key, child: child);
                    };
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      router.routeToUri(Uri(path: '/a'));
      await tester.pump();

      expect(sawExpectedData, isTrue);
      expect(pageKey, const ValueKey('dsl:/a'));
    });

    testWidgets('wrapLocationChild receives the current router data', (
      tester,
    ) async {
      var sawExpectedData = false;

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _PathLocation(
            id: _PathId.root,
            path: '',
            children: [
              _PathLocation(
                id: _PathId.a,
                path: 'a',
                children: [
                  _PathLocation(
                    id: _PathId.b,
                    path: 'b',
                    child: const Text('b'),
                    children: [],
                  ),
                ],
              ),
            ],
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
        wrapLocationChild: (context, location, data, child) {
          if (location.id == _PathId.b) {
            final inheritedData = WorkingRouterData.of(context);
            sawExpectedData =
                identical(inheritedData, data) &&
                data.uri.path == '/a/b' &&
                data.leaf?.id == _PathId.b;
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
      expect(find.text('wrapped ${_PathId.b} at /a/b'), findsOneWidget);
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
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _PathLocation(
              id: _PathId.root,
              path: '',
              children: [
                _PathLocation(
                  id: _PathId.a,
                  path: 'a',
                  children: includeB
                      ? [
                          _PathLocation(id: _PathId.b, path: 'b', children: []),
                        ]
                      : const [],
                ),
              ],
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        router.routeToUri(Uri(path: '/a/b'));
        await tester.pump();
        expect(router.nullableData!.leaf?.id, _PathId.b);

        includeB = false;
        router.refresh();
        await tester.pump();

        expect(router.nullableData!.routeNodes, isEmpty);
        expect(router.nullableData!.uri.path, '/a/b');
      },
    );

    testWidgets(
      'supports self-built locations below non-rendering parents',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _MigratingRootLocation(
              id: _MigratingId.root,
              children: [
                _SelfBuiltAccountLocation(id: _MigratingId.account),
              ],
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(
          Uri(path: '/accounts/42', queryParameters: {'tab': 'overview'}),
        );
        await tester.pumpAndSettle();

        expect(find.text('42:overview'), findsOneWidget);
      },
    );

    testWidgets(
      'scopes share query params with children without building pages',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderScope(
                    build: (builder, scope) {
                      final languageCode = builder.defaultStringQueryParam(
                        'languageCode',
                        defaultValue: 'en',
                      );
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.a,
                          build: (builder, location) {
                            builder.pathLiteral('privacy');
                            builder.content = Content.builder((context, data) {
                              return Text(data.param(languageCode));
                            });
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(
          Uri(path: '/privacy', queryParameters: {'languageCode': 'de'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('de'), findsOneWidget);

        router.routeToUri(Uri(path: '/privacy'));
        await tester.pumpAndSettle();
        expect(find.text('en'), findsOneWidget);
      },
    );

    testWidgets('typed query writes omit default values', (tester) async {
      late QueryParam<String> languageCode;
      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                _BuilderScope(
                  build: (builder, scope) {
                    languageCode = builder.defaultStringQueryParam(
                      'languageCode',
                      defaultValue: 'en',
                    );
                    builder.children = [
                      _BuilderLocation(
                        id: _Id.a,
                        build: (builder, location) {
                          builder.pathLiteral('privacy');
                          builder.content = Content.builder((context, data) {
                            return Text(data.param(languageCode));
                          });
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToId(
        _Id.a,
        writeQueryParameters: (node, query) {
          if (node.queryParameters.any(
            (it) => identical(it, languageCode),
          )) {
            query(languageCode, 'en');
          }
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('en'), findsOneWidget);
      expect(router.nullableData!.uri, Uri(path: '/privacy'));
      expect(router.nullableData!.queryParameters.isEmpty, true);

      router.routeToId(
        _Id.a,
        writeQueryParameters: (node, query) {
          if (node.queryParameters.any(
            (it) => identical(it, languageCode),
          )) {
            query(languageCode, 'de');
          }
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('de'), findsOneWidget);
      expect(
        router.nullableData!.uri,
        Uri(path: '/privacy', queryParameters: {'languageCode': 'de'}),
      );
      expect(router.nullableData!.queryParameters.unlock, {
        'languageCode': 'de',
      });

      router.routeToId(
        _Id.a,
        writeQueryParameters: (node, query) {
          if (node.queryParameters.any(
            (it) => identical(it, languageCode),
          )) {
            query(languageCode, 'en');
          }
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('en'), findsOneWidget);
      expect(router.nullableData!.uri, Uri(path: '/privacy'));
      expect(router.nullableData!.queryParameters.isEmpty, true);
    });

    testWidgets('shells share path and query params with children', (
      tester,
    ) async {
      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                Shell(
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('accounts');
                    final accountId = builder.stringPathParam();
                    final tab = builder.defaultStringQueryParam(
                      'tab',
                      defaultValue: 'overview',
                    );
                    builder.children = [
                      _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathLiteral('dashboard');
                          builder.content = Content.builder((context, data) {
                            return Text(
                              '${data.param(accountId)}:${data.param(tab)}',
                            );
                          });
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(
        Uri(
          path: '/accounts/42/dashboard',
          queryParameters: {'tab': 'billing'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('42:billing'), findsOneWidget);
      expect(router.nullableData!.uri.path, '/accounts/42/dashboard');
    });

    testWidgets(
      'shell locations render an outer shell page and an inner location page',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderShellLocation(
                    build: (builder, location, _) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.shellContent = ShellContent.builder((
                        context,
                        data,
                        child,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('shell'),
                            SizedBox(height: 80, child: child),
                          ],
                        );
                      });
                      builder.content = Content.builder((context, data) {
                        return Text('settings:${data.param(accountId)}');
                      });
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/accounts/42'));
        await tester.pumpAndSettle();

        expect(find.text('shell'), findsOneWidget);
        expect(find.text('settings:42'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(2),
        );
      },
    );

    testWidgets(
      'popping a shell location page removes its nested child locations',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderLocation(
                    id: _Id.a,
                    build: (builder, location) {
                      builder.pathLiteral('dashboard');
                      builder.content = Content.widget(
                        const Text('dashboard'),
                      );
                      builder.children = [
                        _BuilderShellLocation(
                          build: (builder, location, _) {
                            builder.pathLiteral('settings');
                            builder.shellContent = ShellContent.builder((
                              context,
                              data,
                              child,
                            ) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('settings-shell'),
                                  SizedBox(height: 80, child: child),
                                ],
                              );
                            });
                            builder.content = Content.widget(
                              const Text('settings'),
                            );
                            builder.children = [
                              _BuilderLocation(
                                id: _Id.b,
                                build: (builder, location) {
                                  builder.pathLiteral('theme');
                                  builder.content = Content.widget(
                                    const Text('theme'),
                                  );
                                },
                              ),
                            ];
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/dashboard/settings/theme'));
        await tester.pumpAndSettle();

        expect(find.text('settings-shell'), findsOneWidget);
        expect(find.text('theme'), findsOneWidget);
        expect(
          router.nullableData!.uri,
          Uri(path: '/dashboard/settings/theme'),
        );

        final rootNavigator = tester.state<NavigatorState>(
          find
              .ancestor(
                of: find.text('settings-shell'),
                matching: find.byType(Navigator),
              )
              .first,
        );
        final didPop = await rootNavigator.maybePop();
        await tester.pumpAndSettle();

        expect(didPop, true);
        expect(find.text('dashboard'), findsOneWidget);
        expect(find.text('settings-shell'), findsNothing);
        expect(find.text('theme'), findsNothing);
        expect(router.nullableData!.uri, Uri(path: '/dashboard'));
      },
    );

    testWidgets('shell without matching child is treated as unresolved', (
      tester,
    ) async {
      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                Shell(
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('accounts');
                    builder.stringPathParam();
                    builder.children = [
                      _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathLiteral('dashboard');
                          builder.content = Content.widget(
                            const Text('dashboard'),
                          );
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const Text('no-content'),
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(Uri(path: '/accounts/42'));
      await tester.pumpAndSettle();

      expect(find.text('no-content'), findsOneWidget);
      expect(router.nullableData!.routeNodes, isEmpty);
      expect(router.nullableData!.uri.path, '/accounts/42');
    });

    testWidgets(
      'shell renders default content when matched descendants use the parent navigator',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (rootRouterKey) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  Shell(
                    build: (builder, shell, routerKey) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.defaultContent = DefaultContent.builder((
                        context,
                        data,
                      ) {
                        return Text('default:${data.param(accountId)}');
                      });
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: rootRouterKey,
                          build: (builder, location) {
                            builder.pathLiteral('dashboard');
                            builder.content = Content.builder((context, data) {
                              return Text(
                                'dashboard:${data.param(accountId)}',
                              );
                            });
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/accounts/42/dashboard'));
        await tester.pumpAndSettle();

        expect(find.text('default:42', skipOffstage: false), findsOneWidget);
        expect(find.text('dashboard:42'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(
            find.byType(Navigator, skipOffstage: false),
          ),
          hasLength(2),
        );
      },
    );

    testWidgets('routeToId can write shell path parameters', (tester) async {
      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                Shell(
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('accounts');
                    final accountId = builder.stringPathParam();
                    builder.children = [
                      _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathLiteral('dashboard');
                          builder.content = Content.builder((context, data) {
                            return Text(data.param(accountId));
                          });
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToId(
        _Id.b,
        writePathParameters: (node, path) {
          if (node is Shell) {
            path(node.pathParameters.single as PathParam<String>, '42');
          }
        },
      );
      await tester.pumpAndSettle();

      expect(router.nullableData!.uri.path, '/accounts/42/dashboard');
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets(
      'bindParam supports reusable unbound params with nullable outer access',
      (tester) async {
        const accountId = UnboundPathParam<String>(StringRouteParamCodec());
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderLocation(
                    id: _Id.a,
                    build: (builder, location) {
                      builder.pathLiteral('accounts');
                      final boundAccountId = builder.bindParam(accountId);
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          build: (builder, location) {
                            builder.pathLiteral('dashboard');
                            builder.content = Content.builder((context, data) {
                              return Text(
                                '${data.param(boundAccountId)}:${data.paramOrNull(accountId)}',
                              );
                            });
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri.parse('/accounts/42/dashboard'));
        await tester.pumpAndSettle();

        expect(find.text('42:42'), findsOneWidget);
      },
    );

    testWidgets('enabled shell throws when matched children are routed to root', (
      tester,
    ) async {
      final router = WorkingRouter(
        buildRouteNodes: (rootRouterKey) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                Shell(
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('accounts');
                    final accountId = builder.stringPathParam();
                    builder.children = [
                      _BuilderLocation(
                        id: _Id.b,
                        parentRouterKey: rootRouterKey,
                        build: (builder, location) {
                          builder.pathLiteral('dashboard');
                          builder.content = Content.builder((context, data) {
                            return Text(data.param(accountId));
                          });
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(Uri(path: '/accounts/42/dashboard'));
      await tester.pump();

      expect(
        tester.takeException(),
        isA<StateError>().having(
          (it) => it.message,
          'message',
          allOf([
            contains('Enabled shell Shell'),
            contains(
              'has matched descendants, but none are assigned to its routerKey.',
            ),
          ]),
        ),
      );
    });

    testWidgets(
      'enabled shell renders matched shell location with default content',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  Shell(
                    build: (builder, shell, _) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.content = ShellContent.builder((
                        context,
                        data,
                        child,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('account:${data.param(accountId)}'),
                            SizedBox(height: 160, child: child),
                          ],
                        );
                      });
                      builder.children = [
                        _BuilderShellLocation(
                          build: (builder, location, _) {
                            builder.pathLiteral('notice-board');
                            builder.shellContent = ShellContent.builder((
                              context,
                              data,
                              child,
                            ) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('notice-shell'),
                                  SizedBox(height: 80, child: child),
                                ],
                              );
                            });
                            builder.defaultContent = DefaultContent.widget(
                              const Text('select-notice'),
                            );
                            builder.content = const Content.none();
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/accounts/42/notice-board'));
        await tester.pumpAndSettle();

        expect(find.text('account:42'), findsOneWidget);
        expect(find.text('notice-shell'), findsOneWidget);
        expect(find.text('select-notice'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(3),
        );
      },
    );

    testWidgets(
      'enabled shell renders matched multi shell location content default',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  Shell(
                    build: (builder, shell, _) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.content = ShellContent.builder((
                        context,
                        data,
                        child,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('account:${data.param(accountId)}'),
                            SizedBox(height: 160, child: child),
                          ],
                        );
                      });
                      builder.children = [
                        _BuilderMultiShellLocation(
                          build: (builder, location, contentSlot) {
                            builder.pathLiteral('notice-board');
                            builder.shellContent = MultiShellContent.builder((
                              context,
                              data,
                              slots,
                            ) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('notice-shell'),
                                  SizedBox(
                                    height: 80,
                                    child: slots.child(contentSlot),
                                  ),
                                ],
                              );
                            });
                            builder.defaultContent = DefaultContent.widget(
                              const Text('select-notice'),
                            );
                            builder.content = const Content.none();
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/accounts/42/notice-board'));
        await tester.pumpAndSettle();

        expect(find.text('account:42'), findsOneWidget);
        expect(find.text('notice-shell'), findsOneWidget);
        expect(find.text('select-notice'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(3),
        );
      },
    );

    testWidgets(
      'disabled shell routes implicit and explicit shell children to parent navigator',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  Shell(
                    navigatorEnabled: false,
                    build: (builder, shell, routerKey) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          build: (builder, location) {
                            builder.pathLiteral('dashboard');
                            builder.content = Content.builder((context, data) {
                              return Text(
                                'dashboard:${data.param(accountId)}',
                              );
                            });
                          },
                        ),
                        _BuilderLocation(
                          id: _Id.c,
                          parentRouterKey: routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('details');
                            builder.content = Content.builder((context, data) {
                              return Text(
                                'details:${data.param(accountId)}',
                              );
                            });
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/accounts/42/details'));
        await tester.pumpAndSettle();

        expect(find.text('details:42'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'disabled shell location renders on parent navigator and aliases its router key',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderShellLocation(
                    navigatorEnabled: false,
                    build: (builder, location, routerKey) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.content = Content.builder((context, data) {
                        return Text('settings:${data.param(accountId)}');
                      });
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.c,
                          parentRouterKey: routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('details');
                            builder.content = Content.builder((context, data) {
                              return Text(
                                'details:${data.param(accountId)}',
                              );
                            });
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/accounts/42'));
        await tester.pumpAndSettle();

        expect(find.text('settings:42'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(1),
        );

        router.routeToUri(Uri(path: '/accounts/42/details'));
        await tester.pumpAndSettle();

        expect(find.text('details:42'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'shell location supports Content.none when default content is configured',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderShellLocation(
                    build: (builder, location, routerKey) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.shellContent = ShellContent.builder((
                        context,
                        data,
                        child,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('shell'),
                            SizedBox(height: 80, child: child),
                          ],
                        );
                      });
                      builder.defaultContent = DefaultContent.builder((
                        context,
                        data,
                      ) {
                        return Text('placeholder:${data.param(accountId)}');
                      });
                      builder.content = const Content.none();
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.c,
                          parentRouterKey: routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('details');
                            builder.content = Content.builder((context, data) {
                              return Text(
                                'details:${data.param(accountId)}',
                              );
                            });
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/accounts/42'));
        await tester.pumpAndSettle();

        expect(find.text('shell'), findsOneWidget);
        expect(find.text('placeholder:42'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(2),
        );
      },
    );

    testWidgets(
      'multi shell location renders sibling slot and content navigators',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation(
                    build: (builder, location, contentSlot) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(debugLabel: 'left');
                      builder.shellContent = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 80,
                              child: slots.child(leftSlot),
                            ),
                            SizedBox(
                              height: 80,
                              child: slots.child(contentSlot),
                            ),
                          ],
                        );
                      });
                      builder.content = Content.widget(const Text('empty'));
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation(
                                id: _Id.c,
                                parentRouterKey: contentSlot.routerKey,
                                build: (builder, location) {
                                  builder.pathLiteral('detail');
                                  builder.content = Content.widget(
                                    const Text('detail'),
                                  );
                                },
                              ),
                            ];
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat/search/detail'));
        await tester.pumpAndSettle();

        expect(find.text('search'), findsOneWidget);
        expect(find.text('detail'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(3),
        );
      },
    );

    testWidgets(
      'multi shell renders sibling slots',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShell(
                    build: (builder, shell) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(debugLabel: 'left');
                      final detailSlot = builder.slot(debugLabel: 'detail');
                      builder.content = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 80,
                              child: slots.child(leftSlot),
                            ),
                            SizedBox(
                              height: 80,
                              child: slots.child(detailSlot),
                            ),
                          ],
                        );
                      });
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation(
                                id: _Id.c,
                                parentRouterKey: detailSlot.routerKey,
                                build: (builder, location) {
                                  builder.pathLiteral('detail');
                                  builder.content = Content.widget(
                                    const Text('detail'),
                                  );
                                },
                              ),
                            ];
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat/search/detail'));
        await tester.pumpAndSettle();

        expect(find.text('search'), findsOneWidget);
        expect(find.text('detail'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(3),
        );
      },
    );

    testWidgets(
      'disabled multi shell location aliases content and slot navigators to the parent navigator',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation(
                    navigatorEnabled: false,
                    build: (builder, location, contentSlot) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(debugLabel: 'left');
                      builder.shellContent = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Row(
                          children: [
                            Expanded(child: slots.child(leftSlot)),
                            Expanded(child: slots.child(contentSlot)),
                          ],
                        );
                      });
                      builder.content = Content.widget(const Text('empty'));
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation(
                                id: _Id.c,
                                parentRouterKey: contentSlot.routerKey,
                                build: (builder, location) {
                                  builder.pathLiteral('detail');
                                  builder.content = Content.widget(
                                    const Text('detail'),
                                  );
                                },
                              ),
                            ];
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat/search/detail'));
        await tester.pumpAndSettle();

        expect(find.text('detail'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'disabled multi shell aliases slot navigators to the parent navigator',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShell(
                    navigatorEnabled: false,
                    build: (builder, shell) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(debugLabel: 'left');
                      final detailSlot = builder.slot(debugLabel: 'detail');
                      builder.content = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Row(
                          children: [
                            Expanded(child: slots.child(leftSlot)),
                            Expanded(child: slots.child(detailSlot)),
                          ],
                        );
                      });
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation(
                                id: _Id.c,
                                parentRouterKey: detailSlot.routerKey,
                                build: (builder, location) {
                                  builder.pathLiteral('detail');
                                  builder.content = Content.widget(
                                    const Text('detail'),
                                  );
                                },
                              ),
                            ];
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat/search/detail'));
        await tester.pumpAndSettle();

        expect(find.text('detail'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'multi shell renders default content for enabled slot without routed content',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShell(
                    build: (builder, shell) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(
                        debugLabel: 'left',
                        defaultContent: DefaultContent.widget(
                          const Text('default-list'),
                        ),
                      );
                      final detailSlot = builder.slot(debugLabel: 'detail');
                      builder.content = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 80,
                              child: slots.child(leftSlot),
                            ),
                            SizedBox(
                              height: 80,
                              child: slots.child(detailSlot),
                            ),
                          ],
                        );
                      });
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: detailSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('detail');
                            builder.content = Content.widget(
                              const Text('detail'),
                            );
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat/detail'));
        await tester.pumpAndSettle();

        expect(find.text('default-list'), findsOneWidget);
        expect(find.text('detail'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(3),
        );
      },
    );

    testWidgets(
      'multi shell location renders default content for enabled extra slot without routed content',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation(
                    build: (builder, location, contentSlot) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(
                        debugLabel: 'left',
                        defaultContent: DefaultContent.widget(
                          const Text('default-list'),
                        ),
                      );
                      builder.shellContent = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 80,
                              child: slots.child(leftSlot),
                            ),
                            SizedBox(
                              height: 80,
                              child: slots.child(contentSlot),
                            ),
                          ],
                        );
                      });
                      builder.content = Content.widget(const Text('detail'));
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat'));
        await tester.pumpAndSettle();

        expect(find.text('default-list'), findsOneWidget);
        expect(find.text('detail'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(3),
        );
      },
    );

    testWidgets(
      'multi shell location supports Content.none with default content for the content slot',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation(
                    build: (builder, location, contentSlot) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(
                        debugLabel: 'left',
                        defaultContent: DefaultContent.widget(
                          const Text('default-list'),
                        ),
                      );
                      builder.shellContent = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 80,
                              child: slots.child(leftSlot),
                            ),
                            SizedBox(
                              height: 80,
                              child: slots.child(contentSlot),
                            ),
                          ],
                        );
                      });
                      builder.defaultContent = DefaultContent.widget(
                        const Text('placeholder'),
                      );
                      builder.content = const Content.none();
                      builder.page = (key, child) {
                        return MaterialPage<dynamic>(
                          key: key,
                          child: child,
                        );
                      };
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat'));
        await tester.pumpAndSettle();

        expect(find.text('default-list'), findsOneWidget);
        expect(find.text('placeholder'), findsOneWidget);
        expect(
          tester.widgetList<Navigator>(find.byType(Navigator)),
          hasLength(3),
        );
      },
    );

    test(
      'page without content reports route context and assignment stack',
      () {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.pathLiteral('chat');
                builder.page = (key, child) {
                  return MaterialPage<dynamic>(
                    key: key,
                    child: child,
                  );
                };
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        Object? thrownError;
        StackTrace? thrownStackTrace;
        try {
          router.routeToUri(Uri(path: '/chat'));
        } catch (error, stackTrace) {
          thrownError = error;
          thrownStackTrace = stackTrace;
        }

        expect(
          thrownError,
          isA<StateError>().having(
            (it) => it.message,
            'message',
            allOf([
              contains(
                'LocationBuilder page was configured without content.',
              ),
              contains('node: _BuilderLocation'),
              contains('builder: LocationBuilder'),
              contains('node-local path: /chat'),
              contains('Content.none'),
            ]),
          ),
        );
        expect(
          thrownStackTrace.toString().split('\n').first,
          contains('LocationBuilder.page='),
        );
      },
    );

    testWidgets(
      'multi shell slot keeps the same navigator between default and routed pages',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation(
                    build: (builder, location, contentSlot) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(
                        debugLabel: 'left',
                        defaultContent: DefaultContent.widget(
                          const Text('default-list'),
                        ),
                      );
                      builder.shellContent = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Row(
                          children: [
                            Expanded(child: slots.child(leftSlot)),
                            Expanded(child: slots.child(contentSlot)),
                          ],
                        );
                      });
                      builder.content = Content.widget(
                        const Text('detail-root'),
                      );
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat'));
        await tester.pumpAndSettle();

        final defaultNavigatorFinder = find.ancestor(
          of: find.text('default-list'),
          matching: find.byType(Navigator),
        );
        final defaultNavigatorState = tester.state<NavigatorState>(
          defaultNavigatorFinder.first,
        );

        router.routeToUri(Uri(path: '/chat/search'));
        await tester.pumpAndSettle();

        final searchNavigatorFinder = find.ancestor(
          of: find.text('search'),
          matching: find.byType(Navigator),
        );
        final searchNavigatorState = tester.state<NavigatorState>(
          searchNavigatorFinder.first,
        );

        expect(identical(searchNavigatorState, defaultNavigatorState), isTrue);
      },
    );

    testWidgets(
      'multi shell throws when enabled slot has neither routed content nor default',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShell(
                    build: (builder, shell) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(debugLabel: 'left');
                      final detailSlot = builder.slot(debugLabel: 'detail');
                      builder.content = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 80,
                              child: slots.child(leftSlot),
                            ),
                            SizedBox(
                              height: 80,
                              child: slots.child(detailSlot),
                            ),
                          ],
                        );
                      });
                      builder.children = [
                        _BuilderLocation(
                          id: _Id.b,
                          parentRouterKey: detailSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('detail');
                            builder.content = Content.widget(
                              const Text('detail'),
                            );
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat/detail'));
        await tester.pump();

        expect(
          tester.takeException(),
          isA<StateError>().having(
            (it) => it.message,
            'message',
            contains(
              'Enabled slot MultiShellSlot(left) has neither routed content nor default content.',
            ),
          ),
        );
      },
    );

    testWidgets(
      'childOrNull returns null for disabled slot',
      (tester) async {
        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation(
                    build: (builder, location, contentSlot) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(
                        debugLabel: 'left',
                        navigatorEnabled: false,
                      );
                      builder.shellContent = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        final leftChild = slots.childOrNull(leftSlot);
                        return Row(
                          children: [
                            if (leftChild != null) Expanded(child: leftChild),
                            Expanded(child: slots.child(contentSlot)),
                          ],
                        );
                      });
                      builder.content = Content.widget(const Text('detail'));
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat'));
        await tester.pumpAndSettle();

        expect(find.text('detail'), findsOneWidget);
        expect(find.byType(Expanded), findsOneWidget);
      },
    );

    testWidgets('query overlay renders in slot and preserves primary content', (
      tester,
    ) async {
      late _BuilderMultiShellLocation chat;
      late _BuilderOverlay search;
      late _ChannelLocation channel;

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                chat = _BuilderMultiShellLocation(
                  build: (builder, location, contentSlot) {
                    builder.pathLiteral('chat');
                    final chatDisplay = builder.defaultStringQueryParam(
                      'chatDisplay',
                      defaultValue: 'list',
                    );
                    final searchScope = builder.defaultStringQueryParam(
                      'searchScope',
                      defaultValue: 'local',
                    );
                    final leftSlot = builder.slot(
                      debugLabel: 'left',
                      defaultContent: DefaultContent.widget(
                        const Text('list'),
                      ),
                    );
                    builder.shellContent = MultiShellContent.builder((
                      context,
                      data,
                      slots,
                    ) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 80, child: slots.child(leftSlot)),
                          SizedBox(
                            height: 80,
                            child: slots.child(contentSlot),
                          ),
                        ],
                      );
                    });
                    builder.content = Content.widget(const Text('empty'));
                    builder.overlays = [
                      search = _BuilderOverlay(
                        id: _overlaySearchId,
                        parentRouterKey: leftSlot.routerKey,
                        build: (builder, location) {
                          builder.conditions = [
                            chatDisplay.matches('search'),
                            searchScope.matches('global'),
                          ];
                          builder.content = Content.builder((context, data) {
                            return TextButton(
                              onPressed: () {
                                WorkingRouter.of(context).routeBack();
                              },
                              child: const Text('search'),
                            );
                          });
                        },
                      ),
                    ];
                    channel = _ChannelLocation(
                      parentRouterKey: contentSlot.routerKey,
                    );
                    builder.children = [channel];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(Uri(path: '/chat/channel/42'));
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
      expect(find.text('channel:42'), findsOneWidget);
      expect(find.text('search'), findsNothing);
      expect(router.nullableData!.uri, Uri(path: '/chat/channel/42'));

      router.routeTo(
        OverlayRouteTarget(
          owner: chat,
          overlay: search,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('search'), findsOneWidget);
      expect(find.text('channel:42'), findsOneWidget);
      expect(router.nullableData!.leaf, same(channel));
      expect(
        router.nullableData!.isMatched(
          (node) => node is _BuilderOverlay && identical(node, search),
        ),
        isTrue,
      );
      expect(router.nullableData!.leaf, isNot(same(search)));
      expect(
        router.nullableData!.uri,
        Uri(
          path: '/chat/channel/42',
          queryParameters: {
            'chatDisplay': 'search',
            'searchScope': 'global',
          },
        ),
      );
      final searchUri = router.nullableConfiguration!.uri;

      router.routeTo(
        ChildRouteTarget(
          start: chat,
          resolveChildPathNodes: () => <RouteNode>[channel].toIList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('list'), findsNothing);
      expect(find.text('search'), findsOneWidget);
      expect(find.text('channel:42'), findsOneWidget);
      expect(router.nullableData!.uri, searchUri);

      router.routeToUri(searchUri);
      await tester.pumpAndSettle();

      await tester.tap(find.text('search'));
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
      expect(find.text('search'), findsNothing);
      expect(find.text('channel:42'), findsOneWidget);
      expect(router.nullableData!.uri, Uri(path: '/chat/channel/42'));

      router.routeToUri(searchUri);
      await tester.pumpAndSettle();

      expect(find.text('search'), findsOneWidget);
      expect(find.text('channel:42'), findsOneWidget);
      expect(
        router.nullableData!.uri,
        Uri(
          path: '/chat/channel/42',
          queryParameters: {
            'chatDisplay': 'search',
            'searchScope': 'global',
          },
        ),
      );

      final contentNavigator = tester.state<NavigatorState>(
        find
            .ancestor(
              of: find.text('channel:42'),
              matching: find.byType(Navigator),
            )
            .first,
      );
      final didPopContent = await contentNavigator.maybePop();
      await tester.pumpAndSettle();

      expect(didPopContent, true);
      expect(find.text('search'), findsOneWidget);
      expect(find.text('channel:42'), findsNothing);
      expect(
        router.nullableData!.uri,
        Uri(
          path: '/chat',
          queryParameters: {
            'chatDisplay': 'search',
            'searchScope': 'global',
          },
        ),
      );

      router.routeToUri(searchUri);
      await tester.pumpAndSettle();

      final searchNavigator = tester.state<NavigatorState>(
        find
            .ancestor(of: find.text('search'), matching: find.byType(Navigator))
            .first,
      );
      final didPop = await searchNavigator.maybePop();
      await tester.pumpAndSettle();

      expect(didPop, true);
      expect(find.text('list'), findsOneWidget);
      expect(find.text('search'), findsNothing);
      expect(find.text('channel:42'), findsOneWidget);
      expect(router.nullableData!.uri, Uri(path: '/chat/channel/42'));
    });

    testWidgets(
      'nested default slot uses refreshed route nodes for child targets',
      (tester) async {
        late _BuilderLocation channel;
        var resolveChildPathNodesCalls = 0;

        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation(
                    build: (builder, location, contentSlot) {
                      builder.pathLiteral('chat');
                      final leftSlot = builder.slot(
                        debugLabel: 'left',
                        defaultContent: DefaultContent.builder((
                          context,
                          data,
                        ) {
                          return TextButton(
                            onPressed: () {
                              WorkingRouter.of(context).routeTo(
                                ChildRouteTarget(
                                  start: location,
                                  resolveChildPathNodes: () {
                                    resolveChildPathNodesCalls += 1;
                                    return resolveExactChildRouteNodes(
                                      location,
                                      [(node) => identical(node, channel)],
                                    );
                                  },
                                ),
                              );
                            },
                            child: const Text('open channel'),
                          );
                        }),
                      );
                      builder.shellContent = MultiShellContent.builder((
                        context,
                        data,
                        slots,
                      ) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: 80, child: slots.child(leftSlot)),
                            SizedBox(
                              height: 80,
                              child: slots.child(contentSlot),
                            ),
                          ],
                        );
                      });
                      builder.content = Content.widget(const Text('empty'));
                      channel = _BuilderLocation(
                        id: _Id.b,
                        parentRouterKey: contentSlot.routerKey,
                        build: (builder, location) {
                          builder.pathLiteral('channel');
                          builder.content = Content.widget(
                            const Text('channel'),
                          );
                        },
                      );
                      builder.children = [channel];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat'));
        await tester.pumpAndSettle();

        router.refresh();
        await tester.pumpAndSettle();

        await tester.tap(find.text('open channel'));
        await tester.pumpAndSettle();

        expect(resolveChildPathNodesCalls, 1);
        expect(find.text('channel'), findsOneWidget);
        expect(router.nullableData!.uri, Uri(path: '/chat/channel'));
      },
    );

    testWidgets(
      'hidden route is matchable from url but omitted from generated uri',
      (tester) async {
        late _BuilderLocation chat;
        late _BuilderLocation dialog;

        final router = WorkingRouter(
          buildRouteNodes: (_) => [
            _BuilderLocation(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  chat = _BuilderLocation(
                    id: _Id.a,
                    build: (builder, location) {
                      builder.pathLiteral('chat');
                      builder.content = Content.widget(const Text('chat'));
                      builder.children = [
                        dialog = _BuilderLocation(
                          id: _Id.b,
                          build: (builder, location) {
                            builder.pathVisibility = UriVisibility.hidden;
                            builder.pathLiteral('dialog');
                            builder.content = Content.widget(
                              const Text('dialog'),
                            );
                          },
                        ),
                      ];
                    },
                  ),
                ];
              },
            ),
          ],
          noContentWidget: const SizedBox.shrink(),
        );

        await _pumpRouterApp(tester, router);
        router.routeToUri(Uri(path: '/chat'));
        await tester.pumpAndSettle();

        router.routeTo(
          ChildRouteTarget(
            start: chat,
            resolveChildPathNodes: () => <RouteNode>[dialog].toIList(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('dialog'), findsOneWidget);
        expect(router.nullableData!.uri.path, '/chat');
        final dialogRouteInformation = router.routeInformationParser!
            .restoreRouteInformation(
              router.routerDelegate.currentConfiguration!,
            )!;
        expect(dialogRouteInformation.uri, Uri(path: '/chat'));
        expect(dialogRouteInformation.state, {
          'workingRouter': {
            'hiddenPathSegments': ['dialog'],
          },
        });
        router.routeBack();
        await tester.pumpAndSettle();

        expect(find.text('chat'), findsOneWidget);
        expect(find.text('dialog'), findsNothing);
        expect(router.nullableData!.uri.path, '/chat');

        await router.routerDelegate.setNewRoutePath(
          await router.routeInformationParser!.parseRouteInformation(
            dialogRouteInformation,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('dialog'), findsOneWidget);
        expect(router.nullableData!.uri.path, '/chat');

        router.routeToUri(Uri(path: '/chat/dialog'));
        await tester.pumpAndSettle();

        expect(find.text('dialog'), findsOneWidget);
        expect(router.nullableData!.uri.path, '/chat');
      },
    );

    testWidgets('children inherit hidden parent route visibility', (
      tester,
    ) async {
      late _BuilderLocation chat;
      late _BuilderLocation hiddenParent;
      late _BuilderLocation child;

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                chat = _BuilderLocation(
                  id: _Id.a,
                  build: (builder, location) {
                    builder.pathLiteral('chat');
                    builder.content = Content.widget(const Text('chat'));
                    builder.children = [
                      hiddenParent = _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathVisibility = UriVisibility.hidden;
                          builder.pathLiteral('hidden');
                          builder.content = Content.widget(
                            const Text('hidden'),
                          );
                          builder.children = [
                            child = _BuilderLocation(
                              id: _Id.c,
                              build: (builder, location) {
                                builder.pathLiteral('child');
                                builder.content = Content.widget(
                                  const Text('child'),
                                );
                              },
                            ),
                          ];
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(Uri(path: '/chat'));
      await tester.pumpAndSettle();

      router.routeTo(
        ChildRouteTarget(
          start: chat,
          resolveChildPathNodes: () =>
              <RouteNode>[hiddenParent, child].toIList(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('child'), findsOneWidget);
      expect(router.nullableData!.uri.path, '/chat');
    });

    testWidgets('hidden query parameters stay in router state but not uri', (
      tester,
    ) async {
      late _BuilderLocation chat;
      late _BuilderLocation channel;
      late DefaultQueryParam<bool> search;

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                chat = _BuilderLocation(
                  id: _Id.a,
                  build: (builder, location) {
                    builder.pathLiteral('chat');
                    search = builder.defaultBoolQueryParam(
                      'search',
                      defaultValue: false,
                      visibility: UriVisibility.hidden,
                    );
                    builder.content = Content.widget(const Text('chat'));
                    builder.children = [
                      channel = _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathLiteral('channel');
                          builder.content = Content.widget(
                            const Text('channel'),
                          );
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(
        Uri(path: '/chat/channel', queryParameters: {'search': 'true'}),
      );
      await tester.pumpAndSettle();

      expect(find.text('channel'), findsOneWidget);
      expect(router.nullableData!.param(search), true);
      expect(router.nullableData!.queryParameters.unlock, {'search': 'true'});
      expect(router.nullableData!.uri, Uri(path: '/chat/channel'));
      final searchRouteInformation = router.routeInformationParser!
          .restoreRouteInformation(
            router.routerDelegate.currentConfiguration!,
          )!;
      expect(searchRouteInformation.uri, Uri(path: '/chat/channel'));
      expect(searchRouteInformation.state, {
        'workingRouter': {
          'hiddenQueryParameters': {'search': 'true'},
        },
      });

      router.routeToUri(Uri(path: '/chat/channel'));
      await tester.pumpAndSettle();

      expect(router.nullableData!.param(search), false);
      expect(router.nullableData!.uri, Uri(path: '/chat/channel'));

      await router.routerDelegate.setNewRoutePath(
        await router.routeInformationParser!.parseRouteInformation(
          searchRouteInformation,
        ),
      );
      await tester.pumpAndSettle();

      expect(router.nullableData!.param(search), true);
      expect(router.nullableData!.queryParameters.unlock, {'search': 'true'});
      expect(router.nullableData!.uri, Uri(path: '/chat/channel'));

      router.routeTo(
        ChildRouteTarget(
          start: chat,
          resolveChildPathNodes: () => <RouteNode>[channel].toIList(),
          writeQueryParameters: (node, query) {
            if (identical(node, chat)) {
              query(search, true);
            }
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(router.nullableData!.param(search), true);
      expect(router.nullableData!.queryParameters.unlock, {'search': 'true'});
      expect(router.nullableData!.uri, Uri(path: '/chat/channel'));
    });

    testWidgets('hidden query state-only changes report browser navigation', (
      tester,
    ) async {
      late _BuilderLocation chat;
      late _BuilderLocation channel;
      late _BuilderOverlay searchOverlay;

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                chat = _BuilderLocation(
                  id: _Id.a,
                  build: (builder, location) {
                    builder.pathLiteral('chat');
                    final search = builder.defaultBoolQueryParam(
                      'search',
                      defaultValue: false,
                      visibility: UriVisibility.hidden,
                    );
                    builder.content = Content.widget(const Text('chat'));
                    builder.overlays = [
                      searchOverlay = _BuilderOverlay(
                        id: _overlaySearchId,
                        build: (builder, location) {
                          builder.conditions = [search.matches(true)];
                          builder.content = Content.widget(
                            const Text('search'),
                          );
                        },
                      ),
                    ];
                    builder.children = [
                      channel = _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathLiteral('channel');
                          builder.content = Content.widget(
                            const Text('channel'),
                          );
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );
      final informationProvider =
          router.routeInformationProvider! as WorkingRouteInformationProvider;

      await _pumpRouterApp(tester, router);
      router.routeToUri(Uri(path: '/chat/channel'));
      await tester.pumpAndSettle();
      informationProvider.debugReportedTypes.clear();

      router.routeTo(
        OverlayRouteTarget(
          owner: chat,
          overlay: searchOverlay,
        ),
      );
      await tester.pumpAndSettle();

      expect(router.nullableData!.leaf, same(channel));
      expect(
        router.nullableData!.isMatched(
          (node) => node is _BuilderOverlay && identical(node, searchOverlay),
        ),
        isTrue,
      );
      expect(router.nullableData!.uri, Uri(path: '/chat/channel'));
      expect(router.nullableConfiguration!.hiddenQueryParameters.unlock, {
        'search': 'true',
      });
      expect(
        informationProvider.debugReportedTypes.last,
        RouteInformationReportingType.navigate,
      );
    });

    testWidgets('query parameters inherit hidden visibility by key', (
      tester,
    ) async {
      late DefaultQueryParam<String> tab;

      final router = WorkingRouter(
        buildRouteNodes: (_) => [
          _BuilderLocation(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                _BuilderLocation(
                  id: _Id.a,
                  build: (builder, location) {
                    builder.pathLiteral('chat');
                    builder.defaultStringQueryParam(
                      'tab',
                      defaultValue: 'list',
                      visibility: UriVisibility.hidden,
                    );
                    builder.content = Content.widget(const Text('chat'));
                    builder.children = [
                      _BuilderLocation(
                        id: _Id.b,
                        build: (builder, location) {
                          builder.pathLiteral('channel');
                          tab = builder.defaultStringQueryParam(
                            'tab',
                            defaultValue: 'list',
                          );
                          builder.content = Content.widget(
                            const Text('channel'),
                          );
                        },
                      ),
                    ];
                  },
                ),
              ];
            },
          ),
        ],
        noContentWidget: const SizedBox.shrink(),
      );

      await _pumpRouterApp(tester, router);
      router.routeToUri(
        Uri(path: '/chat/channel', queryParameters: {'tab': 'details'}),
      );
      await tester.pumpAndSettle();

      expect(router.nullableData!.param(tab), 'details');
      expect(router.nullableData!.queryParameters.unlock, {'tab': 'details'});
      expect(router.nullableData!.uri, Uri(path: '/chat/channel'));
    });
  });
}

Future<void> _pumpApp(WidgetTester tester, WorkingRouter router) async {
  await _pumpRouterApp(tester, router);
}

Future<void> _pumpRouterApp(
  WidgetTester tester,
  WorkingRouter router,
) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

WorkingRouter _buildRouter({
  TransitionDecider? decideTransition,
  RouteTransitionCommitted? onTransitionCommitted,
  Future<bool> Function()? beforeLeave,
  int redirectLimit = 5,
  Widget noContentWidget = const SizedBox.shrink(),
}) {
  return WorkingRouter(
    buildRouteNodes: (_) => [
      _PathLocation(
        id: _PathId.root,
        path: '',
        child: const Text('root'),
        children: [
          _PathLocation(
            id: _PathId.a,
            path: 'a',
            child: const Text('a'),
            children: [
              _PathLocation(
                id: _PathId.b,
                path: 'b',
                child: LocationObserver(
                  beforeLeave: beforeLeave,
                  child: const Text('b'),
                ),
                children: [],
              ),
            ],
          ),
          _PathLocation(
            id: _PathId.c,
            path: 'c',
            child: const Text('c'),
            children: [],
          ),
        ],
      ),
    ],
    noContentWidget: noContentWidget,
    decideTransition: decideTransition,
    onTransitionCommitted: onTransitionCommitted,
    redirectLimit: redirectLimit,
  );
}

WorkingRouter _buildOrderRouter({
  Future<bool> Function()? beforeLeaveA,
  Future<bool> Function()? beforeLeaveB,
}) {
  return WorkingRouter(
    buildRouteNodes: (_) => [
      _PathLocation(
        id: _PathId.root,
        path: '',
        child: const Text('root'),
        children: [
          _PathLocation(
            id: _PathId.a,
            path: 'a',
            child: LocationObserver(
              beforeLeave: beforeLeaveA,
              child: const Text('a'),
            ),
            children: [
              _PathLocation(
                id: _PathId.b,
                path: 'b',
                child: LocationObserver(
                  beforeLeave: beforeLeaveB,
                  child: const Text('b'),
                ),
                children: [],
              ),
            ],
          ),
          _PathLocation(
            id: _PathId.c,
            path: 'c',
            child: const Text('c'),
            children: [],
          ),
        ],
      ),
    ],
    noContentWidget: const SizedBox.shrink(),
  );
}

WorkingRouter _buildParamRouter() {
  return WorkingRouter(
    buildRouteNodes: (_) => [
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
    noContentWidget: const SizedBox.shrink(),
  );
}

abstract final class _Id {
  static final root = NodeId<_BuilderLocation>();
  static final a = NodeId<_BuilderLocation>();
  static final b = NodeId<_BuilderLocation>();
  static final c = NodeId<_BuilderLocation>();
}

abstract final class _PathId {
  static final root = NodeId<_PathLocation>();
  static final a = NodeId<_PathLocation>();
  static final b = NodeId<_PathLocation>();
  static final c = NodeId<_PathLocation>();
}

abstract final class _ParamId {
  static final root = NodeId<_ParamRootLocation>();
  static final item = NodeId<_ItemLocation>();
  static final details = NodeId<_DetailLocation>();
}

abstract final class _MigratingId {
  static final root = NodeId<_MigratingRootLocation>();
  static final account = NodeId<_SelfBuiltAccountLocation>();
}

final _overlaySearchId = NodeId<_BuilderOverlay>();

class _PathLocation extends Location<_PathLocation> {
  final List<PathSegment> _segments;
  final List<RouteNode> children;
  final Widget? child;
  final PageKey? pageKey;

  _PathLocation({
    required NodeId<_PathLocation> id,
    required String path,
    this.child,
    this.pageKey,
    this.children = const [],
  }) : _segments = _pathSegments(path),
       super(id: id);

  @override
  void build(LocationBuilder builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
    if (pageKey != null) {
      builder.pageKey = pageKey!;
    }
    if (child != null) {
      builder.content = Content.widget(child!);
    }
    builder.children = children;
  }
}

abstract class _ParamPathLocation<Self extends _ParamPathLocation<Self>>
    extends Location<Self> {
  final List<PathSegment> _segments;
  final List<RouteNode> children;

  _ParamPathLocation({
    required NodeId<Self> id,
    required String path,
    this.children = const [],
  }) : _segments = _pathSegments(path),
       super(id: id);

  @override
  void build(LocationBuilder builder) {
    register(builder);
  }

  void register(
    LocationBuilder builder,
  ) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
    builder.content = Content.builder((_, _) => Text('$id'));
    builder.children = children;
  }
}

class _ParamRootLocation extends _ParamPathLocation<_ParamRootLocation> {
  _ParamRootLocation({
    required super.id,
    List<RouteNode> children = const [],
  }) : super(
         path: '',
         children: List.unmodifiable(children),
       );
}

class _ItemLocation extends _ParamPathLocation<_ItemLocation> {
  final idParameter = const UnboundPathParam(StringRouteParamCodec());
  final keep = const RequiredUnboundQueryParam('keep', StringRouteParamCodec());
  late final PathParam<String> boundIdParameter =
      definition.pathParameters.single as PathParam<String>;
  late final QueryParam<String> boundKeep =
      definition.queryParameters.single as QueryParam<String>;

  _ItemLocation({
    required super.id,
    List<RouteNode> children = const [],
  }) : super(
         path: 'item',
         children: List.unmodifiable(children),
       );

  @override
  void register(
    LocationBuilder builder,
  ) {
    super.register(builder);
    builder.bindParam(idParameter);
    builder.bindParam(keep);
  }
}

class _DetailLocation extends _ParamPathLocation<_DetailLocation> {
  _DetailLocation({
    required super.id,
    required super.path,
  });

  @override
  void register(
    LocationBuilder builder,
  ) {
    super.register(builder);
    builder.stringQueryParam('detail');
  }
}

class _MigratingRootLocation extends Location<_MigratingRootLocation> {
  final List<RouteNode> children;

  _MigratingRootLocation({
    required NodeId<_MigratingRootLocation> id,
    this.children = const [],
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.children = children;
  }
}

class _SelfBuiltAccountLocation extends Location<_SelfBuiltAccountLocation> {
  _SelfBuiltAccountLocation({
    required NodeId<_SelfBuiltAccountLocation> id,
  }) : super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('accounts');
    final accountId = builder.stringPathParam();
    final tab = builder.stringQueryParam('tab');
    builder.content = Content.builder((context, data) {
      return Text(
        '${data.param(accountId)}:${data.param(tab)}',
      );
    });
  }
}

class _BuilderLocation extends Location<_BuilderLocation> {
  final void Function(LocationBuilder builder, _BuilderLocation location)
  _build;

  _BuilderLocation({
    required super.id,
    super.parentRouterKey,
    required void Function(LocationBuilder builder, _BuilderLocation location)
    build,
  }) : _build = build;

  @override
  void build(LocationBuilder builder) {
    _build(builder, this);
  }
}

class _BuilderOverlay extends AbstractOverlay<_BuilderOverlay> {
  final BuildOverlay<_BuilderOverlay> _build;

  _BuilderOverlay({
    required super.id,
    super.parentRouterKey,
    required BuildOverlay<_BuilderOverlay> build,
  }) : _build = build;

  @override
  void build(OverlayBuilder builder) {
    _build(builder, this);
  }
}

class _BuilderScope extends Scope<_BuilderScope> {
  final void Function(ScopeBuilder builder, _BuilderScope scope) _build;

  _BuilderScope({
    required void Function(ScopeBuilder builder, _BuilderScope scope) build,
  }) : _build = build;

  @override
  void build(ScopeBuilder builder) {
    _build(builder, this);
  }
}

class _BuilderShellLocation extends ShellLocation<_BuilderShellLocation> {
  final void Function(
    ShellLocationBuilder builder,
    _BuilderShellLocation location,
    WorkingRouterKey routerKey,
  )
  _build;

  _BuilderShellLocation({
    super.navigatorEnabled,
    required void Function(
      ShellLocationBuilder builder,
      _BuilderShellLocation location,
      WorkingRouterKey routerKey,
    )
    build,
  }) : _build = build;

  @override
  void build(ShellLocationBuilder builder) {
    _build(builder, this, routerKey);
  }
}

class _BuilderMultiShellLocation
    extends MultiShellLocation<_BuilderMultiShellLocation> {
  final void Function(
    MultiShellLocationBuilder builder,
    _BuilderMultiShellLocation location,
    MultiShellSlot contentSlot,
  )
  _build;

  _BuilderMultiShellLocation({
    super.navigatorEnabled,
    required void Function(
      MultiShellLocationBuilder builder,
      _BuilderMultiShellLocation location,
      MultiShellSlot contentSlot,
    )
    build,
  }) : _build = build;

  @override
  void build(MultiShellLocationBuilder builder) {
    _build(builder, this, contentSlot);
  }
}

class _BuilderMultiShell extends MultiShell {
  _BuilderMultiShell({
    super.navigatorEnabled,
    required super.build,
  });
}

class _ChannelLocation extends Location<_ChannelLocation> {
  late final PathParam<String> channelId;

  _ChannelLocation({
    super.parentRouterKey,
  });

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('channel');
    channelId = builder.stringPathParam();
    builder.content = Content.builder((context, data) {
      return Text('channel:${data.param(channelId)}');
    });
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
