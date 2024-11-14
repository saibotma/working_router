import 'package:flutter/cupertino.dart';

import 'working_router_data_sailor.dart';

class InheritedWorkingRouter<ID> extends InheritedWidget {
  final WorkingRouterDataSailor<ID> sailor;

  const InheritedWorkingRouter({
    required super.child,
    required this.sailor,
    super.key,
  });

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}
