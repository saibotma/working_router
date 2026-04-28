import 'package:flutter/material.dart';
import 'package:working_router/src/working_router_data.dart';

typedef WorkingRouterFunction = dynamic Function(WorkingRouterData);

class InheritedWorkingRouterData extends InheritedModel<WorkingRouterFunction> {
  final WorkingRouterData data;

  const InheritedWorkingRouterData({
    required super.child,
    required this.data,
    super.key,
  });

  @override
  bool updateShouldNotify(covariant InheritedWorkingRouterData oldWidget) {
    return oldWidget.data != data;
  }

  @override
  bool updateShouldNotifyDependent(
    covariant InheritedWorkingRouterData oldWidget,
    Set<dynamic Function(WorkingRouterData)> dependencies,
  ) {
    return dependencies.any(
      (element) => element(data) != element(oldWidget.data),
    );
  }
}
