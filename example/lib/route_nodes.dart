import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

import 'alphabet_sidebar_screen.dart';
import 'filled_alphabet_screen.dart';
import 'inner_shell_screen.dart';
import 'responsive.dart';
import 'splash_screen.dart';

part 'route_nodes.g.dart';

final splashId = NodeId<SplashNode>();

@RouteNodes()
List<RouteNode> buildRouteNodes({
  required ScreenSize screenSize,
  required WorkingRouterKey rootRouterKey,
}) {
  return [
    SplashNode(
      id: splashId,
      screenSize: screenSize,
      rootRouterKey: rootRouterKey,
    ),
  ];
}
