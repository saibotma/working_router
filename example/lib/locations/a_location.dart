import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../location_id.dart';
import 'ab_location.dart';
import 'ad_location.dart';

class ALocation extends Location<LocationId> {
  final GlobalKey<NavigatorState> rootNavigatorKey;

  ALocation({
    required super.id,
    required this.rootNavigatorKey,
    super.tags,
  });

  @override
  late final children = [
    ABLocation(
      id: LocationId.ab,
      rootNavigatorKey: rootNavigatorKey,
    ),
    ADLocation(
      id: LocationId.ad,
      rootNavigatorKey: rootNavigatorKey,
    ),
  ];

  @override
  List<PathSegment> get path => [literal('a')];

  @override
  bool get buildsOwnPage => true;

  @override
  Widget buildWidget(BuildContext context, WorkingRouterData<LocationId> data) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Text('Empty page'),
    );
  }
}
