# working_router

`working_router` is a composable Flutter router focused on explicit location trees, nested routing, and predictable route transitions.

## Coordinator Architecture For Multi-Account Apps

For apps with:
- global screens (`/login`, `/forgot-password`, `/accounts/add`)
- multiple signed-in accounts
- independent per-account navigation stacks
- swipe gestures where two accounts can be visible at once

use a **coordinator** approach.

### Router Responsibilities

1. `AppNavigationCoordinator` (core coordinator/state)
   - Owns routing decisions and commands.
   - Tracks `mode`, `activeAccountId`, and account-router registry.

2. `AppShellRouter` (top-level `RouterConfig<Uri>` adapter)
   - Owns URL parsing/serialization at app root.
   - Bridges Flutter Router API to the coordinator.

3. `WorkingRouter` for global flow
   - Owns only global screens.

4. `WorkingRouter` per account
   - One router instance per account id.
   - Owns that account's full nested route tree.
   - Preserves stack state while another account is active.

This is preferred over one giant router containing all accounts, because independent stacks and lifecycle are naturally isolated per router instance.

### Terminology Map

- `AppNavigationCoordinator`: app-level routing state and commands.
- `AppShellRouter`: root-level `RouterConfig<Uri>` adapter that bridges Flutter Router to `AppNavigationCoordinator`.

Only these two names are used in this document.

## URL Strategy (Single Browser Bar)

A browser has one path. Make that path represent:
- current global screen, or
- current subroute of the active account

Recommended patterns:
- `/login`
- `/forgot-password`
- `/accounts/add`
- `/accounts/:accountId/*subroute`

Example:
- `/accounts/42/inbox/thread/9?tab=files`

## Where Inactive Account Paths Live

Do not encode all account stacks into the URL.

Store per-account route state in app state:
- `Map<AccountId, WorkingRouter<AccountRouteId>> accountRouters`
- optional persisted cache: `Map<AccountId, Uri> lastUriByAccount`

Inactive account paths are recovered from each account router's `router.data.uri` (or from persisted `lastUriByAccount` after restart).

## Wiring Flow

1. External URL arrives.
2. `AppShellRouter` forwards parsed URL input to `AppNavigationCoordinator`.
3. If global path:
   - route global router.
4. If `/accounts/:accountId/*subroute`:
   - ensure account router exists
   - set active account id
   - route only that account router to `subroute`
5. Keep non-active routers untouched.
6. When active account router changes, write new URL for that account only.

## Path Ownership (No Duplication)

The split is intentional:

- `AppNavigationCoordinator` knows only the envelope path:
  - global paths like `/login`
  - account envelope `/accounts/:accountId/*subroute`
- Account `WorkingRouter` knows only account-internal subroutes:
  - `/inbox`, `/thread/:id`, `/settings`, ...

So the coordinator does not repeat feature subpaths. It extracts `accountId` + `subroute` and forwards only `subroute` to the account router.

## Coordinator Sketch

Use one coordinator class that handles both command-style navigation from widgets and URL dispatch from `AppShellRouter`:

```dart
enum AppMode { global, accounts }
enum GlobalLocationId { login, forgotPassword, addAccount }
enum AccountLocationId { inbox, thread, settings }

class AppNavigationCoordinator {
  AppMode mode = AppMode.global;
  String? activeAccountId;

  final WorkingRouter<GlobalLocationId> globalRouter;
  final Map<String, WorkingRouter<AccountLocationId>> accountRouters;

  void routeToGlobal(GlobalLocationId id) {
    mode = AppMode.global;
    globalRouter.routeToId(id);
  }

  void routeToAccount(String accountId, AccountLocationId id) {
    final router = ensureAccountRouter(accountId);
    activeAccountId = accountId;
    mode = AppMode.accounts;
    router.routeToId(id);
  }

  void routeToActiveAccount(AccountLocationId id) {
    routeToAccount(activeAccountId!, id);
  }

  WorkingRouter<AccountLocationId> ensureAccountRouter(
    String accountId, {
    Uri? initialSubroute,
  }) {
    return accountRouters.putIfAbsent(
      accountId,
      () => buildAccountRouter(initialSubroute),
    );
  }

  // Called by AppShellRouter.setNewRoutePath
  void handleExternalUrl(Uri uri) {
    if (_isGlobalPath(uri.path)) {
      mode = AppMode.global;
      globalRouter.routeToUri(uri);
      return;
    }

    final parsed = parseAccountEnvelope(uri); // accountId + account subroute
    if (parsed == null) {
      mode = AppMode.global;
      globalRouter.routeToUri(Uri(path: '/login'));
      return;
    }

    final accountRouter = ensureAccountRouter(
      parsed.accountId,
      initialSubroute: parsed.subroute,
    );
    activeAccountId = parsed.accountId;
    mode = AppMode.accounts;
    accountRouter.routeToUri(parsed.subroute);
  }
}
```

