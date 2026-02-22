import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:working_router/src/location_v2.dart';
import 'package:working_router/src/transition_decision.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_information_parser.dart';

typedef ScopeShellBuilder<ScopeKey, RouteId> =
    Widget Function(
      BuildContext context,
      WorkingRouterV2<ScopeKey, RouteId> router,
      Widget activeRouter,
    );

sealed class InitialRouteSeed<RouteId> {
  const InitialRouteSeed();

  const factory InitialRouteSeed.id(
    RouteId id, {
    Map<String, String> pathParameters,
    Map<String, String> queryParameters,
  }) = InitialRouteById<RouteId>;
}

final class InitialRouteById<RouteId> extends InitialRouteSeed<RouteId> {
  final RouteId id;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;

  const InitialRouteById(
    this.id, {
    this.pathParameters = const {},
    this.queryParameters = const {},
  });
}

enum ScopeTransitionReason {
  programmatic,
  routeInformation,
}

class ScopeTransition<ScopeKey> {
  final ScopeKey from;
  final ScopeKey to;
  final ScopeTransitionReason reason;

  const ScopeTransition({
    required this.from,
    required this.to,
    required this.reason,
  });
}

class ScopedRouteTransition<ScopeKey, RouteId> {
  final ScopeKey scope;
  final RouteTransition<RouteId> transition;

  const ScopedRouteTransition({
    required this.scope,
    required this.transition,
  });
}

