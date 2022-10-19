import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/locations/a_location.dart';
import 'package:navigator_test/my_router.dart';

import 'locations/abc_location.dart';

class NestedScreen extends StatefulWidget {
  const NestedScreen({Key? key}) : super(key: key);

  @override
  State<NestedScreen> createState() => _NestedScreenState();
}

class _NestedScreenState extends State<NestedScreen> {
  final routerDelegate = NestedRouterDelegate();
  
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(color: Colors.yellow, width: 200, child: MaterialButton(onPressed: () {
        MyRouterProvider.of(context).routeToLocation(ABCLocation());
      },)),
      Expanded(child: Router(routerDelegate: routerDelegate)),
    ],);
  }
}

class NestedRouterDelegate extends RouterDelegate<String> {
  var pages = [MaterialPage(child: Container(color: Colors.blue))];

  @override
  void addListener(VoidCallback listener) {
    // TODO: implement addListener
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: pages,
      onPopPage: (route, result) {
        return route.didPop(result);
      },
    );
  }

  @override
  Future<bool> popRoute() {
    return SynchronousFuture(true);
  }

  @override
  void removeListener(VoidCallback listener) {
    // TODO: implement removeListener
  }

  @override
  Future<void> setNewRoutePath(String configuration) {
    routeTo(configuration);
    return SynchronousFuture(null);
  }

  void routeTo(String path) {
    if (path == "/a") {
      pages = [MaterialPage(child: Container(color: Colors.white))];
    } else if (path.startsWith("/a/b")) {
      pages = [MaterialPage(child: Container(color: Colors.blueGrey))];
    }
  }
}
