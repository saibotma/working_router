import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import '../working_router.dart';

class WorkingRouterDataProvider<ID> extends StatefulWidget {
  final WorkingRouter<ID> router;
  final Widget child;

  const WorkingRouterDataProvider({
    required this.router,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  State<WorkingRouterDataProvider<ID>> createState() {
    return _WorkingRouterDataProviderState<ID>();
  }
}

class _WorkingRouterDataProviderState<ID>
    extends State<WorkingRouterDataProvider<ID>> {
  @override
  void initState() {
    super.initState();
    widget.router.addListener(handleMyRouterNotify);
  }

  @override
  Widget build(BuildContext context) {
    return WorkingRouterDataProviderInherited<ID>(
      myRouter: widget.router,
      locations: widget.router.currentLocations,
      pathParameters: widget.router.currentPathParameters,
      queryParameters:
          widget.router.currentPath?.queryParameters.toIMap() ?? IMap(),
      child: NotificationListener(
        child: widget.child,
        onNotification: (notification) {
          if (notification is AddLocationGuardMessage) {
            widget.router.addGuard(notification.state);
            return true;
          }
          if (notification is RemoveLocationGuardMessage) {
            widget.router.removeGuard(notification.state);
            return true;
          }
          return false;
        },
      ),
    );
  }

  void handleMyRouterNotify() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.router.removeListener(handleMyRouterNotify);
    super.dispose();
  }
}

class WorkingRouterDataProviderInherited<ID> extends InheritedWidget {
  final WorkingRouter<ID> myRouter;
  final IList<Location<ID>> locations;
  final IMap<String, String> queryParameters;
  final IMap<String, String> pathParameters;

  const WorkingRouterDataProviderInherited({
    required this.myRouter,
    required this.locations,
    required this.queryParameters,
    required this.pathParameters,
    required Widget child,
  }) : super(child: child);

  @override
  bool updateShouldNotify(
    covariant WorkingRouterDataProviderInherited<ID> oldWidget,
  ) {
    return oldWidget.locations != locations ||
        oldWidget.queryParameters != queryParameters ||
        oldWidget.pathParameters != pathParameters;
  }
}
