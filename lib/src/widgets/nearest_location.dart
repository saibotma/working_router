import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';

class NearestLocation extends InheritedWidget {
  final AnyLocation location;

  const NearestLocation({
    required this.location,
    required super.child,
    super.key,
  });

  static AnyLocation of(BuildContext context) {
    final NearestLocation? nearestLocation = context
        .dependOnInheritedWidgetOfExactType<NearestLocation>();
    return nearestLocation!.location;
  }

  @override
  bool updateShouldNotify(covariant NearestLocation oldWidget) {
    return oldWidget.location != location;
  }
}
