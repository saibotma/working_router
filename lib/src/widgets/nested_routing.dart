import 'package:flutter/material.dart';

import 'package:working_router/working_router.dart';

class NestedRouting<ID> extends StatefulWidget {
  final WorkingRouter<ID> router;
  final BuildPages<ID> buildPages;
  final String? debugLabel;

  const NestedRouting({
    required this.router,
    required this.buildPages,
    this.debugLabel,
    super.key,
  });

  @override
  State<NestedRouting<ID>> createState() => _NestedRoutingState<ID>();
}

class _NestedRoutingState<ID> extends State<NestedRouting<ID>> {
  late WorkingRouterDelegate<ID>? _delegate = WorkingRouterDelegate(
    isRootDelegate: false,
    router: widget.router,
    buildPages: widget.buildPages,
    debugLabel: widget.debugLabel,
  );

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
    _delegate!.dispose();
    _delegate = null;
    super.dispose();
  }
}
