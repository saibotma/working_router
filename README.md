# working_router

`working_router` is a composable Flutter router focused on explicit location trees, nested routing, and predictable route transitions.

## API Levels

- V1: `WorkingRouter` + optional `ScopedRouterHost` (legacy/stable API)
- V2: `WorkingRouterV2` + `LocationV2` tree (scoped-first single-tree API)

Both are available side-by-side. Existing V1 apps keep working.

## Try The V2 Accounts Example

Run the new scoped accounts demo:

```bash
cd example
flutter run -t lib/scoped_accounts/main.dart
```

The demo includes:
- global routes: `/login`, `/forgot-password`, `/accounts/add`
- scoped routes: `/accounts/:accountId/inbox`, `/accounts/:accountId/thread/:threadId`, `/accounts/:accountId/settings`
- per-account route preservation while switching scopes

## Scoped Routers (Built-In)

Use `ScopedRouterHost<Scope>` when your app has:
- global routes (`/login`, `/forgot-password`, `/scopes/add`)
- many independent scoped route stacks (scopes/workspaces/tenants)
- one browser URL bar

`ScopedRouterHost` provides the Router 2 plumbing in-package:
- `RouterConfig<Uri>` (`routeInformationParser`, provider, delegate)
- URL dispatch to global vs scoped child routers
- lazy scoped-router creation and lifecycle
- host-level `currentConfiguration` updates for browser URL

## Path Ownership (No Duplication)

The split is intentional:
- `ScopedRouterHost` owns only the envelope path: `/scopes/:scopeId/*subroute`
- Each scoped `WorkingRouter` owns only its internal subroutes: `/inbox`, `/thread/:id`, `/settings`, ...

So you do not repeat feature subpaths in the host. The host extracts `scopeId + subroute`, then forwards only `subroute` to the scoped router.

## URL Strategy

Recommended URL shape:
- `/login`
- `/forgot-password`
- `/scopes/add`
- `/scopes/:scopeId/*subroute`

Example:
- `/scopes/42/inbox/thread/9?tab=files`

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

final globalRouter = WorkingRouter<GlobalLocationId>(
  buildLocationTree: buildGlobalTree,
  buildRootPages: buildGlobalPages,
  noContentWidget: const SizedBox.shrink(),
);

final host = ScopedRouterHost<String>(
  globalRouter: globalRouter,
  // Parse host URL -> (scope?, scopedUri)
  resolveScope: (uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'scopes') {
      final scopeId = segments[1];
      final rest = segments.skip(2).toList();
      final subPath = rest.isEmpty ? '/' : '/${rest.join('/')}';
      return ScopeResolution.scoped(
        scope: scopeId,
        scopedUri: Uri(
          path: subPath,
          queryParameters:
              uri.queryParameters.isEmpty ? null : uri.queryParameters,
        ),
      );
    }
    return ScopeResolution.global(scopedUri: uri);
  },
  // Build browser URL from active scope + scopedUri
  buildHostUri: (resolution) {
    if (resolution.isGlobal) {
      return resolution.scopedUri;
    }
    final scopeId = resolution.scope!;
    final sub = resolution.scopedUri;
    final suffix = sub.path == '/' ? '' : sub.path;
    return Uri(
      path: '/scopes/$scopeId$suffix',
      queryParameters: sub.queryParameters.isEmpty ? null : sub.queryParameters,
    );
  },
  // Lazily create one WorkingRouter per scope
  buildScopedRouter: (scopeId, initialUri) {
    return WorkingRouter<ScopeLocationId>(
      buildLocationTree: buildScopeTree,
      buildRootPages: buildScopePages,
      noContentWidget: const SizedBox.shrink(),
      initialUri: initialUri,
    );
  },
  // Optional seed (restoration/tests). Top-level web startup usually comes
  // from browser route information.
  // initialUri: Uri(path: '/login'),
);

void main() {
  runApp(MaterialApp.router(routerConfig: host));
}
```

## Routing From Widgets

Use the host for cross-scope/global routing:

```dart
host.routeToGlobalUri(Uri(path: '/login'));
host.routeToScopedUri('42', Uri(path: '/settings'));
```

Inside a scoped subtree, local routing can still call the scoped router directly:

```dart
WorkingRouter.of<ScopeLocationId>(context).routeToId(ScopeLocationId.thread);
```

## Browser URL Ownership

Only the top-level `ScopedRouterHost` should be used as `MaterialApp.router(routerConfig: ...)`.

Child `WorkingRouter`s should be mounted as nested `Router(routerDelegate: ...)` and should not be used as top-level `routerConfig`.

## Rendering/Transitions

Default host behavior renders the active router.

For custom shell UI (PageView/IndexedStack/animated transitions), pass `buildShell` to `ScopedRouterHost`. It receives:
- the host instance
- the default active-router widget

You can also render multiple scoped routers at once with:
- `buildScopeRouterWidget(context, scope)`
- `buildGlobalRouterWidget(context)`

## Per-Scope State Persistence

Inactive scope paths are stored in scoped routers (`router.data.uri`).

If needed, persist them yourself:
- `Map<Scope, Uri> lastUriByScope`
- hydrate each scoped router via `initialUri`

## Useful Existing APIs

`WorkingRouter` also provides:
- `initialUri`: explicit seed for restored/non-top-level/test routers
- `routeTransitions`: typed stream of committed transitions
- `dispose()`: cleanup for removed scopes

## Existing Example

See `example/lib/state_preserving_tabs/main.dart` for the same core idea of preserved independent nested navigators.
