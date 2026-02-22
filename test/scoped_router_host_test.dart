import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_router/working_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScopedRouterHost', () {
    testWidgets('routes account envelope to scoped router', (tester) async {
      final globalRouter = _buildGlobalRouter();
      final createdScopedRouters = <String, WorkingRouter<dynamic>>{};
      final host = ScopedRouterHost<String>(
        globalRouter: globalRouter,
        resolveScope: _resolveScope,
        buildHostUri: _buildHostUri,
        buildScopedRouter: (scope, initialUri) {
          final router = _buildScopedRouter(initialUri: initialUri);
          createdScopedRouters[scope] = router;
          return router;
        },
        initialUri: Uri(path: '/accounts/a/inbox'),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: host));
      await tester.pump();

      expect(host.activeScope, 'a');
      expect(host.currentConfiguration.path, '/accounts/a/inbox');
      expect(createdScopedRouters['a'], isNotNull);
      expect(createdScopedRouters['a']!.nullableData!.uri.path, '/inbox');
    });

    testWidgets('routes global path to global router', (tester) async {
      final globalRouter = _buildGlobalRouter();
      final host = ScopedRouterHost<String>(
        globalRouter: globalRouter,
        resolveScope: _resolveScope,
        buildHostUri: _buildHostUri,
        buildScopedRouter: (scope, initialUri) {
          return _buildScopedRouter(initialUri: initialUri);
        },
        initialUri: Uri(path: '/accounts/a/inbox'),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: host));
      await tester.pump();

      host.routeToUri(Uri(path: '/login'));
      await tester.pump();

      expect(host.activeScope, isNull);
      expect(globalRouter.nullableData!.uri.path, '/login');
      expect(host.currentConfiguration.path, '/login');
    });

    testWidgets(
      'updates host URI when active scoped router changes internally',
      (tester) async {
        final globalRouter = _buildGlobalRouter();
        final host = ScopedRouterHost<String>(
          globalRouter: globalRouter,
          resolveScope: _resolveScope,
          buildHostUri: _buildHostUri,
          buildScopedRouter: (scope, initialUri) {
            return _buildScopedRouter(initialUri: initialUri);
          },
          initialUri: Uri(path: '/accounts/a/inbox'),
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: host));
        await tester.pump();

        final scopedRouter = host.scopeRouterOrNull('a')!;
        scopedRouter.routeToUri(Uri(path: '/settings'));
        await tester.pump();

        expect(host.currentConfiguration.path, '/accounts/a/settings');
      },
    );

    testWidgets('removeScope removes and deactivates scoped router', (
      tester,
    ) async {
      final globalRouter = _buildGlobalRouter();
      final host = ScopedRouterHost<String>(
        globalRouter: globalRouter,
        resolveScope: _resolveScope,
        buildHostUri: _buildHostUri,
        buildScopedRouter: (scope, initialUri) {
          return _buildScopedRouter(initialUri: initialUri);
        },
        initialUri: Uri(path: '/accounts/a/inbox'),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: host));
      await tester.pump();

      expect(host.activeScope, 'a');
      expect(host.scopeRouterOrNull('a'), isNotNull);

      host.removeScope('a', disposeRouter: false);
      await tester.pump();

      expect(host.activeScope, isNull);
      expect(host.scopeRouterOrNull('a'), isNull);
    });
  });
}

ScopeResolution<String> _resolveScope(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length >= 2 && segments.first == 'accounts') {
    final accountId = segments[1];
    final subSegments = segments.skip(2).toList();
    final subPath = subSegments.isEmpty ? '/' : '/${subSegments.join('/')}';
    return ScopeResolution.scoped(
      scope: accountId,
      scopedUri: Uri(
        path: subPath,
        queryParameters: uri.queryParameters.isEmpty
            ? null
            : uri.queryParameters,
      ),
    );
  }
  return ScopeResolution.global(scopedUri: uri);
}

Uri _buildHostUri(ScopeResolution<String> resolution) {
  if (resolution.isGlobal) {
    return resolution.scopedUri;
  }
  final scope = resolution.scope!;
  final scopedUri = resolution.scopedUri;
  final suffix = scopedUri.path == '/' ? '' : scopedUri.path;
  return Uri(
    path: '/accounts/$scope$suffix',
    queryParameters: scopedUri.queryParameters.isEmpty
        ? null
        : scopedUri.queryParameters,
  );
}

WorkingRouter<String> _buildGlobalRouter() {
  return WorkingRouter<String>(
    buildLocationTree: () {
      return _PathLocation(
        path: '',
        id: 'root',
        children: [
          _PathLocation(path: 'login', id: 'login'),
          _PathLocation(path: 'forgot-password', id: 'forgot'),
          _PathLocation(path: 'accounts/add', id: 'add-account'),
        ],
      );
    },
    buildRootPages: (_, location, _) {
      if (location.path.isEmpty) {
        return [];
      }
      return [
        ChildLocationPageSkeleton<String>(
          child: Text(location.path),
        ),
      ];
    },
    noContentWidget: const SizedBox.shrink(),
  );
}

WorkingRouter<String> _buildScopedRouter({Uri? initialUri}) {
  return WorkingRouter<String>(
    buildLocationTree: () {
      return _PathLocation(
        path: '',
        id: 'root',
        children: [
          _PathLocation(path: 'inbox', id: 'inbox'),
          _PathLocation(path: 'settings', id: 'settings'),
        ],
      );
    },
    buildRootPages: (_, location, _) {
      if (location.path.isEmpty) {
        return [];
      }
      return [
        ChildLocationPageSkeleton<String>(
          child: Text(location.path),
        ),
      ];
    },
    noContentWidget: const SizedBox.shrink(),
    initialUri: initialUri,
  );
}

class _PathLocation extends Location<String> {
  final String _path;

  _PathLocation({
    required String path,
    required super.id,
    super.children = const [],
  }) : _path = path,
       super();

  @override
  String get path => _path;
}
