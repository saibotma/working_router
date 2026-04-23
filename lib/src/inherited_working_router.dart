import 'package:flutter/cupertino.dart';
import 'package:working_router/src/working_router_data_sailor.dart';

class InheritedWorkingRouter extends InheritedWidget {
  final WorkingRouterDataSailor sailor;

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
