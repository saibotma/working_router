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
                    path(location.pathParameters[0] as PathParam<String>, id);
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
                    path(location.pathParameters[0] as PathParam<String>, id);
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

final class AdShellRouteTarget extends IdRouteTarget<LocationId> {
  const AdShellRouteTarget()
      : super(
          LocationId.adShell,
        );
}

final class ChildAdshellRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdshellRouteTarget()
      : super(
          (location) => location is ADShellLocation,
        );
}

final class AdeRouteTarget extends IdRouteTarget<LocationId> {
  const AdeRouteTarget()
      : super(
          LocationId.ade,
        );
}

final class ChildAdeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdeRouteTarget()
      : super(
          (location) => location is ADELocation,
        );
}

extension BuildLocationsGeneratedRoutes on WorkingRouterSailor<LocationId> {
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

  void routeToAdShell() {
    routeTo(AdShellRouteTarget());
  }

  void routeToChildAdshell() {
    routeTo(ChildAdshellRouteTarget());
  }

  void routeToAde() {
    routeTo(AdeRouteTarget());
  }

  void routeToChildAde() {
    routeTo(ChildAdeRouteTarget());
  }
}

extension SplashLocationGeneratedChildTargets on SplashLocation {
  ChildRouteTarget<LocationId> childATarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ALocation,
    );
  }

  ChildRouteTarget<LocationId> childAbTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABLocation,
    );
  }

  ChildRouteTarget<LocationId> childAbcTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABCLocation,
      writePathParameters: (() {
        var abclocationMatchIndex = 0;
        return (location, path) {
          if (location is ABCLocation) {
            switch (abclocationMatchIndex++) {
              case 0:
                path(location.pathParameters[0] as PathParam<String>, id);
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

  ChildRouteTarget<LocationId> childAdTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdcTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADCLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdshellTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADShellLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADELocation,
    );
  }
}

extension ALocationGeneratedChildTargets on ALocation {
  ChildRouteTarget<LocationId> childAbTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABLocation,
    );
  }

  ChildRouteTarget<LocationId> childAbcTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABCLocation,
      writePathParameters: (() {
        var abclocationMatchIndex = 0;
        return (location, path) {
          if (location is ABCLocation) {
            switch (abclocationMatchIndex++) {
              case 0:
                path(location.pathParameters[0] as PathParam<String>, id);
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

  ChildRouteTarget<LocationId> childAdTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdcTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADCLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdshellTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADShellLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADELocation,
    );
  }
}

extension ABLocationGeneratedChildTargets on ABLocation {
  ChildRouteTarget<LocationId> childAbcTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABCLocation,
      writePathParameters: (() {
        var abclocationMatchIndex = 0;
        return (location, path) {
          if (location is ABCLocation) {
            switch (abclocationMatchIndex++) {
              case 0:
                path(location.pathParameters[0] as PathParam<String>, id);
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
}

extension ADLocationGeneratedChildTargets on ADLocation {
  ChildRouteTarget<LocationId> childAdcTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADCLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdshellTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADShellLocation,
    );
  }

  ChildRouteTarget<LocationId> childAdeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADELocation,
    );
  }
}

extension ADShellLocationGeneratedChildTargets on ADShellLocation {
  ChildRouteTarget<LocationId> childAdeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADELocation,
    );
  }
}
