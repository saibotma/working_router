import 'package:flutter/material.dart';
import 'working_router_data.dart';

typedef WorkingRouterFunction = dynamic Function(WorkingRouterData<dynamic>);

class InheritedWorkingRouterData<ID>
    extends InheritedModel<WorkingRouterFunction> {
  final WorkingRouterData<ID> data;

  const InheritedWorkingRouterData({
    required super.child,
    required this.data,
    super.key,
  });

  @override
  bool updateShouldNotify(covariant InheritedWorkingRouterData<ID> oldWidget) {
    return oldWidget.data != data;
  }

  @override
  bool updateShouldNotifyDependent(
    covariant InheritedWorkingRouterData<ID> oldWidget,
    Set<dynamic Function(WorkingRouterData<ID>)> dependencies,
  ) {
    return dependencies
        .any((element) => element(data) != element(oldWidget.data));
  }
}
