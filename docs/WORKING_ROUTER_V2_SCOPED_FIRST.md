# WorkingRouterV2 Scoped-First Draft

Status: Draft v0.2  
Date: 2026-02-15

## Goal

Build a scoped-first router with one mental model and one location API:

1. one tree model for app routing
2. scope boundaries declared in that same tree
3. global is just a scope key
4. one top-level RouterConfig owner for URL
5. independent per-scope navigation stacks preserved

No separate host location API. No app-facing envelope callbacks.

## Single API Model

V2 uses one `LocationV2` hierarchy:

```dart
sealed class LocationV2<ScopeKey, RouteId> {
  String get path; // segment pattern, same semantics as current path matching
  List<LocationV2<ScopeKey, RouteId>> get children;
}
```

Two core node kinds:

1. `RouteLocationV2`
   - regular route nodes (path + metadata)
   - belongs to the current active scope
2. `ScopeLocationV2`
   - scope boundary node
   - resolves scope key from path params
   - forwards remaining path to that scope's route subtree

```dart
class RouteLocationV2<ScopeKey, RouteId> extends LocationV2<ScopeKey, RouteId> {
  final RouteId? id;
}

class ScopeLocationV2<ScopeKey, Scoped extends ScopeKey, RouteId>
    extends LocationV2<ScopeKey, RouteId> {
  final Scoped Function(Map<String, String> params) resolveScope;
  final Map<String, String> Function(Scoped scope) serializeScopeParams;
  final WorkingRouter<RouteId> Function(
    Scoped scope,
    ScopeRouteSubtree<ScopeKey, RouteId> subtree,
    Uri? initialScopedUri,
  )
  buildScopeRouter;
  final ScopeBackBehavior backBehavior;
}

class StaticScopeLocationV2<ScopeKey, Scoped extends ScopeKey, RouteId>
    extends LocationV2<ScopeKey, RouteId> {
  final Scoped scope;
  final WorkingRouter<RouteId> Function(
    Scoped scope,
    ScopeRouteSubtree<ScopeKey, RouteId> subtree,
    Uri? initialScopedUri,
  )
  buildScopeRouter;
}
```

Each scope owns one `WorkingRouter` instance, and that scope router defines its own `buildRootPages` exactly like v1.
`ScopeLocationV2` is subtype-typed (`Scoped extends ScopeKey`), so callbacks like
`serializeScopeParams` receive the concrete subtype (for example `AccountScope`)
without `switch`/casts.

`ScopeRouteSubtree` represents the matched V2 subtree below the scope boundary.
This keeps one source of truth for paths and avoids defining a second route tree.

## Proposed Router API

```dart
class WorkingRouterV2<ScopeKey, RouteId> extends ChangeNotifier
    implements RouterConfig<Uri> {
  WorkingRouterV2({
    required ScopeKey initialScope,
    required LocationV2<ScopeKey, RouteId> root,
    ScopeShellBuilder<ScopeKey, RouteId>? buildShell,
    Uri? initialUri,
    InitialRouteSeed<RouteId>? initialRoute,
    GlobalKey<NavigatorState>? navigatorKey,
  });

  ScopeKey get activeScope;
  Iterable<ScopeKey> get scopes;

  WorkingRouter<RouteId> ensureScope(
    ScopeKey scope, {
    Uri? initialScopedUri,
  });
  WorkingRouter<RouteId>? scopeRouterOrNull(ScopeKey scope);
  void removeScope(ScopeKey scope, {bool disposeRouter = true});

  // Host URI routing (scope resolution happens via scope nodes in root tree).
  void routeToUri(Uri uri);

  // Convenience in current active scope.
  void routeToId(RouteId id, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  });
  void routeBack();

  Stream<ScopeTransition<ScopeKey>> get scopeTransitions;
  Stream<ScopedRouteTransition<ScopeKey, RouteId>> get routeTransitions;
}
```

```dart
sealed class InitialRouteSeed<RouteId> {
  const InitialRouteSeed();
  const factory InitialRouteSeed.id(
    RouteId id, {
    Map<String, String> pathParameters,
    Map<String, String> queryParameters,
  }) = InitialRouteById<RouteId>;
}
```

Initialization rule:

1. Top-level web startup usually comes from Flutter Router route-information flow.
2. `initialUri` is still useful as an explicit seed for non-top-level routers, lazy scope-router creation, restoration, and tests.
3. `initialRoute` is optional typed startup seed for non-URL boot flows.
4. If both are provided, `initialUri` wins.

## Clarifications

### Why `initialUri` instead of only `initialLocation`?

Browser/deep-link entry is URI-based in Flutter Router APIs.
At top level, that URI normally arrives via route-information parsing.  
The explicit `initialUri` parameter remains valuable for routers that are created outside that flow
(for example lazily created scope routers, restored inactive scopes, and tests).
For typed startup (for example app-controlled bootstrap without external URL), v2 also includes
`initialRoute` (`InitialRouteSeed<RouteId>`), which keeps startup type-safe.

### Route Node Type

`RouteLocationV2` is the public route-node type in the v2 single-tree model.

### Are there duplicate location trees?

In this v2 draft: no. The app defines one `LocationV2` tree.  
When a scope node matches, the runtime passes the matched subtree (`ScopeRouteSubtree`) into
`buildScopeRouter`, so scoped routers reuse the same declared nodes instead of redefining routes.

## Matching + Serialization Semantics

Given host URI:

1. match `root` from left to right
2. when a `ScopeLocationV2` matches:
   - resolve `ScopeKey` from path params
   - remaining path becomes scoped URI
   - create/ensure scope router via that node's `buildScopeRouter`
   - route scoped URI in that scope router
