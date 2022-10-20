import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/locations/location.dart';
import 'package:navigator_test/my_router.dart';

class AppellaRouterDelegate extends RouterDelegate<String> with ChangeNotifier {
  final bool isRootRouter;
  final MyRouter myRouter;
  final List<Page<dynamic>> Function(List<Location> location) buildPages;
  late List<Page<dynamic>> pages;

  AppellaRouterDelegate({
    required this.isRootRouter,
    required this.myRouter,
    required this.buildPages,
  }) {
    refresh();
    myRouter.addListener(refresh);
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

  void refresh() {
    pages = buildPages(myRouter.currentLocations);
    notifyListeners();
  }
}
