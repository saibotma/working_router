import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'route_nodes.dart';

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
