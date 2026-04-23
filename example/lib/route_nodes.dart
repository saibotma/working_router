import 'package:flutter/widgets.dart';
import 'package:working_router/working_router.dart';

import 'locations.dart';
import 'nested_screen.dart';
import 'responsive.dart';
import 'splash_screen.dart';

part 'route_nodes.g.dart';

@RouteNodes()
List<RouteNode> buildRouteNodes({
  required ScreenSize screenSize,
  required WorkingRouterKey rootRouterKey,
}) {
  return [
    SplashNode(
      id: splashId,
      build: (builder, location) {
        builder.content = Content.widget(const SplashScreen());
        builder.children = [
          Shell(
            navigatorEnabled: screenSize != ScreenSize.small,
            build: (builder, shell, routerKey) {
              builder.content = ShellContent.builder(
                (context, data, child) => NestedScreen(child: child),
              );

              builder.children = [
                ANode(
                  id: aId,
                  rendersStandaloneSidebar: screenSize == ScreenSize.small,
                  rootRouterKey: rootRouterKey,
                  outerShellRouterKey: routerKey,
                ),
              ];
            },
          ),
        ];
      },
    ),
  ];
}
