// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_nodes.dart';

// **************************************************************************
// RouteHelpersGenerator
// **************************************************************************

// ignore_for_file: type=lint

final class SplashRouteTarget extends IdRouteTarget {
  SplashRouteTarget()
      : super(
          splashRouteNodeId,
        );
}

final class ARouteTarget extends IdRouteTarget {
  ARouteTarget()
      : super(
          aRouteNodeId,
        );
}

final class AbRouteTarget extends IdRouteTarget {
  AbRouteTarget()
      : super(
          abRouteNodeId,
        );
}

final class AbcRouteTarget extends IdRouteTarget {
  AbcRouteTarget({
    required String id,
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
  }) : super(
          abcRouteNodeId,
          writePathParameters: (nodes, path) {
            var abcRouteNodeIdMatchIndex = 0;
            for (final node in nodes) {
              if (node.id == abcRouteNodeId) {
                switch (abcRouteNodeIdMatchIndex++) {
                  case 0:
                    path(node, node.pathParameters[0] as PathParam<String>, id);
                    break;
                }
              }
            }
          },
          writeQueryParameters: (nodes, query) {
            var abcRouteNodeIdMatchIndex = 0;
            for (final node in nodes) {
              if (node.id == abcRouteNodeId) {
                switch (abcRouteNodeIdMatchIndex++) {
                  case 0:
                    switch (b) {
                      case SetQueryParamValue(:final value):
                        query(
                            node,
                            node.queryParameters
                                    .firstWhere((it) => it.name == 'b')
                                as QueryParam<String>,
                            value);
                    }
                    switch (c) {
                      case SetQueryParamValue(:final value):
                        query(
                            node,
                            node.queryParameters
                                    .firstWhere((it) => it.name == 'c')
                                as QueryParam<String>,
                            value);
                    }
                    break;
                }
              }
            }
          },
        );
}

final class AdRouteTarget extends IdRouteTarget {
  AdRouteTarget()
      : super(
          adRouteNodeId,
        );
}

final class AdcRouteTarget extends IdRouteTarget {
  AdcRouteTarget()
      : super(
          adcRouteNodeId,
        );
}

final class AdShellRouteTarget extends IdRouteTarget {
  AdShellRouteTarget()
      : super(
          adShellRouteNodeId,
        );
}

