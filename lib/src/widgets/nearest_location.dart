import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';

class NearestLocation<ID> extends InheritedWidget {
  final AnyLocation<ID> location;

  const NearestLocation({
    required this.location,
    required super.child,
    super.key,
  });

  static AnyLocation<ID> of<ID>(BuildContext context) {
    final NearestLocation<ID>? nearestLocation = context
        .dependOnInheritedWidgetOfExactType<NearestLocation<ID>>();
    return nearestLocation!.location;
  }

  @override
  bool updateShouldNotify(covariant NearestLocation<ID> oldWidget) {
    return oldWidget.location != location;
  }
}
