import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../filled_alphabet_screen.dart';
import '../location_id.dart';
import 'adc_location.dart';

class ADLocation extends Location<LocationId> {
  final GlobalKey<NavigatorState> rootNavigatorKey;

  ADLocation({
    required super.id,
    required this.rootNavigatorKey,
  });

  @override
  late final children = [
    ADCLocation(
      id: LocationId.adc,
      parentNavigatorKey: rootNavigatorKey,
    ),
  ];

  @override
  List<PathSegment> get path => const [PathSegment.literal('d')];

  @override
  bool get buildsOwnPage => true;

  @override
  Widget buildWidget(BuildContext context, WorkingRouterData<LocationId> data) {
    return const FilledAlphabetScreen();
  }
}