final class AdeRouteTarget extends IdRouteTarget {
  AdeRouteTarget()
      : super(
          adeRouteNodeId,
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
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
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

extension ABRouteNodeGeneratedChildTargets on ABRouteNode {
  ChildRouteTarget childAbcTarget({
    required String id,
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
  }) {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == abcRouteNodeId,
        ]);
      },
      writePathParameters: (nodes, path) {
        var abcRouteNodeIdMatchIndex = 0;
        for (final node in nodes) {
          if (node.id == abcRouteNodeId) {
            switch (abcRouteNodeIdMatchIndex++) {
              case 0:
                path(node, node.pathParameters[0] as PathParam<String>, id);
                break;
            }
          }
        }
      },
      writeQueryParameters: (nodes, query) {
        var abcRouteNodeIdMatchIndex = 0;
        for (final node in nodes) {
          if (node.id == abcRouteNodeId) {
            switch (abcRouteNodeIdMatchIndex++) {
              case 0:
                switch (b) {
                  case SetQueryParamValue(:final value):
                    query(
                        node,
                        node.queryParameters.firstWhere((it) => it.name == 'b')
                            as QueryParam<String>,
                        value);
                }
                switch (c) {
                  case SetQueryParamValue(:final value):
                    query(
                        node,
                        node.queryParameters.firstWhere((it) => it.name == 'c')
                            as QueryParam<String>,
                        value);
                }
                break;
            }
          }
        }
      },
    );
  }

  void routeToChildAbc(
    BuildContext context, {
    required String id,
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
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

extension ADNestedRouteNodeGeneratedChildTargets on ADNestedRouteNode {
  ChildRouteTarget get childAdeTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adeRouteNodeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}

extension ADRouteNodeGeneratedChildTargets on ADRouteNode {
  ChildRouteTarget get childAdcTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == adcRouteNodeId,
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
          (node) => node.id == adShellRouteNodeId,
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
          (node) => node.id == adShellRouteNodeId,
          (node) => node.id == adeRouteNodeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}

extension ARouteNodeGeneratedChildTargets on ARouteNode {
  ChildRouteTarget get childAbTarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == abRouteNodeId,
        ]);
      },
    );
  }

  void routeToChildAb(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAbTarget);
  }

  ChildRouteTarget childAbcTarget({
    required String id,
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
  }) {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node.id == abRouteNodeId,
          (node) => node.id == abcRouteNodeId,
        ]);
      },
      writePathParameters: (nodes, path) {
        var abcRouteNodeIdMatchIndex = 0;
        for (final node in nodes) {
          if (node.id == abcRouteNodeId) {
            switch (abcRouteNodeIdMatchIndex++) {
              case 0:
                path(node, node.pathParameters[0] as PathParam<String>, id);
                break;
            }
          }
        }
      },
      writeQueryParameters: (nodes, query) {
        var abcRouteNodeIdMatchIndex = 0;
        for (final node in nodes) {
          if (node.id == abcRouteNodeId) {
            switch (abcRouteNodeIdMatchIndex++) {
              case 0:
                switch (b) {
                  case SetQueryParamValue(:final value):
                    query(
                        node,
                        node.queryParameters.firstWhere((it) => it.name == 'b')
                            as QueryParam<String>,
                        value);
                }
                switch (c) {
                  case SetQueryParamValue(:final value):
                    query(
                        node,
                        node.queryParameters.firstWhere((it) => it.name == 'c')
                            as QueryParam<String>,
                        value);
                }
                break;
            }
          }
        }
      },
    );
  }

  void routeToChildAbc(
    BuildContext context, {
    required String id,
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
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
          (node) => node.id == adRouteNodeId,
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
          (node) => node.id == adRouteNodeId,
          (node) => node.id == adcRouteNodeId,
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
          (node) => node.id == adRouteNodeId,
          (node) => node.id == adShellRouteNodeId,
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
          (node) => node.id == adRouteNodeId,
          (node) => node.id == adShellRouteNodeId,
          (node) => node.id == adeRouteNodeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}

extension SplashRouteNodeGeneratedChildTargets on SplashRouteNode {
  ChildRouteTarget get childATarget {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aRouteNodeId,
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
          (node) => node.id == aRouteNodeId,
          (node) => node.id == abRouteNodeId,
        ]);
      },
    );
  }

  void routeToChildAb(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAbTarget);
  }

  ChildRouteTarget childAbcTarget({
    required String id,
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
  }) {
    return ChildRouteTarget(
      start: this,
      resolveChildPathNodes: () {
        return resolveExactChildRouteNodes(this, [
          (node) => node is Shell,
          (node) => node.id == aRouteNodeId,
          (node) => node.id == abRouteNodeId,
          (node) => node.id == abcRouteNodeId,
        ]);
      },
      writePathParameters: (nodes, path) {
        var abcRouteNodeIdMatchIndex = 0;
        for (final node in nodes) {
          if (node.id == abcRouteNodeId) {
            switch (abcRouteNodeIdMatchIndex++) {
              case 0:
                path(node, node.pathParameters[0] as PathParam<String>, id);
                break;
            }
          }
        }
      },
      writeQueryParameters: (nodes, query) {
        var abcRouteNodeIdMatchIndex = 0;
        for (final node in nodes) {
          if (node.id == abcRouteNodeId) {
            switch (abcRouteNodeIdMatchIndex++) {
              case 0:
                switch (b) {
                  case SetQueryParamValue(:final value):
                    query(
                        node,
                        node.queryParameters.firstWhere((it) => it.name == 'b')
                            as QueryParam<String>,
                        value);
                }
                switch (c) {
                  case SetQueryParamValue(:final value):
                    query(
                        node,
                        node.queryParameters.firstWhere((it) => it.name == 'c')
                            as QueryParam<String>,
                        value);
                }
                break;
            }
          }
        }
      },
    );
  }

  void routeToChildAbc(
    BuildContext context, {
    required String id,
    required QueryParamValue<String> b,
    required QueryParamValue<String> c,
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
          (node) => node.id == aRouteNodeId,
          (node) => node.id == adRouteNodeId,
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
          (node) => node.id == aRouteNodeId,
          (node) => node.id == adRouteNodeId,
          (node) => node.id == adcRouteNodeId,
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
          (node) => node.id == aRouteNodeId,
          (node) => node.id == adRouteNodeId,
          (node) => node.id == adShellRouteNodeId,
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
          (node) => node.id == aRouteNodeId,
          (node) => node.id == adRouteNodeId,
          (node) => node.id == adShellRouteNodeId,
          (node) => node.id == adeRouteNodeId,
        ]);
      },
    );
  }

  void routeToChildAde(BuildContext context) {
    WorkingRouter.of(context).routeTo(childAdeTarget);
  }
}
