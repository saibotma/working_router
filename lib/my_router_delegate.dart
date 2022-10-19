import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/locations/a_location.dart';
import 'package:navigator_test/locations/ab_location.dart';
import 'package:navigator_test/locations/abc_location.dart';
import 'package:navigator_test/locations/location.dart';
import 'package:navigator_test/locations/not_found_location.dart';
import 'package:navigator_test/locations/splash_location.dart';
import 'package:navigator_test/my_router.dart';
import 'package:navigator_test/nested_screen.dart';
import 'package:navigator_test/platform_modal/platform_modal_page.dart';

class MyRouterDelegate extends RouterDelegate<String> with ChangeNotifier {
  final MyRouter myRouter;
  late List<Page<dynamic>> pages;

  MyRouterDelegate({required this.myRouter}) {
    pages = routeTo(myRouter.currentLocation!);
    myRouter.addListener(() {
      pages = routeTo(myRouter.currentLocation!);
      notifyListeners();
    });
  }

  @override
  String? get currentConfiguration => myRouter.currentPath;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: pages,
      onPopPage: (route, result) {
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
    myRouter.routeToUri(configuration);
    return SynchronousFuture(null);
  }

  final splashPage =
      MaterialPage(child: Container(child: Text("Splash screen")));
  final nestedPage = MaterialPage(key: UniqueKey(), child: NestedScreen());
  final dialogPage = PlatformModalPage(
      child: Container(color: Colors.white, width: 300, height: 300));
  final notFoundPage = MaterialPage(child: Container(child: Text("Not found")));

  List<Page<dynamic>> routeTo(Location location) {
    if (location is SplashLocation) {
      return [splashPage];
    }
    if (location is ALocation || location is ABLocation) {
      return [nestedPage];
    }
    if (location is ABCLocation) {
      return [nestedPage, dialogPage];
    }

    if (location is NotFoundLocation) {
      return [notFoundPage];
    }

    throw Exception("Unknown location");
  }
}
