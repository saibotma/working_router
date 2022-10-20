import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/appella_router_delegate.dart';
import 'package:navigator_test/locations/a_location.dart';
import 'package:navigator_test/locations/ab_location.dart';
import 'package:navigator_test/locations/adc_location.dart';
import 'package:navigator_test/locations/location.dart';
import 'package:navigator_test/my_router.dart';

import 'locations/abc_location.dart';
import 'locations/ad_location.dart';

class NestedScreen extends StatefulWidget {
  const NestedScreen({Key? key}) : super(key: key);

  @override
  State<NestedScreen> createState() => _NestedScreenState();
}

class _NestedScreenState extends State<NestedScreen> {
  final emptyPage = MaterialPage(
    child: Container(color: Colors.white, child: Text("Empty page")),
  );
  final filledPage = MaterialPage(
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
                child: Text("pop"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              MaterialButton(
                child: Text("/a"),
                onPressed: () {
                  MyRouter.of(context).routeToUriString("/a");
                },
              ),
              MaterialButton(
                child: Text("/a/b"),
                onPressed: () {
                  MyRouter.of(context).routeToUriString("/a/b");
                },
              ),
              MaterialButton(
                child: Text("/a/b/c"),
                onPressed: () {
                  MyRouter.of(context).routeToUriString("/a/b/c");
                },
              ),
              MaterialButton(
                child: Text("/a/d"),
                onPressed: () {
                  MyRouter.of(context).routeToUriString("/a/d");
                },
              ),
              MaterialButton(
                child: Text("/a/d/c"),
                onPressed: () {
                  MyRouter.of(context).routeToUriString("/a/d/c");
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: Router(
              routerDelegate: AppellaRouterDelegate(
                isRootRouter: false,
                myRouter: MyRouter.of(context),
                buildPages: (locations) {
                  final location = locations.last;
                  if (location is ALocation) {
                    return [emptyPage];
                  } else if (location is ABLocation ||
                      location is ABCLocation ||
                      location is ADLocation ||
                      location is ADCLocation) {
                    return [emptyPage, filledPage];
                  }

                  throw Exception("Unknown location");
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
