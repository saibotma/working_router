import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'alphabet_sidebar_screen.dart';
import 'nested_screen.dart';
import 'responsive.dart';
import 'route_nodes.dart';

final aRouteNodeId = RouteNodeId<ARouteNode>();

class SplashRouteNode extends Location<SplashRouteNode> {
  final ScreenSize screenSize;
  final WorkingRouterKey rootRouterKey;

  SplashRouteNode({
    super.id,
    super.parentRouterKey,
    required this.screenSize,
    required this.rootRouterKey,
  });

  @override
  void build(LocationBuilder builder) {
    builder.content = Content.widget(const SplashScreen());
    builder.children = [
      Shell(
        navigatorEnabled: screenSize != ScreenSize.small,
        build: (builder, shell, routerKey) {
          builder.content = ShellContent.builder(
            (context, data, child) => NestedScreen(child: child),
          );

          builder.children = [
            ARouteNode(
              id: aRouteNodeId,
              rendersStandaloneSidebar: screenSize == ScreenSize.small,
              rootRouterKey: rootRouterKey,
              outerShellRouterKey: routerKey,
            ),
          ];
        },
      ),
    ];
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final router = WorkingRouter.of(context);

    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: router.routeToA,
          child: const Text('Splash screen'),
        ),
      ),
    );
  }
}
