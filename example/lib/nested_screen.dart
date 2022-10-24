import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'location_id.dart';
import '../locations/ab_location.dart';
import '../locations/abc_location.dart';
import '../locations/ad_location.dart';
import '../locations/adc_location.dart';

class NestedScreen extends StatefulWidget {
  const NestedScreen({Key? key}) : super(key: key);

  @override
  State<NestedScreen> createState() => _NestedScreenState();
}

class _NestedScreenState extends State<NestedScreen> {
  final emptyPage = LocationPageSkeleton<LocationId>(
    child: Container(color: Colors.white, child: const Text("Empty page")),
  );

  final filledPage = LocationPageSkeleton<LocationId>(
    child: Scaffold(
      body: Container(
        color: Colors.blueGrey,
        child: Center(
          child: Column(
            children: [
              MaterialButton(onPressed: () {}),
              const BackButton(),
            ],
          ),
        ),
      ),
    ),
  );

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
            child: Router(
              routerDelegate: WorkingRouterDelegate(
                isRootRouter: false,
                router: WorkingRouter.of<LocationId>(context),
                buildPages: (location, topLocation) {
                  if (location is ABLocation ||
                      location is ABCLocation ||
                      location is ADLocation ||
                      location is ADCLocation) {
                    return [filledPage];
                  }

                  return [emptyPage];
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
