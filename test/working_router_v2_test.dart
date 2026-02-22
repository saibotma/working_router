import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkingRouterV2', () {
    testWidgets('routes host URI to scoped router', (tester) async {
      final router = _buildRouter(initialUri: Uri(path: '/accounts/a/inbox'));

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(router.activeScope, 'account:a');
      expect(router.currentConfiguration.path, '/accounts/a/inbox');
      expect(router.scopeRouterOrNull('account:a'), isNotNull);
      expect(
        router.scopeRouterOrNull('account:a')!.nullableData!.uri.path,
        '/inbox',
      );
    });

    testWidgets('static scope route wins over dynamic scope route', (
      tester,
    ) async {
      final router = _buildRouter();

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      router.routeToUri(Uri(path: '/accounts/add'));
      await tester.pump();

      expect(router.activeScope, 'global');
      expect(router.currentConfiguration.path, '/accounts/add');
      expect(
        router.scopeRouterOrNull('global')!.nullableData!.uri.path,
        '/accounts/add',
      );
    });

    testWidgets(
      'preserves scoped stacks and restores last URI on scope switch',
      (
        tester,
      ) async {
        final router = _buildRouter(initialUri: Uri(path: '/accounts/a/inbox'));

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        final accountA = router.scopeRouterOrNull('account:a')!;
        accountA.routeToUri(Uri(path: '/settings'));
        await tester.pump();
        expect(router.currentConfiguration.path, '/accounts/a/settings');

        router.routeToUri(Uri(path: '/accounts/b/inbox'));
        await tester.pump();
        expect(router.currentConfiguration.path, '/accounts/b/inbox');

        router.activateScope(
          'account:a',
          initialScopedUri: Uri(path: '/inbox'),
        );
        await tester.pump();
        expect(router.currentConfiguration.path, '/accounts/a/settings');
        expect(
          router.scopeRouterOrNull('account:a')!.nullableData!.uri.path,
          '/settings',
        );
      },
    );

    testWidgets(
      'updates host URI when active scoped router changes internally',
      (
        tester,
      ) async {
        final router = _buildRouter(initialUri: Uri(path: '/accounts/a/inbox'));

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        router
            .scopeRouterOrNull('account:a')!
            .routeToUri(Uri(path: '/settings'));
        await tester.pump();

        expect(router.currentConfiguration.path, '/accounts/a/settings');
      },
    );
  });
}

WorkingRouterV2<String, String> _buildRouter({Uri? initialUri}) {
  return WorkingRouterV2<String, String>(
    initialScope: 'global',
    initialUri: initialUri,
    root: ScopeRootLocationV2<String, String>(
      children: <LocationV2<String, String>>[
        StaticScopeLocationV2<String, String, String>(
          path: '',
          scope: 'global',
          buildScopeRouter: (_, subtree, initialScopedUri) {
            return _buildScopeRouter(subtree, initialScopedUri);
          },
          children: const <LocationV2<String, String>>[
            RouteLocationV2<String, String>(path: 'login', id: 'login'),
            RouteLocationV2<String, String>(
              path: 'forgot-password',
              id: 'forgot-password',
            ),
            RouteLocationV2<String, String>(
              path: 'accounts/add',
              id: 'add-account',
            ),
          ],
        ),
        ScopeLocationV2<String, String, String>(
          path: 'accounts/:accountId',
          resolveScope: (params) => 'account:${params['accountId']!}',
          serializeScopeParams: (scope) {
            final id = scope.split(':').last;
            return <String, String>{'accountId': id};
          },
          buildScopeRouter: (_, subtree, initialScopedUri) {
            return _buildScopeRouter(subtree, initialScopedUri);
          },
          children: const <LocationV2<String, String>>[
            RouteLocationV2<String, String>(path: 'inbox', id: 'inbox'),
            RouteLocationV2<String, String>(path: 'settings', id: 'settings'),
          ],
        ),
      ],
    ),
  );
}

WorkingRouter<String> _buildScopeRouter(
  ScopeRouteSubtree<dynamic, String> subtree,
  Uri? initialUri,
) {
  return WorkingRouter<String>.fromLocationSubtreeV2(
    subtree: subtree,
    initialUri: initialUri,
    noContentWidget: const SizedBox.shrink(),
    buildRootPages: (_, location, _) {
      if (location.path.isEmpty) {
        return const <LocationPageSkeleton<String>>[];
      }
      return <LocationPageSkeleton<String>>[
        ChildLocationPageSkeleton<String>(
          child: Text(location.path),
        ),
      ];
    },
  );
}
