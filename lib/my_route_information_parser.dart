import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyRouteInformationParser extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) {
    return SynchronousFuture(Uri.parse(routeInformation.location!));
  }

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) {
    return RouteInformation(location: configuration.toString());
  }
}
