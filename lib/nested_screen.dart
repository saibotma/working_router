import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
                  MyRouterProvider.of(context).routeToLocation(ALocation());
                },
              ),
              MaterialButton(
                child: Text("/a/b"),
                onPressed: () {
                  MyRouterProvider.of(context).routeToLocation(ABLocation());
                },
              ),
              MaterialButton(
                child: Text("/a/b/c"),
                onPressed: () {
                  MyRouterProvider.of(context).routeToLocation(ABCLocation());
                },
              ),
              MaterialButton(
                child: Text("/a/d"),
                onPressed: () {
                  MyRouterProvider.of(context).routeToLocation(ADLocation());
                },
              ),
              MaterialButton(
                child: Text("/a/d/c"),
                onPressed: () {
                  MyRouterProvider.of(context).routeToLocation(ADCLocation());
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: Router(
              routerDelegate: NestedRouterDelegate(
                myRouter: MyRouterProvider.of(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NestedRouterDelegate extends RouterDelegate<String> with ChangeNotifier {
  final MyRouter myRouter;
  late List<Page<dynamic>> pages;

  NestedRouterDelegate({required this.myRouter}) {
    pages = routeTo(myRouter.currentLocation);
    myRouter.addListener(() {
      pages = routeTo(myRouter.currentLocation);
      notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: pages,
      onPopPage: (route, result) {
        print("onPopPage");
        final didPop = route.didPop(result);
        if (didPop) {
          myRouter.pop();
        }
        return didPop;
      },
    );
  }

  @override
  Future<bool> popRoute() {
    return SynchronousFuture(true);
  }

  @override
  Future<void> setNewRoutePath(String configuration) {
    return SynchronousFuture(null);
  }

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
              MaterialButton(onPressed: () {

              }),
              const BackButton(),
            ],
          ),
        ),
      ),
    ),
  );

  List<Page<dynamic>> routeTo(Location location) {
    if (location is ALocation) {
      return [emptyPage];
    } else if (location is ABLocation ||
        location is ABCLocation ||
        location is ADLocation ||
        location is ADCLocation) {
      return [emptyPage, filledPage];
    }

    throw Exception("Unknown location");
  }
}
