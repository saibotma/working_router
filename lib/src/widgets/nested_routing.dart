import 'package:flutter/material.dart';

import '../../working_router.dart';

class NestedRouting<ID> extends StatefulWidget {
  final WorkingRouter<ID> router;
  final BuildPages<ID> buildPages;

  const NestedRouting({
    required this.router,
    required this.buildPages,
    Key? key,
  }) : super(key: key);

  @override
  State<NestedRouting<ID>> createState() => _NestedRoutingState<ID>();
}

class _NestedRoutingState<ID> extends State<NestedRouting<ID>> {
  late WorkingRouterDelegate<ID>? _delegate = WorkingRouterDelegate(
    isRootDelegate: false,
    router: widget.router,
    buildPages: widget.buildPages,
  );

  @override
  void didChangeDependencies() {
    final data = WorkingRouter.of<ID>(context).data;
    _delegate!.updateData(data);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // Depend on working router to make didChangeDependencies get called.
    WorkingRouter.of<ID>(context);
    return Router(routerDelegate: _delegate!);
  }

  @override
  void dispose() {
    _delegate!.deregister();
    _delegate = null;
    super.dispose();
  }
}
