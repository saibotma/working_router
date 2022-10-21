import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';

class NearestLocation<ID> extends InheritedWidget {
  final Location<ID> location;

  const NearestLocation({
    required this.location,
    required super.child,
    super.key,
  });

  static Location<ID> of<ID>(BuildContext context) {
    final NearestLocation<ID>? nearestLocation =
        context.dependOnInheritedWidgetOfExactType<NearestLocation<ID>>();
    return nearestLocation!.location;
  }

  @override
  bool updateShouldNotify(covariant NearestLocation oldWidget) {
    return oldWidget.location != location;
  }
}
