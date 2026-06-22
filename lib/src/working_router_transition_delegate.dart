import 'package:flutter/widgets.dart';

/// Transition policy for working_router navigators.
///
/// Flutter's [DefaultTransitionDelegate] only pops the top-most exiting route
/// with a transition. Lower exiting page routes, including page routes covered
/// by a manually pushed dialog route, are completed without their pop
/// transition. This delegate uses Flutter's default policy unless an exiting
/// page route has attached pageless routes; only that case gets custom
/// handling so the page and attached pageless routes all pop with transitions.
///
/// TODO: Remove this delegate if Flutter resolves
/// https://github.com/flutter/flutter/issues/111137 with the same behavior.
class WorkingRouterTransitionDelegate<T> extends DefaultTransitionDelegate<T> {
  const WorkingRouterTransitionDelegate();

  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
    locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
    pageRouteToPagelessRoutes,
  }) {
    if (!_hasExitingPageRouteWithPagelessRoutes(
      locationToExitingPageRoute,
      pageRouteToPagelessRoutes,
    )) {
      return super.resolve(
        newPageRouteHistory: newPageRouteHistory,
        locationToExitingPageRoute: locationToExitingPageRoute,
        pageRouteToPagelessRoutes: pageRouteToPagelessRoutes,
      );
    }

    final results = <RouteTransitionRecord>[];

    void markForPop(RouteTransitionRecord route) {
      route.markForPop(route.route.currentResult);
    }

    void markForComplete(RouteTransitionRecord route) {
      route.markForComplete(route.route.currentResult);
    }

    void handleExitingRoute(RouteTransitionRecord? location, bool isLast) {
      final exitingPageRoute = locationToExitingPageRoute[location];
      if (exitingPageRoute == null) {
        return;
      }

      if (exitingPageRoute.isWaitingForExitingDecision) {
        final hasPagelessRoute = pageRouteToPagelessRoutes.containsKey(
          exitingPageRoute,
        );
        final isLastExitingPageRoute =
            isLast && !locationToExitingPageRoute.containsKey(exitingPageRoute);
        if (hasPagelessRoute || isLastExitingPageRoute) {
          markForPop(exitingPageRoute);
        } else {
          markForComplete(exitingPageRoute);
        }
        final pagelessRoutes = pageRouteToPagelessRoutes[exitingPageRoute];
        if (pagelessRoutes != null) {
          for (final pagelessRoute in pagelessRoutes) {
            if (pagelessRoute.isWaitingForExitingDecision) {
              if (hasPagelessRoute ||
                  (isLastExitingPageRoute &&
                      pagelessRoute == pagelessRoutes.last)) {
                markForPop(pagelessRoute);
              } else {
                markForComplete(pagelessRoute);
              }
            }
          }
        }
      }

      results.add(exitingPageRoute);
      handleExitingRoute(exitingPageRoute, isLast);
    }

    handleExitingRoute(null, newPageRouteHistory.isEmpty);

    for (final pageRoute in newPageRouteHistory) {
      final isLastPageRoute = newPageRouteHistory.last == pageRoute;
      if (pageRoute.isWaitingForEnteringDecision) {
        if (!locationToExitingPageRoute.containsKey(pageRoute) &&
            isLastPageRoute) {
          pageRoute.markForPush();
        } else {
          pageRoute.markForAdd();
        }
      }
      results.add(pageRoute);
      handleExitingRoute(pageRoute, isLastPageRoute);
    }

    return results;
  }

  bool _hasExitingPageRouteWithPagelessRoutes(
    Map<RouteTransitionRecord?, RouteTransitionRecord>
    locationToExitingPageRoute,
    Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
    pageRouteToPagelessRoutes,
  ) {
    if (pageRouteToPagelessRoutes.isEmpty) {
      return false;
    }
    for (final exitingPageRoute in locationToExitingPageRoute.values) {
      if (exitingPageRoute.isWaitingForExitingDecision &&
          pageRouteToPagelessRoutes.containsKey(exitingPageRoute)) {
        return true;
      }
    }
    return false;
  }
}
