import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _workingRouterStateKey = 'workingRouter';
const _hiddenPathSegmentsStateKey = 'hiddenPathSegments';
const _hiddenQueryParametersStateKey = 'hiddenQueryParameters';

/// Complete browser route configuration used by [WorkingRouter].
///
/// [uri] is the visible address-bar URI reported to Flutter and the browser.
/// Hidden path segments and query parameters are serialized into
/// [RouteInformation.state] so browser back/forward can restore them without
/// exposing them in the URL. [matchingUri] merges both parts back into the
/// internal URI used for route matching.
class WorkingRouteConfiguration {
  /// Browser-visible URI. Hidden route state is intentionally omitted here.
  final Uri uri;

  /// Path segments omitted from [uri] because their route nodes use
  /// `UriVisibility.hidden`.
  final IList<String> hiddenPathSegments;

  /// Query parameters omitted from [uri] because their declarations use
  /// `UriVisibility.hidden`.
  final IMap<String, String> hiddenQueryParameters;

  const WorkingRouteConfiguration({
    required this.uri,
    required this.hiddenPathSegments,
    required this.hiddenQueryParameters,
  });

  factory WorkingRouteConfiguration.fromRouteInformation(
    RouteInformation routeInformation,
  ) {
    final state = routeInformation.state;
    if (state is! Map<Object?, Object?>) {
      return WorkingRouteConfiguration(
        uri: routeInformation.uri,
        hiddenPathSegments: const IListConst([]),
        hiddenQueryParameters: const IMapConst({}),
      );
    }

    final routerState = state[_workingRouterStateKey];
    if (routerState is! Map<Object?, Object?>) {
      return WorkingRouteConfiguration(
        uri: routeInformation.uri,
        hiddenPathSegments: const IListConst([]),
        hiddenQueryParameters: const IMapConst({}),
      );
    }

    return WorkingRouteConfiguration(
      uri: routeInformation.uri,
      hiddenPathSegments: _readHiddenPathSegments(routerState),
      hiddenQueryParameters: _readHiddenQueryParameters(routerState),
    );
  }

  /// Internal URI used for route matching.
  ///
  /// This appends [hiddenPathSegments] to [uri.pathSegments] and merges
  /// [hiddenQueryParameters] with [uri.queryParameters]. Visible query
  /// parameters win if the same key appears in both places.
  Uri get matchingUri {
    final queryParameters = {
      ...hiddenQueryParameters.unlock,
      ...uri.queryParameters,
    };
    final pathSegments = [...uri.pathSegments, ...hiddenPathSegments];
    final path = pathSegments.isEmpty
        ? uri.path
        : '${uri.path.startsWith('/') ? '/' : ''}${pathSegments.join('/')}';
    return uri.replace(
      path: path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  RouteInformation toRouteInformation() {
    return RouteInformation(
      uri: uri,
      state: _state,
    );
  }

  Object? get _state {
    final routerState = <String, Object>{};
    if (hiddenPathSegments.isNotEmpty) {
      routerState[_hiddenPathSegmentsStateKey] = hiddenPathSegments.unlock;
    }
    if (hiddenQueryParameters.isNotEmpty) {
      routerState[_hiddenQueryParametersStateKey] =
          hiddenQueryParameters.unlock;
    }
    if (routerState.isEmpty) {
      return null;
    }
    return {_workingRouterStateKey: routerState};
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkingRouteConfiguration &&
            uri == other.uri &&
            hiddenPathSegments == other.hiddenPathSegments &&
            hiddenQueryParameters == other.hiddenQueryParameters;
  }

  @override
  int get hashCode =>
      uri.hashCode ^
      hiddenPathSegments.hashCode ^
      hiddenQueryParameters.hashCode;
}

IList<String> _readHiddenPathSegments(Map<Object?, Object?> routerState) {
  final value = routerState[_hiddenPathSegmentsStateKey];
  if (value is! List<Object?>) {
    return const IListConst([]);
  }
  return value.whereType<String>().toIList();
}

IMap<String, String> _readHiddenQueryParameters(
  Map<Object?, Object?> routerState,
) {
  final value = routerState[_hiddenQueryParametersStateKey];
  if (value is! Map<Object?, Object?>) {
    return const IMapConst({});
  }
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key! as String: entry.value! as String,
  }.toIMap();
}

class WorkingRouteInformationProvider extends PlatformRouteInformationProvider {
  final bool Function() consumeReplaceBrowserHistory;

  @visibleForTesting
  final List<RouteInformationReportingType> debugReportedTypes = [];

  WorkingRouteInformationProvider({
    required super.initialRouteInformation,
    required this.consumeReplaceBrowserHistory,
  });

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    final effectiveType = consumeReplaceBrowserHistory()
        ? RouteInformationReportingType.neglect
        : type;
    debugReportedTypes.add(effectiveType);
    super.routerReportsNewRouteInformation(
      routeInformation,
      type: effectiveType,
    );
  }
}

class WorkingRouteInformationParser
    extends RouteInformationParser<WorkingRouteConfiguration> {
  @override
  Future<WorkingRouteConfiguration> parseRouteInformation(
    RouteInformation routeInformation,
  ) {
    return SynchronousFuture(
      WorkingRouteConfiguration.fromRouteInformation(routeInformation),
    );
  }

  @override
  RouteInformation? restoreRouteInformation(
    WorkingRouteConfiguration configuration,
  ) {
    return configuration.toRouteInformation();
  }
}
