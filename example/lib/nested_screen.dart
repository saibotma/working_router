import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'location_id.dart';

class NestedScreen extends StatelessWidget {
  final Widget child;

  const NestedScreen({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          color: Colors.yellow,
          width: 200,
          child: Column(
            children: [
              MaterialButton(
                child: const Text("pop"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              MaterialButton(
                child: const Text("/a"),
                onPressed: () {
                  WorkingRouter.of<LocationId>(context).routeToUriString("/a");
                },
              ),
              MaterialButton(
                child: const Text("/a/b"),
                onPressed: () {
                  WorkingRouter.of<LocationId>(context)
                      .routeToUriString("/a/b");
                },
              ),
              MaterialButton(
                child: const Text("/a/b/c"),
                onPressed: () {
                  WorkingRouter.of<LocationId>(context)
                      .routeToUriString("/a/b/c");
                },
              ),
              MaterialButton(
                child: const Text("/a/d"),
                onPressed: () {
                  WorkingRouter.of<LocationId>(context)
                      .routeToUriString("/a/d");
                },
              ),
              MaterialButton(
                child: const Text("/a/d/c"),
                onPressed: () {
                  WorkingRouter.of<LocationId>(context)
                      .routeToUriString("/a/d/c");
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
