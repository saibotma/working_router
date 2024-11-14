import 'package:flutter/material.dart';
import 'working_router_data.dart';

class InheritedWorkingRouterData<ID> extends InheritedWidget {
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
}
