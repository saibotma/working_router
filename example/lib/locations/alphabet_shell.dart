import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../location_id.dart';
import '../nested_screen.dart';
import '../pop_until_target.dart';
import 'a_location.dart';

class AlphabetShell extends Shell<LocationId> {
  final GlobalKey<NavigatorState> rootNavigatorKey;

  AlphabetShell({
    required super.navigatorKey,
    required this.rootNavigatorKey,
  });

  @override
  late final List<RouteNode<LocationId>> children = [
    ALocation(
      id: LocationId.a,
      rootNavigatorKey: rootNavigatorKey,
      tags: [PopUntilTarget()],
    ),
  ];

  @override
  Widget buildWidget(
    BuildContext context,
    WorkingRouterData<LocationId> data,
    Widget child,
  ) {
    return NestedScreen(child: child);
  }
}