class WorkingRouterV2<ScopeKey, RouteId> extends ChangeNotifier
    implements RouterConfig<Uri> {
  final ScopeKey initialScope;
  final ScopeRootLocationV2<ScopeKey, RouteId> root;
  final ScopeShellBuilder<ScopeKey, RouteId>? buildShell;
  final bool disposeRoutersOnDispose;

  final Map<ScopeKey, WorkingRouter<RouteId>> _scopeRouters = {};
  final Map<ScopeKey, StreamSubscription<RouteTransition<RouteId>>>
  _scopeRouterSubscriptions = {};
  final Map<ScopeKey, Uri> _lastKnownScopedUris = {};
  final Map<ScopeKey, _ScopeEntry<ScopeKey, RouteId>> _scopeEntriesByScope =
      <ScopeKey, _ScopeEntry<ScopeKey, RouteId>>{};
  final StreamController<ScopeTransition<ScopeKey>> _scopeTransitionController =
      StreamController<ScopeTransition<ScopeKey>>.broadcast();
  final StreamController<ScopedRouteTransition<ScopeKey, RouteId>>
  _routeTransitionController =
      StreamController<ScopedRouteTransition<ScopeKey, RouteId>>.broadcast();

  final WorkingRouteInformationParser _informationParser =
      WorkingRouteInformationParser();
  late final RouteInformationProvider _informationProvider;
  late final _WorkingRouterV2Delegate<ScopeKey, RouteId> _delegate;

  final List<_ScopeEntry<ScopeKey, RouteId>> _scopeEntries;
  final Map<
    ScopeBoundaryLocationV2<ScopeKey, RouteId>,
    _ScopeEntry<ScopeKey, RouteId>
  >
  _scopeEntriesByNode;

  bool _isDisposed = false;
  ScopeKey _activeScope;

  WorkingRouterV2({
    required this.initialScope,
    required this.root,
    this.buildShell,
    this.disposeRoutersOnDispose = true,
    GlobalKey<NavigatorState>? navigatorKey,
    Uri? initialUri,
    InitialRouteSeed<RouteId>? initialRoute,
  }) : _scopeEntries = _collectScopeEntries(root),
       _scopeEntriesByNode =
           <
             ScopeBoundaryLocationV2<ScopeKey, RouteId>,
             _ScopeEntry<ScopeKey, RouteId>
           >{},
       _activeScope = initialScope {
    for (final entry in _scopeEntries) {
      _scopeEntriesByNode[entry.node] = entry;
    }
    if (_scopeEntries.isEmpty) {
      throw ArgumentError('V2 root tree must contain at least one scope node.');
    }

    final initialConfiguration =
        initialUri ??
        Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    _informationProvider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(
        // ignore: deprecated_member_use
        location: initialConfiguration.toString(),
      ),
    );
    _delegate = _WorkingRouterV2Delegate<ScopeKey, RouteId>(
      host: this,
      navigatorKey:
          navigatorKey ??
          GlobalKey<NavigatorState>(debugLabel: 'working-router-v2'),
    );

    if (initialUri != null) {
      routeToUri(initialUri);
      return;
    }
    if (initialRoute case InitialRouteById<RouteId>(
      :final id,
      :final pathParameters,
      :final queryParameters,
    )) {
      ensureScope(initialScope).routeToId(
        id,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
      );
      _setActiveScope(initialScope, reason: ScopeTransitionReason.programmatic);
      return;
    }
    routeToUri(initialConfiguration);
  }

  ScopeKey get activeScope => _activeScope;

  Iterable<ScopeKey> get scopes => _scopeRouters.keys;

  Stream<ScopeTransition<ScopeKey>> get scopeTransitions =>
      _scopeTransitionController.stream;

  Stream<ScopedRouteTransition<ScopeKey, RouteId>> get routeTransitions =>
      _routeTransitionController.stream;

  @override
  BackButtonDispatcher? get backButtonDispatcher => RootBackButtonDispatcher();

  @override
  RouteInformationParser<Uri>? get routeInformationParser => _informationParser;

  @override
  RouteInformationProvider? get routeInformationProvider =>
      _informationProvider;

  @override
  RouterDelegate<Uri> get routerDelegate => _delegate;

  Uri get currentConfiguration {
    final scopedUri =
        _scopeRouters[_activeScope]?.nullableData?.uri ??
        _lastKnownScopedUris[_activeScope] ??
        Uri(path: '/');
    return _buildHostUri(scope: _activeScope, scopedUri: scopedUri);
  }

  WorkingRouter<RouteId>? scopeRouterOrNull(ScopeKey scope) {
    return _scopeRouters[scope];
  }

  WorkingRouter<RouteId> ensureScope(
    ScopeKey scope, {
    Uri? initialScopedUri,
  }) {
    final existing = _scopeRouters[scope];
    if (existing != null) {
      return existing;
    }

    final scopeEntry = _scopeEntriesByScope[scope] ?? _findScopeEntryFor(scope);
    if (scopeEntry == null) {
      throw ArgumentError(
        'No scope location in root tree can serialize scope "$scope".',
      );
    }

    final router = scopeEntry.node.buildScopeRouterFor(
      scope,
      scopeEntry.subtree,
      initialScopedUri,
    );
    _scopeRouters[scope] = router;
    _scopeEntriesByScope[scope] = scopeEntry;
    if (router.nullableData != null) {
      _lastKnownScopedUris[scope] = router.nullableData!.uri;
    } else if (initialScopedUri != null) {
      _lastKnownScopedUris[scope] = initialScopedUri;
    }
    _scopeRouterSubscriptions[scope] = router.routeTransitions.listen((
      transition,
    ) {
      _lastKnownScopedUris[scope] = transition.to.uri;
      _routeTransitionController.add(
        ScopedRouteTransition<ScopeKey, RouteId>(
          scope: scope,
          transition: transition,
        ),
      );
      if (_activeScope == scope && !_isDisposed) {
        notifyListeners();
      }
    });
    return router;
  }

  void removeScope(
    ScopeKey scope, {
    bool disposeRouter = true,
  }) {
    final subscription = _scopeRouterSubscriptions.remove(scope);
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    final removed = _scopeRouters.remove(scope);
    _scopeEntriesByScope.remove(scope);
    _lastKnownScopedUris.remove(scope);

    if (disposeRouter) {
      removed?.dispose();
    }

    if (_activeScope == scope) {
      final fallbackScope = _scopeRouters.isEmpty
          ? initialScope
          : _scopeRouters.keys.first;
      _activeScope = fallbackScope;
      ensureScope(fallbackScope);
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  void routeToUri(Uri uri) {
    _routeToUri(uri, fromRouteInformation: false);
  }

  void routeToUriFromRouteInformation(Uri uri) {
    _routeToUri(uri, fromRouteInformation: true);
  }

  void routeToId(
    RouteId id, {
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    final router = ensureScope(_activeScope);
    router.routeToId(
      id,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );
  }

  void routeBack() {
    final router = _scopeRouters[_activeScope];
    router?.routeBack();
  }

  Uri uriForScope(ScopeKey scope, {Uri? scopedUri}) {
    final resolvedScopedUri =
        scopedUri ??
        _scopeRouters[scope]?.nullableData?.uri ??
        _lastKnownScopedUris[scope] ??
        Uri(path: '/');
    return _buildHostUri(scope: scope, scopedUri: resolvedScopedUri);
  }

  void activateScope(
    ScopeKey scope, {
    Uri? initialScopedUri,
  }) {
    final targetScopedUri =
        _scopeRouters[scope]?.nullableData?.uri ??
        _lastKnownScopedUris[scope] ??
        initialScopedUri ??
        Uri(path: '/');
    routeToUri(uriForScope(scope, scopedUri: targetScopedUri));
  }

  Widget buildScopeRouterWidget(
    BuildContext context,
    ScopeKey scope, {
    Uri? initialScopedUri,
  }) {
    final router = ensureScope(scope, initialScopedUri: initialScopedUri);
    return _buildRouterWidget(context, router);
  }

  Widget buildActiveRouterWidget(BuildContext context) {
    return buildScopeRouterWidget(context, _activeScope);
  }

  Widget _buildRouterWidget(
    BuildContext context,
    WorkingRouter<RouteId> router,
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

  void _routeToUri(Uri uri, {required bool fromRouteInformation}) {
    final resolved = _resolveUri(uri);
    final router = ensureScope(
      resolved.scope,
      initialScopedUri: resolved.scopedUri,
    );
    _setActiveScope(
      resolved.scope,
      reason: fromRouteInformation
          ? ScopeTransitionReason.routeInformation
          : ScopeTransitionReason.programmatic,
    );
    _lastKnownScopedUris[resolved.scope] = resolved.scopedUri;
    if (fromRouteInformation) {
      router.routeToUriFromRouteInformation(resolved.scopedUri);
    } else {
      router.routeToUri(resolved.scopedUri);
    }
    notifyListeners();
  }

  void _setActiveScope(
    ScopeKey scope, {
    required ScopeTransitionReason reason,
  }) {
    final oldScope = _activeScope;
    _activeScope = scope;
    if (oldScope != scope) {
      _scopeTransitionController.add(
        ScopeTransition<ScopeKey>(
          from: oldScope,
          to: scope,
          reason: reason,
        ),
      );
    }
  }

  _ResolvedScopeRoute<ScopeKey, RouteId> _resolveUri(Uri uri) {
    final segments = uri.pathSegments;
    final fullMatch = _matchFullTree(
      node: root,
      segments: segments,
      pathParameters: const <String, String>{},
      chain: <_NodeMatch<ScopeKey, RouteId>>[],
      score: const _PrefixPatternMatch(
        staticSegments: 0,
        totalSegments: 0,
      ),
    );

    if (fullMatch != null) {
      final boundaryIndex = fullMatch.chain.lastIndexWhere(
        (match) => match.node is ScopeBoundaryLocationV2<ScopeKey, RouteId>,
      );
      if (boundaryIndex != -1) {
        final boundaryNode =
            fullMatch.chain[boundaryIndex].node
                as ScopeBoundaryLocationV2<ScopeKey, RouteId>;
        final entry = _scopeEntriesByNode[boundaryNode]!;
        final scope = boundaryNode.resolveScope(fullMatch.pathParameters);
        _scopeEntriesByScope[scope] = entry;
        final subSegments = fullMatch.chain
            .skip(boundaryIndex + 1)
            .expand((match) => match.actualSegments)
            .toList(growable: false);
        return _ResolvedScopeRoute<ScopeKey, RouteId>(
          scope: scope,
          entry: entry,
          scopedUri: _buildScopedUri(
            subSegments: subSegments,
            source: uri,
          ),
        );
      }
    }

    final boundaryPrefixMatch = _matchScopeBoundaryPrefix(segments);
    if (boundaryPrefixMatch != null) {
      final scope = boundaryPrefixMatch.entry.node.resolveScope(
        boundaryPrefixMatch.pathParameters,
      );
      _scopeEntriesByScope[scope] = boundaryPrefixMatch.entry;
      final subSegments = segments
          .skip(boundaryPrefixMatch.consumedSegments)
          .toList(growable: false);
      return _ResolvedScopeRoute<ScopeKey, RouteId>(
        scope: scope,
        entry: boundaryPrefixMatch.entry,
        scopedUri: _buildScopedUri(
          subSegments: subSegments,
          source: uri,
        ),
      );
    }

    final fallbackEntry =
        _scopeEntriesByScope[_activeScope] ??
        _findScopeEntryFor(_activeScope) ??
        _scopeEntries.first;
    return _ResolvedScopeRoute<ScopeKey, RouteId>(
      scope: _activeScope,
      entry: fallbackEntry,
      scopedUri: uri,
    );
  }

  Uri _buildScopedUri({
    required List<String> subSegments,
    required Uri source,
  }) {
    return Uri(
      path: subSegments.isEmpty ? '/' : '/${subSegments.join('/')}',
      queryParameters: source.queryParameters.isEmpty
          ? null
          : source.queryParameters,
    );
  }

  Uri _buildHostUri({
    required ScopeKey scope,
    required Uri scopedUri,
  }) {
    final entry =
        _scopeEntriesByScope[scope] ??
        _findScopeEntryFor(scope) ??
        _scopeEntries.first;
    final scopeParameters = entry.node.trySerializeScopeParams(scope);
    if (scopeParameters == null) {
      throw ArgumentError(
        'Scope "$scope" cannot be serialized by ${entry.node.runtimeType}.',
      );
    }

    final scopePrefixSegments = entry.fullPatternSegments.map((segment) {
      if (!segment.startsWith(':')) {
        return segment;
      }
      final parameter = scopeParameters[segment.substring(1)];
      if (parameter == null) {
        throw ArgumentError(
          'Missing serialized scope parameter "${segment.substring(1)}" '
          'for scope "$scope".',
        );
      }
      return parameter;
    });

    final hostPathSegments = <String>[
      ...scopePrefixSegments,
      ...scopedUri.pathSegments,
    ];
    return Uri(
      path: hostPathSegments.isEmpty ? '/' : '/${hostPathSegments.join('/')}',
      queryParameters: scopedUri.queryParameters.isEmpty
          ? null
          : scopedUri.queryParameters,
    );
  }

  _ScopeEntry<ScopeKey, RouteId>? _findScopeEntryFor(ScopeKey scope) {
    _PrefixPatternMatch? bestMatch;
    _ScopeEntry<ScopeKey, RouteId>? bestEntry;
    for (final entry in _scopeEntries) {
      final serialized = entry.node.trySerializeScopeParams(scope);
      if (serialized == null) {
        continue;
      }
      final score = _scorePattern(entry.fullPatternSegments);
      if (_isBetterPatternMatch(score, bestMatch)) {
        bestMatch = score;
        bestEntry = entry;
      }
    }
    return bestEntry;
  }

  _ScopeBoundaryPrefixMatch<ScopeKey, RouteId>? _matchScopeBoundaryPrefix(
    List<String> uriSegments,
  ) {
    _ScopeBoundaryPrefixMatch<ScopeKey, RouteId>? best;

    for (final entry in _scopeEntries) {
      final prefixMatch = _matchPatternPrefix(
        patternSegments: entry.fullPatternSegments,
        targetSegments: uriSegments,
      );
      if (prefixMatch == null) {
        continue;
      }
      final candidate = _ScopeBoundaryPrefixMatch<ScopeKey, RouteId>(
        entry: entry,
        consumedSegments: prefixMatch.consumedSegments,
        pathParameters: prefixMatch.pathParameters,
        score: prefixMatch.score,
      );

      if (_isBetterBoundaryPrefixMatch(candidate, best)) {
        best = candidate;
      }
    }
    return best;
  }

  _TreeMatchResult<ScopeKey, RouteId>? _matchFullTree({
    required LocationV2<ScopeKey, RouteId> node,
    required List<String> segments,
    required Map<String, String> pathParameters,
    required List<_NodeMatch<ScopeKey, RouteId>> chain,
    required _PrefixPatternMatch score,
  }) {
    final prefixMatch = _matchPatternPrefix(
      patternSegments: node.pathSegments,
      targetSegments: segments,
    );
    if (prefixMatch == null) {
      return null;
    }

    final nextPathParameters = <String, String>{
      ...pathParameters,
      ...prefixMatch.pathParameters,
    };
    final consumedSegments = segments
        .take(prefixMatch.consumedSegments)
        .toList();
    final nextChain = <_NodeMatch<ScopeKey, RouteId>>[
      ...chain,
      _NodeMatch<ScopeKey, RouteId>(
        node: node,
        actualSegments: consumedSegments,
      ),
    ];
    final nextScore = _PrefixPatternMatch(
      staticSegments: score.staticSegments + prefixMatch.score.staticSegments,
      totalSegments: score.totalSegments + prefixMatch.score.totalSegments,
    );
    final remainingSegments = segments
        .skip(prefixMatch.consumedSegments)
        .toList();
    if (remainingSegments.isEmpty) {
      return _TreeMatchResult<ScopeKey, RouteId>(
        chain: nextChain,
        pathParameters: nextPathParameters,
        score: nextScore,
      );
    }

    _TreeMatchResult<ScopeKey, RouteId>? bestChildMatch;
    for (final child in _prioritize(node.children)) {
      final childMatch = _matchFullTree(
        node: child,
        segments: remainingSegments,
        pathParameters: nextPathParameters,
        chain: nextChain,
        score: nextScore,
      );
      if (childMatch == null) {
        continue;
      }
      if (bestChildMatch == null ||
          _isBetterPatternMatch(childMatch.score, bestChildMatch.score)) {
        bestChildMatch = childMatch;
      }
    }

    return bestChildMatch;
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final subscription in _scopeRouterSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    if (disposeRoutersOnDispose) {
      for (final router in _scopeRouters.values) {
        router.dispose();
      }
    }
    unawaited(_scopeTransitionController.close());
    unawaited(_routeTransitionController.close());
    super.dispose();
  }
}

class _WorkingRouterV2Delegate<ScopeKey, RouteId> extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  final WorkingRouterV2<ScopeKey, RouteId> host;

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  _WorkingRouterV2Delegate({
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

class _ResolvedScopeRoute<ScopeKey, RouteId> {
  final ScopeKey scope;
  final _ScopeEntry<ScopeKey, RouteId> entry;
  final Uri scopedUri;

  const _ResolvedScopeRoute({
    required this.scope,
    required this.entry,
    required this.scopedUri,
  });
}

class _ScopeEntry<ScopeKey, RouteId> {
  final ScopeBoundaryLocationV2<ScopeKey, RouteId> node;
  final List<String> fullPatternSegments;
  final ScopeRouteSubtree<ScopeKey, RouteId> subtree;

  const _ScopeEntry({
    required this.node,
    required this.fullPatternSegments,
    required this.subtree,
  });
}

class _NodeMatch<ScopeKey, RouteId> {
  final LocationV2<ScopeKey, RouteId> node;
  final List<String> actualSegments;

  const _NodeMatch({
    required this.node,
    required this.actualSegments,
  });
}

class _TreeMatchResult<ScopeKey, RouteId> {
  final List<_NodeMatch<ScopeKey, RouteId>> chain;
  final Map<String, String> pathParameters;
  final _PrefixPatternMatch score;

  const _TreeMatchResult({
    required this.chain,
    required this.pathParameters,
    required this.score,
  });
}

class _PatternPrefixMatch {
  final int consumedSegments;
  final Map<String, String> pathParameters;
  final _PrefixPatternMatch score;

  const _PatternPrefixMatch({
    required this.consumedSegments,
    required this.pathParameters,
    required this.score,
  });
}

class _PrefixPatternMatch {
  final int staticSegments;
  final int totalSegments;

  const _PrefixPatternMatch({
    required this.staticSegments,
    required this.totalSegments,
  });
}

class _ScopeBoundaryPrefixMatch<ScopeKey, RouteId> {
  final _ScopeEntry<ScopeKey, RouteId> entry;
  final int consumedSegments;
  final Map<String, String> pathParameters;
  final _PrefixPatternMatch score;

  const _ScopeBoundaryPrefixMatch({
    required this.entry,
    required this.consumedSegments,
    required this.pathParameters,
    required this.score,
  });
}

List<_ScopeEntry<ScopeKey, RouteId>> _collectScopeEntries<ScopeKey, RouteId>(
  LocationV2<ScopeKey, RouteId> root,
) {
  final entries = <_ScopeEntry<ScopeKey, RouteId>>[];

  void visit(
    LocationV2<ScopeKey, RouteId> node, {
    required List<String> prefixSegments,
  }) {
    final fullSegments = <String>[
      ...prefixSegments,
      ...node.pathSegments,
    ];

    if (node is ScopeBoundaryLocationV2<ScopeKey, RouteId>) {
      entries.add(
        _ScopeEntry<ScopeKey, RouteId>(
          node: node,
          fullPatternSegments: fullSegments,
          subtree: ScopeRouteSubtree<ScopeKey, RouteId>(
            children: node.children,
          ),
        ),
      );
    }

    for (final child in node.children) {
      visit(child, prefixSegments: fullSegments);
    }
  }

  visit(root, prefixSegments: const <String>[]);
  return entries;
}

List<LocationV2<ScopeKey, RouteId>> _prioritize<ScopeKey, RouteId>(
  List<LocationV2<ScopeKey, RouteId>> children,
) {
  final indexed = children.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final aScore = _scorePattern(a.$2.pathSegments);
    final bScore = _scorePattern(b.$2.pathSegments);
    final staticCompare = bScore.staticSegments.compareTo(
      aScore.staticSegments,
    );
    if (staticCompare != 0) {
      return staticCompare;
    }
    final lengthCompare = bScore.totalSegments.compareTo(aScore.totalSegments);
    if (lengthCompare != 0) {
      return lengthCompare;
    }
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

_PatternPrefixMatch? _matchPatternPrefix({
  required List<String> patternSegments,
  required List<String> targetSegments,
}) {
  if (targetSegments.length < patternSegments.length) {
    return null;
  }

  final pathParameters = <String, String>{};
  var staticSegments = 0;
  for (var index = 0; index < patternSegments.length; index++) {
    final pattern = patternSegments[index];
    final target = targetSegments[index];
    if (pattern.startsWith(':')) {
      pathParameters[pattern.substring(1)] = target;
      continue;
    }
    if (pattern != target) {
      return null;
    }
    staticSegments += 1;
  }

  return _PatternPrefixMatch(
    consumedSegments: patternSegments.length,
    pathParameters: pathParameters,
    score: _PrefixPatternMatch(
      staticSegments: staticSegments,
      totalSegments: patternSegments.length,
    ),
  );
}

_PrefixPatternMatch _scorePattern(List<String> segments) {
  return _PrefixPatternMatch(
    staticSegments: segments
        .where((segment) => !segment.startsWith(':'))
        .length,
    totalSegments: segments.length,
  );
}

bool _isBetterPatternMatch(
  _PrefixPatternMatch candidate,
  _PrefixPatternMatch? currentBest,
) {
  if (currentBest == null) {
    return true;
  }
  if (candidate.staticSegments != currentBest.staticSegments) {
    return candidate.staticSegments > currentBest.staticSegments;
  }
  return candidate.totalSegments > currentBest.totalSegments;
}

bool _isBetterBoundaryPrefixMatch<ScopeKey, RouteId>(
  _ScopeBoundaryPrefixMatch<ScopeKey, RouteId> candidate,
  _ScopeBoundaryPrefixMatch<ScopeKey, RouteId>? currentBest,
) {
  if (currentBest == null) {
    return true;
  }

  if (candidate.consumedSegments != currentBest.consumedSegments) {
    return candidate.consumedSegments > currentBest.consumedSegments;
  }
  if (candidate.score.staticSegments != currentBest.score.staticSegments) {
    return candidate.score.staticSegments > currentBest.score.staticSegments;
  }
  return candidate.score.totalSegments > currentBest.score.totalSegments;
}
