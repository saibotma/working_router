import 'package:flutter/material.dart';
import '../working_router.dart';

class WorkingRouterDataProvider<ID> extends StatelessWidget {
  final WorkingRouter<ID> router;
  final WorkingRouterData<ID>? data;
  final Location<ID>? location;
  final Widget child;

  const WorkingRouterDataProvider({
    required this.router,
    required this.data,
    required this.child,
    this.location,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WorkingRouterDataProviderInherited<ID>(
      router: router,
      data: data,
      child: NotificationListener(
        child: child,
        onNotification: (notification) {
          if (notification is AddLocationGuardMessage) {
            router.addGuard(notification.state);
            return true;
          }
          if (notification is RemoveLocationGuardMessage) {
            router.removeGuard(notification.state);
            return true;
          }
          return false;
        },
      ),
    );
  }
}

class WorkingRouterDataProviderInherited<ID> extends InheritedWidget {
  final WorkingRouter<ID> router;

  // Just pass the data, to know when to notify.
  final WorkingRouterData<ID>? data;

  const WorkingRouterDataProviderInherited({
    required this.router,
    required this.data,
    required Widget child,
  }) : super(child: child);

  @override
  bool updateShouldNotify(
    covariant WorkingRouterDataProviderInherited<ID> oldWidget,
  ) {
    return oldWidget.data != data;
  }
}
