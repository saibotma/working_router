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

final class ChildAnodeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAnodeRouteTarget()
      : super(
          (location) => location is ANode,
        );
}

final class AbRouteTarget extends IdRouteTarget<LocationId> {
  const AbRouteTarget()
      : super(
          LocationId.ab,
        );
}

final class ChildAbnodeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAbnodeRouteTarget()
      : super(
          (location) => location is ABNode,
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
            var abcnodeMatchIndex = 0;
            return (location, path) {
              if (location is ABCNode) {
                switch (abcnodeMatchIndex++) {
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

final class ChildAbcnodeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAbcnodeRouteTarget({
    required String id,
    required String b,
    required String c,
  }) : super(
          (location) => location is ABCNode,
          writePathParameters: (() {
            var abcnodeMatchIndex = 0;
            return (location, path) {
              if (location is ABCNode) {
                switch (abcnodeMatchIndex++) {
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

final class ChildAdnodeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdnodeRouteTarget()
      : super(
          (location) => location is ADNode,
        );
}

final class AdcRouteTarget extends IdRouteTarget<LocationId> {
  const AdcRouteTarget()
      : super(
          LocationId.adc,
        );
}

final class ChildAdcnodeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdcnodeRouteTarget()
      : super(
          (location) => location is ADCNode,
        );
}

final class AdShellRouteTarget extends IdRouteTarget<LocationId> {
  const AdShellRouteTarget()
      : super(
          LocationId.adShell,
        );
}

final class ChildAdnestedNodeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdnestedNodeRouteTarget()
      : super(
          (location) => location is ADNestedNode,
        );
}

final class AdeRouteTarget extends IdRouteTarget<LocationId> {
  const AdeRouteTarget()
      : super(
          LocationId.ade,
        );
}

final class ChildAdenodeRouteTarget extends ChildRouteTarget<LocationId> {
  ChildAdenodeRouteTarget()
      : super(
          (location) => location is ADENode,
        );
}

extension BuildLocationsGeneratedRoutes on WorkingRouterSailor<LocationId> {
  void routeToSplash() {
    routeTo(SplashRouteTarget());
  }

  void routeToA() {
    routeTo(ARouteTarget());
  }

  void routeToChildAnode() {
    routeTo(ChildAnodeRouteTarget());
  }

  void routeToAb() {
    routeTo(AbRouteTarget());
  }

  void routeToChildAbnode() {
    routeTo(ChildAbnodeRouteTarget());
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

  void routeToChildAbcnode({
    required String id,
    required String b,
    required String c,
  }) {
    routeTo(
      ChildAbcnodeRouteTarget(
        id: id,
        b: b,
        c: c,
      ),
    );
  }

  void routeToAd() {
    routeTo(AdRouteTarget());
  }

  void routeToChildAdnode() {
    routeTo(ChildAdnodeRouteTarget());
  }

  void routeToAdc() {
    routeTo(AdcRouteTarget());
  }

  void routeToChildAdcnode() {
    routeTo(ChildAdcnodeRouteTarget());
  }

  void routeToAdShell() {
    routeTo(AdShellRouteTarget());
  }

  void routeToChildAdnestedNode() {
    routeTo(ChildAdnestedNodeRouteTarget());
  }

  void routeToAde() {
    routeTo(AdeRouteTarget());
  }

  void routeToChildAdenode() {
    routeTo(ChildAdenodeRouteTarget());
  }
}

extension SplashNodeGeneratedChildTargets on SplashNode {
  ChildRouteTarget<LocationId> childAnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ANode,
    );
  }

  ChildRouteTarget<LocationId> childAbnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABNode,
    );
  }

  ChildRouteTarget<LocationId> childAbcnodeTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABCNode,
      writePathParameters: (() {
        var abcnodeMatchIndex = 0;
        return (location, path) {
          if (location is ABCNode) {
            switch (abcnodeMatchIndex++) {
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

  ChildRouteTarget<LocationId> childAdnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADNode,
    );
  }

  ChildRouteTarget<LocationId> childAdcnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADCNode,
    );
  }

  ChildRouteTarget<LocationId> childAdnestedNodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADNestedNode,
    );
  }

  ChildRouteTarget<LocationId> childAdenodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADENode,
    );
  }
}

extension ANodeGeneratedChildTargets on ANode {
  ChildRouteTarget<LocationId> childAbnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABNode,
    );
  }

  ChildRouteTarget<LocationId> childAbcnodeTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABCNode,
      writePathParameters: (() {
        var abcnodeMatchIndex = 0;
        return (location, path) {
          if (location is ABCNode) {
            switch (abcnodeMatchIndex++) {
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

  ChildRouteTarget<LocationId> childAdnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADNode,
    );
  }

  ChildRouteTarget<LocationId> childAdcnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADCNode,
    );
  }

  ChildRouteTarget<LocationId> childAdnestedNodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADNestedNode,
    );
  }

  ChildRouteTarget<LocationId> childAdenodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADENode,
    );
  }
}

extension ABNodeGeneratedChildTargets on ABNode {
  ChildRouteTarget<LocationId> childAbcnodeTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<LocationId>(
      (location) => location is ABCNode,
      writePathParameters: (() {
        var abcnodeMatchIndex = 0;
        return (location, path) {
          if (location is ABCNode) {
            switch (abcnodeMatchIndex++) {
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

extension ADNodeGeneratedChildTargets on ADNode {
  ChildRouteTarget<LocationId> childAdcnodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADCNode,
    );
  }

  ChildRouteTarget<LocationId> childAdnestedNodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADNestedNode,
    );
  }

  ChildRouteTarget<LocationId> childAdenodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADENode,
    );
  }
}

extension ADNestedNodeGeneratedChildTargets on ADNestedNode {
  ChildRouteTarget<LocationId> childAdenodeTarget() {
    return ChildRouteTarget<LocationId>(
      (location) => location is ADENode,
    );
  }
}
