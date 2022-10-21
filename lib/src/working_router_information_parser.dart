import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MyRouteInformationParser extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) {
    return SynchronousFuture(Uri.parse(routeInformation.location!));
  }

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) {
    String uriString = configuration.toString();
    // Required, because Uri does not add a leading slash when
    // creating Uri from path segments.
    if (!uriString.startsWith("/")) {
      uriString = "/$uriString";
    }
    return RouteInformation(location: uriString);
  }
}
