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
  late final _delegate = WorkingRouterDelegate(
    isRootDelegate: false,
    router: widget.router,
    buildPages: widget.buildPages,
  );

  @override
  Widget build(BuildContext context) {
    return Router(routerDelegate: _delegate);
  }
}
