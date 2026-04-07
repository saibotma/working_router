// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// RouteHelpersGenerator
// **************************************************************************

extension BuildRouteNodeTreeGeneratedRoutes on WorkingRouterSailor<LocationId> {
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
    required String idParameter,
  }) {
    var abclocationMatchIndex = 0;
    routeToId(
      LocationId.abc,
      writePathParameters: (location, path) {
        if (location is ABCLocation) {
          switch (abclocationMatchIndex++) {
            case 0:
              path(location.idParameter, idParameter);
              break;
          }
        }
      },
    );
  }

  void routeToChildAbc({
    required String idParameter,
  }) {
    var abclocationMatchIndex = 0;
    routeToChild<ABCLocation>(
      writePathParameters: (location, path) {
        if (location is ABCLocation) {
          switch (abclocationMatchIndex++) {
            case 0:
              path(location.idParameter, idParameter);
              break;
          }
        }
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