The sketch assumes injected helpers/builders such as `buildAccountRouter`, `_isGlobalPath`, and `parseAccountEnvelope`.

From widgets:
- use `AppNavigationCoordinator` for cross-domain/cross-account navigation
- inside an account subtree, direct `WorkingRouter.of<AccountLocationId>(context)` calls are still fine for local account-only navigation

## UI For Swipe Between Accounts

Render account content with `PageView` or `IndexedStack` and keep children alive:
- each page contains the corresponding account router
- partial swipe can show two accounts simultaneously
- each account renders its own last active route immediately

If you need one coordinator route per visible account page:
- use stable keys per account (`ValueKey(accountId)`)
- avoid destroying inactive account widgets unless intentionally removing account data

## Recommended `working_router` APIs For This Pattern

### `initialUri` (new)

Seed a router instance with a known starting route when creating it:

```dart
final router = WorkingRouter<AccountRouteId>(
  buildLocationTree: buildAccountLocationTree,
  buildRootPages: buildAccountPages,
  noContentWidget: const SizedBox.shrink(),
  initialUri: Uri(path: '/inbox'),
);
```

Use this when restoring per-account last route.

### `routeTransitions` stream (new)

Listen to committed, typed route transitions:

```dart
final sub = router.routeTransitions.listen((transition) {
  // transition.from
  // transition.to
  // transition.reason
});
```

Use this to mirror active account route changes back to your URL writer.

### `dispose()` cleanup

Dispose routers when removing accounts permanently:

```dart
accountRouters.remove(accountId)?.dispose();
```

## URL Ownership And Browser Updates

Only `AppShellRouter` should own browser URL integration.

- Top-level app should use only the app-shell as `MaterialApp.router(routerConfig: appShellRouter)`.
- Global/account `WorkingRouter` instances should be mounted as child `Router` widgets via `routerDelegate`, not as top-level `routerConfig`.
- Inactive account routers keep state in memory; they do not write browser URL.

How URL updates happen:

1. `AppShellRouter` listens to navigation events from the active router (for example using `activeRouter.routeTransitions`).
2. On each committed transition, `AppShellRouter` updates its own `currentConfiguration` (for example `/accounts/:accountId/*subroute`) and calls `notifyListeners()`.
3. Flutter Router updates the single browser URL from the app-shell configuration.

Do you need to disable route information parsing/providers in child `WorkingRouter`s?

- No, as long as child `WorkingRouter`s are not used as top-level `routerConfig`.
- Their parser/provider are effectively unused in child-router mode.
- If you mount a child `WorkingRouter` as `MaterialApp.router(routerConfig: childRouter)`, it will compete for URL ownership, which is not desired in this architecture.

## Draft `AppShellRouter` Implementation

This is a draft shape you can hand to another agent and adapt to your app:
For brevity, this draft keeps coordinator logic inside `AppShellRouter`.
In production, split that logic into `AppNavigationCoordinator` and keep `AppShellRouter` thin.

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

enum AppMode { global, accounts }
enum GlobalLocationId { login, forgotPassword, addAccount }
enum AccountLocationId { inbox, thread, settings }

