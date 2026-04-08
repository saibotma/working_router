import 'package:example/locations/abc_location.dart';
import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../filled_alphabet_screen.dart';
import '../location_id.dart';

class ABLocation extends Location<LocationId> {
  final GlobalKey<NavigatorState> rootNavigatorKey;

  ABLocation({
    required super.id,
    required this.rootNavigatorKey,
  });

  @override
  late final children = [
    ABCLocation(
      id: LocationId.abc,
      parentNavigatorKey: rootNavigatorKey,
    ),
  ];

  @override
  List<PathSegment> get path => [literal('b')];

  @override
  bool get buildsOwnPage => true;

  @override
  Widget buildWidget(BuildContext context, WorkingRouterData<LocationId> data) {
    return const FilledAlphabetScreen();
  }
}
