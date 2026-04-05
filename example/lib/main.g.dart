// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// RouteHelpersGenerator
// **************************************************************************

extension BuildLocationTreeGeneratedRoutes on WorkingRouterSailor<LocationId> {
  void routeToSplash() {
    routeToId(
      LocationId.splash,
    );
  }

  void routeToA() {
    routeToId(
      LocationId.a,
    );
  }

  void routeToChildA() {
    routeToChild<ALocation>();
  }

  void routeToAb() {
    routeToId(
      LocationId.ab,
    );
  }

  void routeToChildAb() {
    routeToChild<ABLocation>();
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

  void routeToChildAbc({
    required String id,
  }) {
    routeToChild<ABCLocation>(
      pathParameters: {
        'id': StringRouteParamCodec().encode(id),
      },
    );
  }

  void routeToAd() {
    routeToId(
      LocationId.ad,
    );
  }

  void routeToChildAd() {
    routeToChild<ADLocation>();
  }

  void routeToAdc() {
    routeToId(
      LocationId.adc,
    );
  }

  void routeToChildAdc() {
    routeToChild<ADCLocation>();
  }
}