class AppShellRouter extends ChangeNotifier implements RouterConfig<Uri> {
  AppShellRouter({
    required this.buildGlobalRouter,
    required this.buildAccountRouter,
    this.initialUri,
  }) {
    globalRouter = buildGlobalRouter();
    _delegate = _AppShellDelegate(this);
    _informationProvider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(
        // ignore: deprecated_member_use
        location:
            (initialUri ?? Uri(path: '/login')).toString(),
      ),
    );
    _subscribeToGlobalRouter();
  }

  final WorkingRouter<GlobalLocationId> Function() buildGlobalRouter;
  final WorkingRouter<AccountLocationId> Function(Uri? initialUri)
      buildAccountRouter;
  final Uri? initialUri;

  late final WorkingRouter<GlobalLocationId> globalRouter;
  final Map<String, WorkingRouter<AccountLocationId>> _accountRouters = {};
  final Map<String, StreamSubscription<RouteTransition<AccountLocationId>>>
      _accountSubs = {};
  StreamSubscription<RouteTransition<GlobalLocationId>>? _globalSub;

  AppMode mode = AppMode.global;
  String? activeAccountId;

  late final _AppShellDelegate _delegate;
  late final RouteInformationProvider _informationProvider;
  final WorkingRouteInformationParser _parser = WorkingRouteInformationParser();

  @override
  RouteInformationParser<Uri> get routeInformationParser => _parser;

  @override
  RouteInformationProvider get routeInformationProvider => _informationProvider;

  @override
  RouterDelegate<Uri> get routerDelegate => _delegate;

  // URL written to browser by Flutter Router.
  Uri get currentConfiguration {
    if (mode == AppMode.global) {
      return globalRouter.nullableData?.uri ?? Uri(path: '/login');
    }
    final accountId = activeAccountId;
    if (accountId == null) {
      return Uri(path: '/login');
    }
    final subroute = _accountRouters[accountId]?.nullableData?.uri ?? Uri(path: '/');
    return Uri(
      path: '/accounts/$accountId${subroute.path == '/' ? '' : subroute.path}',
      queryParameters: subroute.queryParameters.isEmpty
          ? null
          : subroute.queryParameters,
    );
  }

  Future<void> setNewRoutePath(Uri uri) async {
    final globalPath = uri.path;
    if (_isGlobalPath(globalPath)) {
      mode = AppMode.global;
      globalRouter.routeToUri(uri);
      notifyListeners();
      return;
    }

    final parsed = _parseAccountUrl(uri);
    if (parsed == null) {
      mode = AppMode.global;
      globalRouter.routeToId(GlobalLocationId.login);
      notifyListeners();
      return;
    }

    final accountId = parsed.$1;
    final subroute = parsed.$2;
    final router = _ensureAccountRouter(accountId, initialUri: subroute);

    activeAccountId = accountId;
    mode = AppMode.accounts;
    router.routeToUri(subroute);
    notifyListeners();
  }

  void routeToGlobal(GlobalLocationId id) {
    mode = AppMode.global;
    globalRouter.routeToId(id);
    notifyListeners();
  }

  void routeToAccount(String accountId, AccountLocationId id) {
    final router = _ensureAccountRouter(accountId);
    activeAccountId = accountId;
    mode = AppMode.accounts;
    router.routeToId(id);
    notifyListeners();
  }

  void routeToActiveAccount(AccountLocationId id) {
    final accountId = activeAccountId;
    if (accountId == null) return;
    routeToAccount(accountId, id);
  }

  WorkingRouter<AccountLocationId> _ensureAccountRouter(
    String accountId, {
    Uri? initialUri,
  }) {
    final existing = _accountRouters[accountId];
    if (existing != null) return existing;

    final router = buildAccountRouter(initialUri);
    _accountRouters[accountId] = router;
    _accountSubs[accountId] = router.routeTransitions.listen((_) {
      if (mode == AppMode.accounts && activeAccountId == accountId) {
        notifyListeners();
      }
    });
    return router;
  }

  void _subscribeToGlobalRouter() {
    _globalSub = globalRouter.routeTransitions.listen((_) {
      if (mode == AppMode.global) {
        notifyListeners();
      }
    });
  }

  bool _isGlobalPath(String path) {
    return path == '/login' ||
        path == '/forgot-password' ||
        path == '/accounts/add';
  }

  // Returns (accountId, subroute) for /accounts/:accountId/*subroute.
  (String, Uri)? _parseAccountUrl(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments.first != 'accounts') return null;
    final accountId = segments[1];
    final rest = segments.skip(2).toList();
    final subPath = rest.isEmpty ? '/' : '/${rest.join('/')}';
    return (
      accountId,
      Uri(path: subPath, queryParameters: uri.queryParameters),
    );
  }

  @override
  void dispose() {
    _globalSub?.cancel();
    for (final sub in _accountSubs.values) {
      sub.cancel();
    }
    globalRouter.dispose();
    for (final router in _accountRouters.values) {
      router.dispose();
    }
    super.dispose();
  }
}

