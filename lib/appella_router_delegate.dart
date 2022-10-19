import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/locations/a_location.dart';
import 'package:navigator_test/locations/ab_location.dart';
import 'package:navigator_test/locations/abc_location.dart';
import 'package:navigator_test/locations/ad_location.dart';
import 'package:navigator_test/locations/adc_location.dart';
import 'package:navigator_test/locations/location.dart';
import 'package:navigator_test/locations/not_found_location.dart';
import 'package:navigator_test/locations/splash_location.dart';
import 'package:navigator_test/my_router.dart';
import 'package:navigator_test/nested_screen.dart';
import 'package:navigator_test/platform_modal/platform_modal_page.dart';

class AppellaRouterDelegate extends RouterDelegate<String> with ChangeNotifier {
  final bool isRootRouter;
  final MyRouter myRouter;
  final List<Page<dynamic>> Function(Location location) buildPages;
  late List<Page<dynamic>> pages;

  AppellaRouterDelegate({
    required this.isRootRouter,
    required this.myRouter,
    required this.buildPages,
  }) {
    pages = buildPages(myRouter.currentLocation);
    myRouter.addListener(() {
      pages = buildPages(myRouter.currentLocation);
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
    if (isRootRouter) {
      myRouter.routeToUri(configuration);
    }
    return SynchronousFuture(null);
  }
}
