// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// RouteHelpersGenerator
// **************************************************************************

final class SplashRouteTarget extends IdRouteTarget<LocationId> {
  const SplashRouteTarget()
      : super(
          LocationId.splash,
        );
}

final class ARouteTarget extends IdRouteTarget<LocationId> {
  const ARouteTarget()
      : super(
          LocationId.a,
        );
}

final class ChildARouteTarget extends ChildRouteTarget<LocationId> {
  ChildARouteTarget()
      : super(
          (location) => location is ALocation,
        );
}

final class AbRouteTarget extends IdRouteTarget<LocationId> {
  const AbRouteTarget()
      : super(
          LocationId.ab,
        );
}

final class ChildAbRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAbRouteTarget()
      : super(
          (location) => location is ABLocation,
        );
}

final class AbcRouteTarget extends IdRouteTarget<LocationId> {
  AbcRouteTarget({
    required String id,
    required String b,
    required String c,
  }) : super(
          LocationId.abc,
          writePathParameters: (() {
            var abclocationMatchIndex = 0;
            return (location, path) {
              if (location is ABCLocation) {
                switch (abclocationMatchIndex++) {
                  case 0:
                    path(location.idParam, id);
                    break;
                }
              }
            };
          })(),
          queryParameters: {
            'b': const StringRouteParamCodec().encode(b),
            'c': const StringRouteParamCodec().encode(c),
          },
        );
}

final class ChildAbcRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAbcRouteTarget({
    required String id,
    required String b,
    required String c,
  }) : super(
          (location) => location is ABCLocation,
          writePathParameters: (() {
            var abclocationMatchIndex = 0;
            return (location, path) {
              if (location is ABCLocation) {
                switch (abclocationMatchIndex++) {
                  case 0:
                    path(location.idParam, id);
                    break;
                }
              }
            };
          })(),
          queryParameters: {
            'b': const StringRouteParamCodec().encode(b),
            'c': const StringRouteParamCodec().encode(c),
          },
        );
}

final class AdRouteTarget extends IdRouteTarget<LocationId> {
  const AdRouteTarget()
      : super(
          LocationId.ad,
        );
}

final class ChildAdRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdRouteTarget()
      : super(
          (location) => location is ADLocation,
        );
}

final class AdcRouteTarget extends IdRouteTarget<LocationId> {
  const AdcRouteTarget()
      : super(
          LocationId.adc,
        );
}

final class ChildAdcRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdcRouteTarget()
      : super(
          (location) => location is ADCLocation,
        );
}

extension BuildRouteNodesGeneratedRoutes on WorkingRouterSailor<LocationId> {
  void routeToSplash() {
    routeTo(SplashRouteTarget());
  }

  void routeToA() {
    routeTo(ARouteTarget());
  }

  void routeToChildA() {
    routeTo(ChildARouteTarget());
  }

  void routeToAb() {
    routeTo(AbRouteTarget());
  }

  void routeToChildAb() {
    routeTo(ChildAbRouteTarget());
  }

  void routeToAbc({
    required String id,
    required String b,
    required String c,
  }) {
    routeTo(
      AbcRouteTarget(
        id: id,
        b: b,
        c: c,
      ),
    );
  }

  void routeToChildAbc({
    required String id,
    required String b,
    required String c,
  }) {
    routeTo(
      ChildAbcRouteTarget(
        id: id,
        b: b,
        c: c,
      ),
    );
  }

  void routeToAd() {
    routeTo(AdRouteTarget());
  }

  void routeToChildAd() {
    routeTo(ChildAdRouteTarget());
  }

  void routeToAdc() {
    routeTo(AdcRouteTarget());
  }

  void routeToChildAdc() {
    routeTo(ChildAdcRouteTarget());
  }
}
