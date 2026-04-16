import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'route_nodes.dart';
import 'route_node_id.dart';
import 'responsive.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Responsive(
      builder: (context, size) {
        return _DependentMaterialApp(screenSize: size);
      },
    );
  }
}

class _DependentMaterialApp extends StatefulWidget {
  final ScreenSize screenSize;

  const _DependentMaterialApp({
    required this.screenSize,
  });

  @override
  State<_DependentMaterialApp> createState() => _DependentMaterialAppState();
}

class _DependentMaterialAppState extends State<_DependentMaterialApp> {
  late final WorkingRouter<RouteNodeId> router = WorkingRouter<RouteNodeId>(
    noContentWidget: const Center(child: Text('No matching route.')),
    buildRouteNodes: (rootRouterKey) => buildRouteNodes(
      screenSize: widget.screenSize,
      rootRouterKey: rootRouterKey,
    ),
  );

  @override
  void didUpdateWidget(covariant _DependentMaterialApp oldWidget) {
    if (oldWidget.screenSize != widget.screenSize) {
      debugPrint(
        'Refreshing router for screen size change: '
        '${oldWidget.screenSize} -> ${widget.screenSize}',
      );
      router.refresh();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'working_router example',
      routerConfig: router,
    );
  }
}
