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

    testWidgets('routeBackFrom ignores deeper active descendants', (tester) async {
      final router = _buildRouter();

      router.routeToUri(Uri.parse('/a/b'));
      await tester.pump();

      final ancestorLocation = router.nullableData!.locations
          .whereType<_PathLocation>()
          .singleWhere((location) => location.id == _Id.a);

      router.routeBackFrom(ancestorLocation);
      await tester.pump();

      expect(router.nullableData!.uri.path, '/');
      expect(
        router.nullableData!.locations.map((location) => location.id).toList(),
        [_Id.root],
      );
    });

    testWidgets(
      'non-rendering location leaves its parent page visible while staying active',
      (tester) async {
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.content = Content.widget(const Text('root'));
                builder.children = [
                  _BuilderLocation<_Id>(
                    id: _Id.a,
                    build: (builder, location) {
                      builder.pathLiteral('settings');
                      builder.content = Content.widget(const Text('settings'));
                      builder.children = [
                        _BuilderLocation<_Id>(
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
        expect(router.nullableData!.activeLocation?.id, _Id.b);
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
        buildLocations: (_) => [
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

    testWidgets('dsl buildPageKey receives the current router data', (
      tester,
    ) async {
      var sawExpectedData = false;
      LocalKey? pageKey;

      final router = WorkingRouter<_Id>(
        buildLocations: (_) => [
          _BuilderLocation<_Id>(
            id: _Id.root,
            build: (builder, location) {
              builder.content = Content.widget(const Text('root'));
              builder.children = [
                _BuilderLocation<_Id>(
                  id: _Id.a,
                  build: (builder, location) {
                    builder.pathLiteral('a');
                    builder.pageKey = PageKey.custom((data) {
                      sawExpectedData =
                          data.uri.path == '/a' &&
                          data.activeLocation?.id == _Id.a;
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

      final router = WorkingRouter<_Id>(
        buildLocations: (_) => [
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
          buildLocations: (_) => [
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
          buildLocations: (_) => [
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

    testWidgets(
      'scopes share query params with children without building pages',
      (tester) async {
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  Scope<_Id>(
                    build: (builder, scope) {
                      final languageCode = builder.stringQueryParam(
                        'languageCode',
                        defaultValue: const Default('en'),
                      );
                      builder.children = [
                        _BuilderLocation<_Id>(
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
      final router = WorkingRouter<_Id>(
        buildLocations: (_) => [
          _BuilderLocation<_Id>(
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
                      _BuilderLocation<_Id>(
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
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderShellLocation<_Id>(
                    id: _Id.b,
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
      final router = WorkingRouter<_Id>(
        buildLocations: (_) => [
          _BuilderLocation<_Id>(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                Shell(
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('accounts');
                    builder.stringPathParam();
                    builder.children = [
                      _BuilderLocation<_Id>(
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
      expect(router.nullableData!.locations, isEmpty);
      expect(router.nullableData!.uri.path, '/accounts/42');
    });

    testWidgets('routeToId can write shell path parameters', (tester) async {
      final router = WorkingRouter<_Id>(
        buildLocations: (_) => [
          _BuilderLocation<_Id>(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                Shell(
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('accounts');
                    final accountId = builder.stringPathParam();
                    builder.children = [
                      _BuilderLocation<_Id>(
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
          if (location is Shell<_Id>) {
            path(location.pathParameters.single as PathParam<String>, '42');
          }
        },
      );
      await tester.pumpAndSettle();

      expect(router.nullableData!.uri.path, '/accounts/42/dashboard');
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shell acts like scope when children are routed to root', (
      tester,
    ) async {
      final router = WorkingRouter<_Id>(
        buildLocations: (rootRouterKey) => [
          _BuilderLocation<_Id>(
            id: _Id.root,
            build: (builder, location) {
              builder.children = [
                Shell(
                  build: (builder, shell, routerKey) {
                    builder.pathLiteral('accounts');
                    final accountId = builder.stringPathParam();
                    builder.children = [
                      _BuilderLocation<_Id>(
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
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
      expect(
        tester.widgetList<Navigator>(find.byType(Navigator)),
        hasLength(1),
      );
      expect(router.nullableData!.uri.path, '/accounts/42/dashboard');
    });

    testWidgets(
      'disabled shell routes implicit and explicit shell children to parent navigator',
      (tester) async {
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  Shell(
                    navigatorEnabled: false,
                    build: (builder, shell, routerKey) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.children = [
                        _BuilderLocation<_Id>(
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
                        _BuilderLocation<_Id>(
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
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderShellLocation<_Id>(
                    id: _Id.b,
                    navigatorEnabled: false,
                    build: (builder, location, routerKey) {
                      builder.pathLiteral('accounts');
                      final accountId = builder.stringPathParam();
                      builder.content = Content.builder((context, data) {
                        return Text('settings:${data.param(accountId)}');
                      });
                      builder.children = [
                        _BuilderLocation<_Id>(
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
      'multi shell location renders sibling slot and content navigators',
      (tester) async {
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation<_Id>(
                    id: _Id.a,
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
                        _BuilderLocation<_Id>(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation<_Id>(
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
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShell<_Id>(
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
                        _BuilderLocation<_Id>(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation<_Id>(
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
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShellLocation<_Id>(
                    id: _Id.a,
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
                        _BuilderLocation<_Id>(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation<_Id>(
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
        final router = WorkingRouter<_Id>(
          buildLocations: (_) => [
            _BuilderLocation<_Id>(
              id: _Id.root,
              build: (builder, location) {
                builder.children = [
                  _BuilderMultiShell<_Id>(
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
                        _BuilderLocation<_Id>(
                          id: _Id.b,
                          parentRouterKey: leftSlot.routerKey,
                          build: (builder, location) {
                            builder.pathLiteral('search');
                            builder.content = Content.widget(
                              const Text('search'),
                            );
                            builder.children = [
                              _BuilderLocation<_Id>(
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
    buildLocations: (_) => [
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
    buildLocations: (_) => [
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
    buildLocations: (_) => [
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

class _PathLocation extends AbstractLocation<_Id, _PathLocation> {
  final List<PathSegment> _segments;
  final List<LocationTreeElement<_Id>> _childNodes;

  _PathLocation({
    required _Id id,
    required String path,
    List<LocationTreeElement<_Id>> children = const [],
  }) : _segments = _pathSegments(path),
       _childNodes = children,
       super(id: id);

  @override
  void build(LocationBuilder<_Id> builder) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
    builder.children = _childNodes;
  }
}

class _ParamPathLocation
    extends AbstractLocation<_ParamId, _ParamPathLocation> {
  final List<PathSegment> _segments;
  final List<LocationTreeElement<_ParamId>> _childNodes;

  _ParamPathLocation({
    required _ParamId id,
    required String path,
    List<LocationTreeElement<_ParamId>> children = const [],
  }) : _segments = _pathSegments(path),
       _childNodes = children,
       super(id: id);

  @override
  void build(LocationBuilder<_ParamId> builder) {
    final children = register(builder);
    builder.children = children;
  }

  List<LocationTreeElement<_ParamId>> register(
    LocationBuilder<_ParamId> builder,
  ) {
    for (final segment in _segments) {
      builder.pathSegment(segment);
    }
    return _childNodes;
  }
}

class _ParamRootLocation extends _ParamPathLocation {
  _ParamRootLocation({
    required super.id,
    super.children = const [],
  }) : super(path: '');
}

class _ItemLocation extends _ParamPathLocation {
  final idParameter = const PathParam(StringRouteParamCodec());
  final keep = const QueryParam('keep', StringRouteParamCodec());

  _ItemLocation({
    required super.id,
    super.children = const [],
  }) : super(path: 'item');

  @override
  List<LocationTreeElement<_ParamId>> register(
    LocationBuilder<_ParamId> builder,
  ) {
    final children = super.register(builder);
    builder.pathSegment(idParameter);
    builder.query(keep);
    return children;
  }
}

class _DetailLocation extends _ParamPathLocation {
  _DetailLocation({
    required super.id,
    required super.path,
  });

  @override
  List<LocationTreeElement<_ParamId>> register(
    LocationBuilder<_ParamId> builder,
  ) {
    final children = super.register(builder);
    builder.query(const QueryParam('detail', StringRouteParamCodec()));
    return children;
  }
}

class _MigratingRootLocation
    extends AbstractLocation<_MigratingId, _MigratingRootLocation> {
  final List<LocationTreeElement<_MigratingId>> _childNodes;

  _MigratingRootLocation({
    required _MigratingId id,
    List<LocationTreeElement<_MigratingId>> children = const [],
  }) : _childNodes = children,
       super(id: id);

  @override
  void build(LocationBuilder<_MigratingId> builder) {
    builder.children = _childNodes;
  }
}

class _SelfBuiltAccountLocation
    extends AbstractLocation<_MigratingId, _SelfBuiltAccountLocation> {
  _SelfBuiltAccountLocation({
    required _MigratingId id,
  }) : super(id: id);

  @override
  void build(LocationBuilder<_MigratingId> builder) {
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

class _BuilderLocation<ID> extends Location<ID, _BuilderLocation<ID>> {
  _BuilderLocation({
    required super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class _BuilderShellLocation<ID>
    extends ShellLocation<ID, _BuilderShellLocation<ID>> {
  _BuilderShellLocation({
    required super.id,
    super.parentRouterKey,
    super.navigatorEnabled,
    required super.build,
  });
}

class _BuilderMultiShellLocation<ID>
    extends MultiShellLocation<ID, _BuilderMultiShellLocation<ID>> {
  _BuilderMultiShellLocation({
    required super.id,
    super.parentRouterKey,
    super.navigatorEnabled,
    required super.build,
  });
}

class _BuilderMultiShell<ID> extends MultiShell<ID> {
  _BuilderMultiShell({
    super.parentRouterKey,
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
