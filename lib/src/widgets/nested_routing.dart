import 'package:flutter/material.dart';

import 'package:working_router/src/inherited_working_router.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';
import 'package:working_router/src/working_router_delegate.dart';
import 'package:working_router/src/working_router_key.dart';

/// Hosts a nested [WorkingRouterDelegate] inside widget state.
///
/// The nested delegate keeps owning its `Navigator` key and page stack across
/// parent route-tree rebuilds, so shell navigators can survive
/// [WorkingRouter.refresh] as long as the surrounding shell widget is reused.
/// This is what lets working_router support dynamic route trees without
/// immediately discarding nested navigator state on every refresh.
///
/// It also installs a navigator-aware [WorkingRouter.of] value. Calling
/// `WorkingRouter.of(context).routeBack()` from inside this widget routes back
/// inside this nested navigator first, then falls back to the parent/global
/// router when this navigator has no active location to remove.
class NestedRouting extends StatefulWidget {
  final WorkingRouter router;
  final List<Page<dynamic>> Function(WorkingRouterData data)? buildDefaultPages;
  final WorkingRouterKey routerKey;
  final String? debugLabel;

  const NestedRouting({
    required this.router,
    this.buildDefaultPages,
    required this.routerKey,
    this.debugLabel,
    super.key,
  });

  @override
  State<NestedRouting> createState() => _NestedRoutingState();
}

class _NestedRoutingState extends State<NestedRouting> {
  late WorkingRouterDelegate? _delegate = WorkingRouterDelegate(
    isRootDelegate: false,
    routerKey: widget.routerKey,
    router: widget.router,
    buildDefaultPages: widget.buildDefaultPages,
    debugLabel: widget.debugLabel,
  );
  late final NestedWorkingRouterSailor _sailor = NestedWorkingRouterSailor(
    router: widget.router,
    routerKey: widget.routerKey,
  );

  @override
  void didUpdateWidget(covariant NestedRouting oldWidget) {
    // The stateful nested delegate is reused across widget updates, so keep
    // its router ownership key in sync when the surrounding shell now targets
    // a different nested router boundary.
    if (!identical(oldWidget.routerKey, widget.routerKey)) {
      _delegate!.updateRouterKey(widget.routerKey);
      _sailor.routerKey = widget.routerKey;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    final data = WorkingRouterData.of(context);
    _delegate!.updateData(data);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // Depend on working router to make didChangeDependencies get called.
    WorkingRouterData.of(context);

    // Followed https://github.com/flutter/flutter/issues/55570#issuecomment-665330166
    // on how to connect this to the root back button dispatcher.
    final parentRouter = Router.of(context);
    final childBackButtonDispatcher = parentRouter.backButtonDispatcher!
        .createChildBackButtonDispatcher();
    childBackButtonDispatcher.takePriority();
    return InheritedWorkingRouter(
      sailor: _sailor,
      child: Router(
        routerDelegate: _delegate!,
        backButtonDispatcher: childBackButtonDispatcher,
      ),
    );
  }

  @override
  void dispose() {
    _delegate!.deregister();
    _delegate = null;
    _sailor.dispose();
    super.dispose();
  }
}
