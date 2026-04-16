// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_nodes.dart';

// **************************************************************************
// RouteHelpersGenerator
// **************************************************************************

final class SplashRouteTarget extends IdRouteTarget<RouteNodeId> {
  const SplashRouteTarget()
      : super(
          RouteNodeId.splash,
        );
}

final class ARouteTarget extends IdRouteTarget<RouteNodeId> {
  const ARouteTarget()
      : super(
          RouteNodeId.a,
        );
}

final class ChildAnodeRouteTarget extends ChildRouteTarget<RouteNodeId> {
  ChildAnodeRouteTarget()
      : super(
          (location) => location is ANode,
        );
}

final class AbRouteTarget extends IdRouteTarget<RouteNodeId> {
  const AbRouteTarget()
      : super(
          RouteNodeId.ab,
        );
}

final class ChildAbnodeRouteTarget extends ChildRouteTarget<RouteNodeId> {
  ChildAbnodeRouteTarget()
      : super(
          (location) => location is ABNode,
        );
}

final class AbcRouteTarget extends IdRouteTarget<RouteNodeId> {
  AbcRouteTarget({
    required String id,
    required String b,
    required String c,
  }) : super(
          RouteNodeId.abc,
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

final class ChildAbcnodeRouteTarget extends ChildRouteTarget<RouteNodeId> {
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

final class AdRouteTarget extends IdRouteTarget<RouteNodeId> {
  const AdRouteTarget()
      : super(
          RouteNodeId.ad,
        );
}

final class ChildAdnodeRouteTarget extends ChildRouteTarget<RouteNodeId> {
  ChildAdnodeRouteTarget()
      : super(
          (location) => location is ADNode,
        );
}

final class AdcRouteTarget extends IdRouteTarget<RouteNodeId> {
  const AdcRouteTarget()
      : super(
          RouteNodeId.adc,
        );
}

final class ChildAdcnodeRouteTarget extends ChildRouteTarget<RouteNodeId> {
  ChildAdcnodeRouteTarget()
      : super(
          (location) => location is ADCNode,
        );
}

final class AdShellRouteTarget extends IdRouteTarget<RouteNodeId> {
  const AdShellRouteTarget()
      : super(
          RouteNodeId.adShell,
        );
}

final class ChildAdnestedNodeRouteTarget extends ChildRouteTarget<RouteNodeId> {
  ChildAdnestedNodeRouteTarget()
      : super(
          (location) => location is ADNestedNode,
        );
}

final class AdeRouteTarget extends IdRouteTarget<RouteNodeId> {
  const AdeRouteTarget()
      : super(
          RouteNodeId.ade,
        );
}

final class ChildAdenodeRouteTarget extends ChildRouteTarget<RouteNodeId> {
  ChildAdenodeRouteTarget()
      : super(
          (location) => location is ADENode,
        );
}

extension BuildRouteNodesGeneratedRoutes on WorkingRouterSailor<RouteNodeId> {
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
  ChildRouteTarget<RouteNodeId> childAnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ANode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAbnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ABNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAbcnodeTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<RouteNodeId>(
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

  ChildRouteTarget<RouteNodeId> childAdnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdcnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADCNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdnestedNodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADNestedNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdenodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADENode,
    );
  }
}

extension ANodeGeneratedChildTargets on ANode {
  ChildRouteTarget<RouteNodeId> childAbnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ABNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAbcnodeTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<RouteNodeId>(
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

  ChildRouteTarget<RouteNodeId> childAdnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdcnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADCNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdnestedNodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADNestedNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdenodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADENode,
    );
  }
}

extension ABNodeGeneratedChildTargets on ABNode {
  ChildRouteTarget<RouteNodeId> childAbcnodeTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget<RouteNodeId>(
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
  ChildRouteTarget<RouteNodeId> childAdcnodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADCNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdnestedNodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADNestedNode,
    );
  }

  ChildRouteTarget<RouteNodeId> childAdenodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADENode,
    );
  }
}

extension ADNestedNodeGeneratedChildTargets on ADNestedNode {
  ChildRouteTarget<RouteNodeId> childAdenodeTarget() {
    return ChildRouteTarget<RouteNodeId>(
      (location) => location is ADENode,
    );
  }
}
