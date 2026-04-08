import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'location_id.dart';
import 'locations/a_location.dart';
import 'locations/ab_location.dart';
import 'locations/abc_location.dart';
import 'locations/ad_location.dart';
import 'locations/adc_location.dart';
import 'locations/splash_location.dart';

part 'app_routes.g.dart';

@RouteNodes()
List<RouteNode<LocationId>> buildRouteNodes({
  required GlobalKey<NavigatorState> rootNavigatorKey,
  required GlobalKey<NavigatorState> alphabetNavigatorKey,
}) =>
    [
      SplashLocation(
        id: LocationId.splash,
        rootNavigatorKey: rootNavigatorKey,
        alphabetNavigatorKey: alphabetNavigatorKey,
      ),
    ];
