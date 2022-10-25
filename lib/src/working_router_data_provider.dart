import 'package:flutter/material.dart';
import '../working_router.dart';

class WorkingRouterDataProvider<ID> extends StatefulWidget {
  final WorkingRouter<ID> router;
  final Location<ID>? location;
  final Widget child;

  const WorkingRouterDataProvider({
    required this.router,
    required this.child,
    this.location,
    Key? key,
  }) : super(key: key);

  @override
  State<WorkingRouterDataProvider<ID>> createState() {
    return _WorkingRouterDataProviderState<ID>();
  }
}

class _WorkingRouterDataProviderState<ID>
    extends State<WorkingRouterDataProvider<ID>> {
  WorkingRouterData<ID>? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleMyRouterNotify();
    });
    widget.router.addListener(handleMyRouterNotify);
  }

  @override
  Widget build(BuildContext context) {
    return WorkingRouterDataProviderInherited<ID>(
      router: widget.router,
      data: _data,
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
    final newData = widget.router.data;
    final location = widget.location;
    if (location == null || (newData?.isIdActive(location.id) ?? false)) {
      setState(() => _data = newData);
    }
  }

  @override
  void dispose() {
    widget.router.removeListener(handleMyRouterNotify);
    super.dispose();
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
