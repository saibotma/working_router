// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_nodes.dart';

// **************************************************************************
// RouteHelpersGenerator
// **************************************************************************

// ignore_for_file: type=lint

final class SplashRouteTarget extends IdRouteTarget {
  SplashRouteTarget()
      : super(
          splashId,
        );
}

final class ARouteTarget extends IdRouteTarget {
  ARouteTarget()
      : super(
          aId,
        );
}

final class AbRouteTarget extends IdRouteTarget {
  AbRouteTarget()
      : super(
          abId,
        );
}

final class AbcRouteTarget extends IdRouteTarget {
  AbcRouteTarget({
    required String id,
    required String b,
    required String c,
  }) : super(
          abcId,
          writePathParameters: (() {
            var abcIdMatchIndex = 0;
            return (location, path) {
              if (location.id == abcId) {
                switch (abcIdMatchIndex++) {
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

final class AdRouteTarget extends IdRouteTarget {
  AdRouteTarget()
      : super(
          adId,
        );
}

final class AdcRouteTarget extends IdRouteTarget {
  AdcRouteTarget()
      : super(
          adcId,
        );
}

final class AdShellRouteTarget extends IdRouteTarget {
  AdShellRouteTarget()
      : super(
          adShellId,
        );
}

final class AdeRouteTarget extends IdRouteTarget {
  AdeRouteTarget()
      : super(
          adeId,
        );
}

extension BuildRouteNodesGeneratedRoutes on WorkingRouterSailor {
  void routeToSplash() {
    routeTo(SplashRouteTarget());
  }

  void routeToA() {
    routeTo(ARouteTarget());
  }

  void routeToAb() {
    routeTo(AbRouteTarget());
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

  void routeToAd() {
    routeTo(AdRouteTarget());
  }

  void routeToAdc() {
    routeTo(AdcRouteTarget());
  }

  void routeToAdShell() {
    routeTo(AdShellRouteTarget());
  }

  void routeToAde() {
    routeTo(AdeRouteTarget());
  }
}

extension ABNodeGeneratedChildTargets on ABNode {
  ChildRouteTarget childAbcTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == abcId,
        ]);
      },
      writePathParameters: (() {
        var abcIdMatchIndex = 0;
        return (location, path) {
          if (location.id == abcId) {
            switch (abcIdMatchIndex++) {
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

  void routeToChildAbc(
    BuildContext context, {
    required String id,
    required String b,
    required String c,
  }) {
    WorkingRouter.of(context).routeTo(
      childAbcTarget(
        id: id,
        b: b,
        c: c,
      ),
    );
  }
}

extension ADNestedNodeGeneratedChildTargets on ADNestedNode {
  ChildRouteTarget get childAdeTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}

extension ADNodeGeneratedChildTargets on ADNode {
  ChildRouteTarget get childAdcTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adcId,
        ]);
      },
    );
  }

  void routeToChildAdc(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdcTarget);
  }

  ChildRouteTarget get childAdnestedTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adShellId,
        ]);
      },
    );
  }

  void routeToChildAdnested(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdnestedTarget);
  }

  ChildRouteTarget get childAdeTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adShellId,
          (node) => node.id == adeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}

extension ANodeGeneratedChildTargets on ANode {
  ChildRouteTarget get childAbTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == abId,
        ]);
      },
    );
  }

  void routeToChildAb(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAbTarget);
  }

  ChildRouteTarget childAbcTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == abId,
          (node) => node.id == abcId,
        ]);
      },
      writePathParameters: (() {
        var abcIdMatchIndex = 0;
        return (location, path) {
          if (location.id == abcId) {
            switch (abcIdMatchIndex++) {
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

  void routeToChildAbc(
    BuildContext context, {
    required String id,
    required String b,
    required String c,
  }) {
    WorkingRouter.of(context).routeTo(
      childAbcTarget(
        id: id,
        b: b,
        c: c,
      ),
    );
  }

  ChildRouteTarget get childAdTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adId,
        ]);
      },
    );
  }

  void routeToChildAd(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdTarget);
  }

  ChildRouteTarget get childAdcTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adId,
          (node) => node.id == adcId,
        ]);
      },
    );
  }

  void routeToChildAdc(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdcTarget);
  }

  ChildRouteTarget get childAdnestedTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adId,
          (node) => node.id == adShellId,
        ]);
      },
    );
  }

  void routeToChildAdnested(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdnestedTarget);
  }

  ChildRouteTarget get childAdeTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adId,
          (node) => node.id == adShellId,
          (node) => node.id == adeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}

extension SplashNodeGeneratedChildTargets on SplashNode {
  ChildRouteTarget get childATarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aId,
        ]);
      },
    );
  }

  void routeToChildA(BuildContext context) {
    WorkingRouter.of(context).routeTo(childATarget);
  }

  ChildRouteTarget get childAbTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aId,
          (node) => node.id == abId,
        ]);
      },
    );
  }

  void routeToChildAb(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAbTarget);
  }

  ChildRouteTarget childAbcTarget({
    required String id,
    required String b,
    required String c,
  }) {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aId,
          (node) => node.id == abId,
          (node) => node.id == abcId,
        ]);
      },
      writePathParameters: (() {
        var abcIdMatchIndex = 0;
        return (location, path) {
          if (location.id == abcId) {
            switch (abcIdMatchIndex++) {
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

  void routeToChildAbc(
    BuildContext context, {
    required String id,
    required String b,
    required String c,
  }) {
    WorkingRouter.of(context).routeTo(
      childAbcTarget(
        id: id,
        b: b,
        c: c,
      ),
    );
  }

  ChildRouteTarget get childAdTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aId,
          (node) => node.id == adId,
        ]);
      },
    );
  }

  void routeToChildAd(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdTarget);
  }

  ChildRouteTarget get childAdcTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aId,
          (node) => node.id == adId,
          (node) => node.id == adcId,
        ]);
      },
    );
  }

  void routeToChildAdc(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdcTarget);
  }

  ChildRouteTarget get childAdnestedTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aId,
          (node) => node.id == adId,
          (node) => node.id == adShellId,
        ]);
      },
    );
  }

  void routeToChildAdnested(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdnestedTarget);
  }

  ChildRouteTarget get childAdeTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aId,
          (node) => node.id == adId,
          (node) => node.id == adShellId,
          (node) => node.id == adeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}
