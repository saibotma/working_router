import 'package:flutter/material.dart';

import 'package:working_router/working_router.dart';

/// Hosts a nested [WorkingRouterDelegate] inside widget state.
///
/// The nested delegate keeps owning its `Navigator` key and page stack across
/// parent route-tree rebuilds, so shell navigators can survive
/// [WorkingRouter.refresh] as long as the surrounding shell widget is reused.
/// This is what lets working_router support dynamic route trees without
/// immediately discarding nested navigator state on every refresh.
class NestedRouting<ID extends Enum> extends StatefulWidget {
  final WorkingRouter<ID> router;
  final BuildPages<ID> buildPages;
  final List<Page<dynamic>> Function(WorkingRouterData<ID> data)?
  buildDefaultPages;
  final WorkingRouterKey routerKey;
  final String? debugLabel;

  const NestedRouting({
    required this.router,
    required this.buildPages,
    this.buildDefaultPages,
    required this.routerKey,
    this.debugLabel,
    super.key,
  });

  @override
  State<NestedRouting<ID>> createState() => _NestedRoutingState<ID>();
}

class _NestedRoutingState<ID extends Enum> extends State<NestedRouting<ID>> {
  late WorkingRouterDelegate<ID>? _delegate = WorkingRouterDelegate(
    isRootDelegate: false,
    routerKey: widget.routerKey,
    router: widget.router,
    buildPages: widget.buildPages,
    buildDefaultPages: widget.buildDefaultPages,
    debugLabel: widget.debugLabel,
  );

  @override
  void didUpdateWidget(covariant NestedRouting<ID> oldWidget) {
    // The stateful nested delegate is reused across widget updates, so keep
    // its router ownership key in sync when the surrounding shell now targets
    // a different nested router boundary.
    if (!identical(oldWidget.routerKey, widget.routerKey)) {
      _delegate!.updateRouterKey(widget.routerKey);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    final data = WorkingRouterData.of<ID>(context);
    _delegate!.updateData(data);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // Depend on working router to make didChangeDependencies get called.
    WorkingRouterData.of<ID>(context);

    // Followed https://github.com/flutter/flutter/issues/55570#issuecomment-665330166
    // on how to connect this to the root back button dispatcher.
    final parentRouter = Router.of(context);
    final childBackButtonDispatcher = parentRouter.backButtonDispatcher!
        .createChildBackButtonDispatcher();
    childBackButtonDispatcher.takePriority();
    return Router(
      routerDelegate: _delegate!,
      backButtonDispatcher: childBackButtonDispatcher,
    );
  }

  @override
  void dispose() {
    _delegate!.deregister();
    _delegate = null;
    super.dispose();
  }
}
