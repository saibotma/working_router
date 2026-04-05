// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// RouteHelpersGenerator
// **************************************************************************

extension BuildLocationTreeGeneratedRoutes on WorkingRouterSailor<LocationId> {
  void routeToSplash() {
    routeToId(LocationId.splash);
  }

  void routeToA() {
    routeToId(LocationId.a);
  }

  void routeToAb() {
    routeToId(LocationId.ab);
  }

  void routeToAbc({
    required String id,
  }) {
    routeToId(
      LocationId.abc,
      pathParameters: {
        'id': StringRouteParamCodec().encode(id),
      },
    );
  }

  void routeToAd() {
    routeToId(LocationId.ad);
  }

  void routeToAdc() {
    routeToId(LocationId.adc);
  }
}
