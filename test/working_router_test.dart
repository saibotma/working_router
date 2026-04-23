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
          writePathParameters: (location, path) {
            if (location is _ItemLocation) {
              path(location.boundIdParameter, '42');
            }
          },
        );
        await tester.pump();

        expect(router.nullableData!.uri.path, '/item/42');
        expect(router.nullableData!.queryParameters.unlock, {'keep': '1'});
      },
    );

    testWidgets('routeToId throws for structural route node ids', (tester) async {
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
                          builder.content = Content.widget(const Text('detail'));
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

    testWidgets('keeps fallback uri and empty locations for unknown path', (
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
    });

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

    testWidgets('slideIn is a no-op for unknown path', (tester) async {
      final router = _buildRouter();

      router.routeToUri(Uri(path: '/does-not-exist'));
      await tester.pump();

      expect(() => router.slideIn(_PathId.a), returnsNormally);
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
                children: [
                  _PathLocation(id: _PathId.b, path: 'b', children: []),
                ],
              ),
            ],
          ),
        ],
        buildRootPages: (_, location, _) {
          return [
            ChildLocationPageSkeleton(
              buildPageKey: (keyLocation, data) {
                if (keyLocation.id == _PathId.a) {
                  sawExpectedData =
                      data.uri.path == '/a/b' &&
                      data.leaf?.id == _PathId.b &&
                      data.routeNodes.contains(keyLocation);
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
                          data.uri.path == '/a' &&
                          data.leaf?.id == _Id.a;
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
                  _PathLocation(id: _PathId.b, path: 'b', children: []),
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
          buildRootPages: (_, location, _) {
            return [
              ChildLocationPageSkeleton(
                child: Text('${location.id}'),
              ),
            ];
          },
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
      'supports self-built locations alongside legacy buildRootPages',
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
          buildRootPages: (_, location, _) {
            if (identical(location.id, _MigratingId.root)) {
              return [
                ChildLocationPageSkeleton(
                  child: const Text('legacy-root'),
                ),
              ];
            }
            return const [];
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
                      final languageCode = builder.stringQueryParam(
                        'languageCode',
                        defaultValue: const Default('en'),
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
          buildRootPages: (_, location, _) {
            return [
              ChildLocationPageSkeleton(child: Text('${location.id}')),
            ];
          },
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
                    final tab = builder.stringQueryParam(
                      'tab',
                      defaultValue: const Default('overview'),
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
        writePathParameters: (location, path) {
          if (location is Shell) {
            path(location.pathParameters.single as PathParam<String>, '42');
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
  Future<bool> Function()? beforeLeave,
  int redirectLimit = 5,
}) {
  final bPage = ChildLocationPageSkeleton(
    child: LocationObserver(
      beforeLeave: beforeLeave,
      child: const Text('b'),
    ),
  );

  return WorkingRouter(
    buildRouteNodes: (_) => [
      _PathLocation(
        id: _PathId.root,
        path: '',
        children: [
          _PathLocation(
            id: _PathId.a,
            path: 'a',
            children: [
              _PathLocation(id: _PathId.b, path: 'b', children: []),
            ],
          ),
          _PathLocation(id: _PathId.c, path: 'c', children: []),
        ],
      ),
    ],
    buildRootPages: (_, location, _) {
      if (identical(location.id, _PathId.root)) {
        return [ChildLocationPageSkeleton(child: const Text('root'))];
      }
      if (identical(location.id, _PathId.a)) {
        return [ChildLocationPageSkeleton(child: const Text('a'))];
      }
      if (identical(location.id, _PathId.b)) {
        return [bPage];
      }
      if (identical(location.id, _PathId.c)) {
        return [ChildLocationPageSkeleton(child: const Text('c'))];
      }
      return [];
    },
    noContentWidget: const SizedBox.shrink(),
    decideTransition: decideTransition,
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
        children: [
          _PathLocation(
            id: _PathId.a,
            path: 'a',
            children: [
              _PathLocation(id: _PathId.b, path: 'b', children: []),
            ],
          ),
          _PathLocation(id: _PathId.c, path: 'c', children: []),
        ],
      ),
    ],
    buildRootPages: (_, location, _) {
      if (identical(location.id, _PathId.root)) {
        return [ChildLocationPageSkeleton(child: const Text('root'))];
      }
      if (identical(location.id, _PathId.a)) {
        return [
          ChildLocationPageSkeleton(
            child: LocationObserver(
              beforeLeave: beforeLeaveA,
              child: const Text('a'),
            ),
          ),
        ];
      }
      if (identical(location.id, _PathId.b)) {
        return [
          ChildLocationPageSkeleton(
            child: LocationObserver(
              beforeLeave: beforeLeaveB,
              child: const Text('b'),
            ),
          ),
        ];
      }
      if (identical(location.id, _PathId.c)) {
        return [ChildLocationPageSkeleton(child: const Text('c'))];
      }
      return [];
    },
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

class _PathLocation extends AbstractLocation<_PathLocation> {
  final List<PathSegment> _segments;
  final List<RouteNode> _childNodes;

  _PathLocation({
    required NodeId<_PathLocation> id,
    required String path,
    List<RouteNode> children = const [],
  }) : _segments = _pathSegments(path),
       _childNodes = children,
       super(id: id);

  @override
  void build(LocationBuilder builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
    builder.children = _childNodes;
  }
}

abstract class _ParamPathLocation<Self extends _ParamPathLocation<Self>>
    extends AbstractLocation<Self> {
  final List<PathSegment> _segments;
  final List<RouteNode> _childNodes;

  _ParamPathLocation({
    required NodeId<Self> id,
    required String path,
    List<RouteNode> children = const [],
  }) : _segments = _pathSegments(path),
       _childNodes = children,
       super(id: id);

  @override
  void build(LocationBuilder builder) {
    final children = register(builder);
    builder.children = children;
  }

  List<RouteNode> register(
    LocationBuilder builder,
  ) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
    return _childNodes;
  }
}

class _ParamRootLocation extends _ParamPathLocation<_ParamRootLocation> {
  _ParamRootLocation({
    required super.id,
    super.children = const [],
  }) : super(path: '');
}

class _ItemLocation extends _ParamPathLocation<_ItemLocation> {
  final idParameter = const UnboundPathParam(StringRouteParamCodec());
  final keep = const UnboundQueryParam('keep', StringRouteParamCodec());
  late final PathParam<String> boundIdParameter =
      definition.pathParameters.single as PathParam<String>;
  late final QueryParam<String> boundKeep =
      definition.queryParameters.single as QueryParam<String>;

  _ItemLocation({
    required super.id,
    super.children = const [],
  }) : super(path: 'item');

  @override
  List<RouteNode> register(
    LocationBuilder builder,
  ) {
    final children = super.register(builder);
    builder.bindParam(idParameter);
    builder.bindParam(keep);
    return children;
  }
}

class _DetailLocation extends _ParamPathLocation<_DetailLocation> {
  _DetailLocation({
    required super.id,
    required super.path,
  });

  @override
  List<RouteNode> register(
    LocationBuilder builder,
  ) {
    final children = super.register(builder);
    builder.stringQueryParam('detail');
    return children;
  }
}

class _MigratingRootLocation
    extends AbstractLocation<_MigratingRootLocation> {
  final List<RouteNode> _childNodes;

  _MigratingRootLocation({
    required NodeId<_MigratingRootLocation> id,
    List<RouteNode> children = const [],
  }) : _childNodes = children,
       super(id: id);

  @override
  void build(LocationBuilder builder) {
    builder.children = _childNodes;
  }
}

class _SelfBuiltAccountLocation
    extends AbstractLocation<_SelfBuiltAccountLocation> {
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

class _BuilderLocation
    extends Location<_BuilderLocation> {
  _BuilderLocation({
    required super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class _BuilderScope extends Scope<_BuilderScope> {
  _BuilderScope({
    required super.build,
  });
}

class _BuilderShellLocation
    extends ShellLocation<_BuilderShellLocation> {
  _BuilderShellLocation({
    super.navigatorEnabled,
    required super.build,
  });
}

class _BuilderMultiShellLocation
    extends MultiShellLocation<_BuilderMultiShellLocation> {
  _BuilderMultiShellLocation({
    super.navigatorEnabled,
    required super.build,
  });
}

class _BuilderMultiShell extends MultiShell {
  _BuilderMultiShell({
    super.navigatorEnabled,
    required super.build,
  });
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
