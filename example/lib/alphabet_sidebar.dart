import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'route_nodes.dart';
import 'location_id.dart';

class AlphabetSidebar extends StatelessWidget {
  final bool showInnerShellBypassRoute;

  const AlphabetSidebar({
    this.showInnerShellBypassRoute = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final router = WorkingRouter.of<LocationId>(context);

    return ColoredBox(
      color: Colors.yellow,
      child: SafeArea(
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MaterialButton(
                child: const Text('pop'),
                onPressed: () {
                  router.routeBack();
                },
              ),
              MaterialButton(
                child: const Text('/a'),
                onPressed: () {
                  router.routeToA();
                },
              ),
              MaterialButton(
                child: const Text('/a/b'),
                onPressed: () {
                  router.routeToAb();
                },
              ),
              MaterialButton(
                child: const Text('/a/b/c/test'),
                onPressed: () {
                  router.routeTo(
                    AbcRouteTarget(
                      id: 'test',
                      b: 'bee',
                      c: 'see',
                    ),
                  );
                },
              ),
              MaterialButton(
                child: const Text('/a/d'),
                onPressed: () {
                  router.routeToAd();
                },
              ),
              MaterialButton(
                child: const Text('/a/d/c'),
                onPressed: () {
                  router.routeToAdc();
                },
              ),
              if (showInnerShellBypassRoute)
                MaterialButton(
                  child: const Text('/a/d/e'),
                  onPressed: () {
                    router.routeToAde();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
