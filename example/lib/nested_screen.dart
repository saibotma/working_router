import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'app_routes.dart';
import 'location_id.dart';

class NestedScreen extends StatelessWidget {
  final Widget child;

  const NestedScreen({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final router = WorkingRouter.of<LocationId>(context);

    return Row(
      children: [
        Container(
          color: Colors.yellow,
          width: 200,
          child: Column(
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
                      idParam: 'test',
                      bParam: 'bee',
                      cParam: 'see',
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
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: child,
          ),
        ),
      ],
    );
  }
}
