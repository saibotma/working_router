import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

class WorkingRouteInformationParser extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(
    RouteInformation routeInformation,
  ) {
    return SynchronousFuture(routeInformation.uri);
  }

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) {
    return RouteInformation(uri: configuration);
  }
}