3. if no scope node matched:
   - URI belongs to whichever static/global branch resolves a scope (for example `GlobalScope`)

Host URI serialization:

1. start from active scope router URI (`scopedUri`)
2. locate matching scope boundary path in root tree for active scope
3. serialize scope params with `serializeScopeParams`
4. prefix scopedUri path with scope boundary path

Precedence rule:

1. static route node beats param route node at same depth
2. prevents ambiguity like `/scopes/add` vs `/scopes/:scopeId/*`

## Fully Fledged Draft Example (Single Tree, No Duplication)

```dart
import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

sealed class AppScope {
  const AppScope();
}

class GlobalScope extends AppScope {
  const GlobalScope();
}

class AccountScope extends AppScope {
  final String id;
  const AccountScope(this.id);
}

enum GlobalRouteId { login, forgotPassword, addScope }
enum AccountRouteId { inbox, thread, settings }

final root = ScopeRootLocationV2<AppScope, Object>(
  children: [
    // Global routes branch (explicitly tied to GlobalScope via helper scope node).
    StaticScopeLocationV2<AppScope, GlobalScope, Object>(
      path: '',
      scope: const GlobalScope(),
      buildScopeRouter: (scope, subtree, initialUri) {
        return WorkingRouter.fromLocationSubtreeV2<Object>(
          subtree: subtree,
          initialUri: initialUri,
          buildRootPages: buildGlobalPages,
          noContentWidget: const SizedBox.shrink(),
        );
      },
      children: [
        RouteLocationV2<AppScope, Object>(
          path: 'login',
          id: GlobalRouteId.login,
        ),
        RouteLocationV2<AppScope, Object>(
          path: 'forgot-password',
          id: GlobalRouteId.forgotPassword,
        ),
        RouteLocationV2<AppScope, Object>(
          path: 'scopes/add',
          id: GlobalRouteId.addScope,
        ),
      ],
    ),

    // Dynamic scope boundary.
    ScopeLocationV2<AppScope, AccountScope, Object>(
      path: 'scopes/:scopeId',
      resolveScope: (params) => AccountScope(params['scopeId']!),
      serializeScopeParams: (scope) => {'scopeId': scope.id},
      buildScopeRouter: (scope, subtree, initialUri) {
        return WorkingRouter.fromLocationSubtreeV2<Object>(
          subtree: subtree,
          initialUri: initialUri,
          buildRootPages: (router, location, data) {
            return buildAccountPages(scope, location, data);
          },
          noContentWidget: const SizedBox.shrink(),
        );
      },
      children: [
        // Scoped routes are defined in same API, but built/rendered by per-scope router.
        RouteLocationV2<AppScope, Object>(
          path: 'inbox',
          id: AccountRouteId.inbox,
        ),
        RouteLocationV2<AppScope, Object>(
          path: 'thread/:threadId',
          id: AccountRouteId.thread,
        ),
        RouteLocationV2<AppScope, Object>(
          path: 'settings',
          id: AccountRouteId.settings,
        ),
      ],
    ),
  ],
);

final routerV2 = WorkingRouterV2<AppScope, Object>(
  initialScope: const GlobalScope(),
  root: root,
  initialUri: Uri(path: '/login'),
  // Optional typed startup when no external URL is driving bootstrap:
  // initialRoute: InitialRouteSeed.id(GlobalRouteId.login),
  buildShell: (context, host, activeRouter) {
    // Optional custom shell: PageView for lateral scopes, Navigator for global overlays.
    return activeRouter;
  },
);

void main() {
  runApp(MaterialApp.router(routerConfig: routerV2));
}
```

## Rendering and Transitions

`buildShell` allows mixed transitions:

1. scope-to-scope: `PageView`/`IndexedStack` style
2. scope-to-global: root `Navigator` page transition
3. nested transitions inside each scope router: normal page stack transitions

## Back Behavior

Default:

1. active scope router handles `routeBack()`
2. when scope stack cannot pop, scope node `backBehavior` decides:
   - stay in scope
   - move to previous scope
   - custom callback

## Internal Runtime State (Draft)

```dart
class V2State<ScopeKey, RouteId> {
  final ScopeKey activeScope;
  final Map<ScopeKey, WorkingRouter<RouteId>> scopeRouters;
  final Map<ScopeKey, Uri> lastScopedUris;
}
```

## Scope Router Lifecycle

`buildScopeRouter` is called only when the scope router is not already in memory.

Pseudo-flow:

```dart
WorkingRouter<RouteId> ensureScope(
  ScopeKey scope,
  Uri? initialScopedUri,
) {
  final existing = scopeRouters[scope];
  if (existing != null) return existing;

  final created = createFromMatchingScopeNodeAndSubtree(scope, initialScopedUri);
  scopeRouters[scope] = created;
  return created;
}
```

After creation, subsequent scope activations reuse the same router instance until `removeScope(scope)` is called.

## Why This Solves The Two-World Problem

1. one tree API (`LocationV2`) for global + scoped routes
2. scope boundaries declared in that tree
3. no app-facing host parser/serializer object
4. global is just `ScopeKey`

## Open Decisions

1. `RouteId` typing strategy:
   - one shared `RouteId` union
   - or per-scope route-id types with erased host-level type
2. Should v2 include `routeToIdInScope(scope, id)` host helper in initial release?
3. Should `StaticScopeLocationV2` be explicit API or synthesized sugar around `ScopeLocationV2`?
4. How strict should ambiguity checks be at tree build time?

## Success Criteria

1. Apps define scoped routing with one location tree model.
2. No manual resolve/build URL glue in app code.
3. Per-scope nested stacks are preserved and independently routable.
4. Scope and route transitions are observable and deterministic.
