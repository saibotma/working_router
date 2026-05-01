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
/// A refresh still replaces the route-node instances in
/// [WorkingRouterData.routeNodes]. When this widget is reused after the
/// surrounding shell or slot rebuilds, the nested delegate must receive the new
/// [routerKey] and [buildDefaultPages] callback so default pages are rebuilt
/// from the refreshed route-node definitions instead of from the old tree.
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
    // a different nested router boundary. The default-page builder also
    // comes from the current shell/slot node definitions, which are replaced
    // by WorkingRouter.refresh().
    final routerKeyChanged = !identical(oldWidget.routerKey, widget.routerKey);
    final buildDefaultPagesChanged = !identical(
      oldWidget.buildDefaultPages,
      widget.buildDefaultPages,
    );
    if (routerKeyChanged || buildDefaultPagesChanged) {
      _delegate!.updateConfiguration(
        routerKey: widget.routerKey,
        buildDefaultPages: widget.buildDefaultPages,
        data: widget.router.nullableData,
      );
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