class _AppShellDelegate extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  _AppShellDelegate(this.shell) {
    shell.addListener(notifyListeners);
  }

  final AppShellRouter shell;

  @override
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'app-shell');

  @override
  Uri? get currentConfiguration => shell.currentConfiguration;

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    return shell.setNewRoutePath(configuration);
  }

  @override
  Widget build(BuildContext context) {
    if (shell.mode == AppMode.global) {
      return Router(
        routerDelegate: shell.globalRouter.routerDelegate,
        backButtonDispatcher: RootBackButtonDispatcher(),
      );
    }

    return _AccountsHost(
      activeAccountId: shell.activeAccountId,
      accountRouters: shell._accountRouters,
    );
  }

  @override
  void dispose() {
    shell.removeListener(notifyListeners);
    super.dispose();
  }
}

class _AccountsHost extends StatelessWidget {
  const _AccountsHost({
    required this.activeAccountId,
    required this.accountRouters,
  });

  final String? activeAccountId;
  final Map<String, WorkingRouter<AccountLocationId>> accountRouters;

  @override
  Widget build(BuildContext context) {
    // Replace with your own swipe UI (PageView/CustomScroll + gesture/app bar).
    final accounts = accountRouters.entries.toList();
    final activeIndex =
        activeAccountId == null
            ? 0
            : accounts.indexWhere((e) => e.key == activeAccountId);
    return IndexedStack(
      index: activeIndex < 0 ? 0 : activeIndex,
      children: [
        for (final entry in accounts)
          KeyedSubtree(
            key: ValueKey('account-${entry.key}'),
            child: Router(routerDelegate: entry.value.routerDelegate),
          ),
      ],
    );
  }
}
```

Adapt this draft to your app state/auth loading and account hydration.

## Why The Name `AppShellRouter`?

`App shell` is the outer frame of your app:
- auth/global screens
- account container/scaffold
- URL ownership
- top-level mode switching

The shell does not own detailed feature routes inside each account. It coordinates which child router is active and what the browser URL should represent.

## Recommended Structure

Prefer this split in production:

1. `AppNavigationCoordinator` (state + navigation decisions + route commands)
2. `AppShellRouter` (thin `RouterConfig<Uri>` adapter over the coordinator)

The coordinator should hold app routing state (`mode`, `activeAccountId`, router map) and expose methods like `routeToGlobal` and `routeToAccount`.
The shell router should mostly forward Router API calls (`setNewRoutePath`, `currentConfiguration`) and rebuild when coordinator state changes.

## Practical Notes

- Keep URL ownership in the app-shell coordinator.
- Keep account stacks inside account routers.
- Keep global auth/account-management flow in the global router.
- Use account router state (not URL) as source of truth for inactive accounts.

## Existing Example

See `example/lib/state_preserving_tabs/main.dart` for the same core idea: multiple nested navigators preserving independent state.
