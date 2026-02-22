import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/transition_decision.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_information_parser.dart';

/// Resolves a host URL into a selected scope and subroute.
///
/// A null [scope] means the global router should be used.
class ScopeResolution<Scope> {
  final Scope? scope;
  final Uri scopedUri;

  const ScopeResolution({
    required this.scope,
    required this.scopedUri,
  });

  const ScopeResolution.global({required Uri scopedUri})
    : this(scope: null, scopedUri: scopedUri);

  const ScopeResolution.scoped({
    required Scope scope,
    required Uri scopedUri,
  }) : this(scope: scope, scopedUri: scopedUri);

  bool get isGlobal => scope == null;
}

typedef ResolveScope<Scope> = ScopeResolution<Scope> Function(Uri uri);
typedef BuildHostUri<Scope> = Uri Function(ScopeResolution<Scope> resolution);
typedef BuildScopedRouter<Scope> =
    WorkingRouter<dynamic> Function(
      Scope scope,
      Uri? initialUri,
    );
typedef ScopedRouterHostBuilder<Scope> =
    Widget Function(
      BuildContext context,
      ScopedRouterHost<Scope> host,
      Widget activeRouter,
    );

/// A generic router host that coordinates a global router and lazily created
/// scoped routers (for example account/workspace/tenant scopes).
class ScopedRouterHost<Scope> extends ChangeNotifier
    implements RouterConfig<Uri> {
  final WorkingRouter<dynamic> globalRouter;
  final ResolveScope<Scope> resolveScope;
  final BuildHostUri<Scope> buildHostUri;
  final BuildScopedRouter<Scope> buildScopedRouter;
  final ScopedRouterHostBuilder<Scope>? buildShell;
  final bool disposeRoutersOnDispose;

  final Map<Scope, WorkingRouter<dynamic>> _scopedRouters = {};
  final Map<Scope, StreamSubscription<RouteTransition<dynamic>>>
  _scopedRouterSubscriptions = {};
  final Map<Scope, Uri> _lastKnownScopedUris = {};

  late final StreamSubscription<RouteTransition<dynamic>>
  _globalRouterSubscription;
  Uri _lastKnownGlobalUri = Uri(path: '/');
  Scope? _activeScope;
  bool _isDisposed = false;

  late final _ScopedRouterHostDelegate<Scope> _delegate;
  final WorkingRouteInformationParser _informationParser =
      WorkingRouteInformationParser();
  late final RouteInformationProvider _informationProvider;

  ScopedRouterHost({
    required this.globalRouter,
    required this.resolveScope,
    required this.buildHostUri,
    required this.buildScopedRouter,
    this.buildShell,
    this.disposeRoutersOnDispose = true,
    GlobalKey<NavigatorState>? navigatorKey,
    Uri? initialUri,
  }) {
    final initialConfiguration =
        initialUri ??
        Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    _informationProvider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(
        // ignore: deprecated_member_use
        location: initialConfiguration.toString(),
      ),
    );
    _delegate = _ScopedRouterHostDelegate<Scope>(
      host: this,
      navigatorKey:
          navigatorKey ??
          GlobalKey<NavigatorState>(debugLabel: 'scoped-router-host'),
    );
    _globalRouterSubscription = globalRouter.routeTransitions.listen((
      transition,
    ) {
      _lastKnownGlobalUri = transition.to.uri;
      if (_activeScope == null && !_isDisposed) {
        notifyListeners();
      }
    });

    routeToUri(initialConfiguration);
  }

  /// Null means the global router is active.
  Scope? get activeScope => _activeScope;

  bool get isGlobalActive => _activeScope == null;

  Iterable<Scope> get scopes => _scopedRouters.keys;

  @override
  BackButtonDispatcher? get backButtonDispatcher => RootBackButtonDispatcher();

  @override
  RouteInformationParser<Uri>? get routeInformationParser => _informationParser;

  @override
  RouteInformationProvider? get routeInformationProvider =>
      _informationProvider;

  @override
  RouterDelegate<Uri> get routerDelegate => _delegate;

  /// Current URI exposed to Flutter Router for browser URL updates.
  Uri get currentConfiguration {
    final scope = _activeScope;
    if (scope == null) {
      return buildHostUri(
        ScopeResolution.global(
          scopedUri: globalRouter.nullableData?.uri ?? _lastKnownGlobalUri,
        ),
      );
    }

    final scopedUri =
        _scopedRouters[scope]?.nullableData?.uri ??
        _lastKnownScopedUris[scope] ??
        Uri(path: '/');
    return buildHostUri(
      ScopeResolution.scoped(
        scope: scope,
        scopedUri: scopedUri,
      ),
    );
  }

  Map<Scope, WorkingRouter<dynamic>> get scopedRouters =>
      Map.unmodifiable(_scopedRouters);

  WorkingRouter<dynamic>? scopeRouterOrNull(Scope scope) =>
      _scopedRouters[scope];

  WorkingRouter<dynamic> ensureScopeRouter(
    Scope scope, {
    Uri? initialUri,
  }) {
    final existing = _scopedRouters[scope];
    if (existing != null) {
      return existing;
    }

    final router = buildScopedRouter(scope, initialUri);
    _scopedRouters[scope] = router;
    if (router.nullableData != null) {
      _lastKnownScopedUris[scope] = router.nullableData!.uri;
    } else if (initialUri != null) {
      _lastKnownScopedUris[scope] = initialUri;
    }
    _scopedRouterSubscriptions[scope] = router.routeTransitions.listen((
      transition,
    ) {
      _lastKnownScopedUris[scope] = transition.to.uri;
      if (_activeScope == scope && !_isDisposed) {
        notifyListeners();
      }
    });
    return router;
  }

  void removeScope(
    Scope scope, {
    bool disposeRouter = true,
  }) {
    final subscription = _scopedRouterSubscriptions.remove(scope);
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    final removedRouter = _scopedRouters.remove(scope);
    _lastKnownScopedUris.remove(scope);
    if (_activeScope == scope) {
      _activeScope = null;
    }
    if (disposeRouter) {
      removedRouter?.dispose();
    }
    notifyListeners();
  }

  /// Programmatic host URL routing. Uses [resolveScope] to dispatch.
  void routeToUri(Uri uri) {
    _routeToUri(uri, fromRouteInformation: false);
  }

  /// Called by the host delegate for browser/back-forward updates.
  void routeToUriFromRouteInformation(Uri uri) {
    _routeToUri(uri, fromRouteInformation: true);
  }

  void routeToGlobalUri(Uri uri) {
    _activeScope = null;
    _lastKnownGlobalUri = uri;
    globalRouter.routeToUri(uri);
    notifyListeners();
  }

  void routeToScopedUri(
    Scope scope,
    Uri scopedUri,
  ) {
    final router = ensureScopeRouter(scope, initialUri: scopedUri);
    _activeScope = scope;
    _lastKnownScopedUris[scope] = scopedUri;
    router.routeToUri(scopedUri);
    notifyListeners();
  }

  Widget buildGlobalRouterWidget(BuildContext context) {
    return _buildRouterWidget(
      context,
      globalRouter,
    );
  }

  Widget buildScopeRouterWidget(
    BuildContext context,
    Scope scope, {
    Uri? initialUri,
  }) {
    return _buildRouterWidget(
      context,
      ensureScopeRouter(scope, initialUri: initialUri),
    );
  }

  Widget buildActiveRouterWidget(BuildContext context) {
    final scope = _activeScope;
    if (scope == null) {
      return buildGlobalRouterWidget(context);
    }
    return buildScopeRouterWidget(context, scope);
  }

  Widget _buildRouterWidget(
    BuildContext context,
    WorkingRouter<dynamic> router,
  ) {
    final parentRouter = Router.of(context);
    final childBackButtonDispatcher = parentRouter.backButtonDispatcher
        ?.createChildBackButtonDispatcher();
    childBackButtonDispatcher?.takePriority();
    return Router(
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: childBackButtonDispatcher,
    );
  }

  void _routeToUri(
    Uri uri, {
    required bool fromRouteInformation,
  }) {
    final resolution = resolveScope(uri);
    if (resolution.isGlobal) {
      _activeScope = null;
      _lastKnownGlobalUri = resolution.scopedUri;
      if (fromRouteInformation) {
        globalRouter.routeToUriFromRouteInformation(resolution.scopedUri);
      } else {
        globalRouter.routeToUri(resolution.scopedUri);
      }
      notifyListeners();
      return;
    }

    final scope = resolution.scope as Scope;
    final router = ensureScopeRouter(scope, initialUri: resolution.scopedUri);
    _activeScope = scope;
    _lastKnownScopedUris[scope] = resolution.scopedUri;
    if (fromRouteInformation) {
      router.routeToUriFromRouteInformation(resolution.scopedUri);
    } else {
      router.routeToUri(resolution.scopedUri);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_globalRouterSubscription.cancel());
    for (final it in _scopedRouterSubscriptions.values) {
      unawaited(it.cancel());
    }
    if (disposeRoutersOnDispose) {
      globalRouter.dispose();
      for (final it in _scopedRouters.values) {
        it.dispose();
      }
    }
    super.dispose();
  }
}

class _ScopedRouterHostDelegate<Scope> extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  final ScopedRouterHost<Scope> host;

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  _ScopedRouterHostDelegate({
    required this.host,
    required this.navigatorKey,
  }) {
    host.addListener(notifyListeners);
  }

  @override
  Uri? get currentConfiguration => host.currentConfiguration;

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    host.routeToUriFromRouteInformation(configuration);
    return SynchronousFuture<void>(null);
  }

  @override
  Widget build(BuildContext context) {
    final activeRouter = host.buildActiveRouterWidget(context);
    final shellBuilder = host.buildShell;
    if (shellBuilder == null) {
      return activeRouter;
    }
    return shellBuilder(context, host, activeRouter);
  }

  @override
  void dispose() {
    host.removeListener(notifyListeners);
    super.dispose();
  }
}
