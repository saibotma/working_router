import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navigator_test/locations/location.dart';
import 'package:navigator_test/my_router.dart';

class AppellaRouterDelegate extends RouterDelegate<Uri> with ChangeNotifier {
  final bool isRootRouter;
  final MyRouter myRouter;
  final List<Page<dynamic>> Function(IList<Location> location) buildPages;
  late List<Page<dynamic>> pages;
  late final GlobalKey<NavigatorState> navigatorKey;

  AppellaRouterDelegate({
    required this.isRootRouter,
    required this.myRouter,
    required this.buildPages,
  }) {
    navigatorKey = GlobalKey<NavigatorState>();
    refresh();
    myRouter.addListener(refresh);
  }

  @override
  Uri? get currentConfiguration => myRouter.currentPath;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      // A Navigator may not have empty pages.
      return Container();
    }
    return Navigator(
      key: navigatorKey,
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
  Future<void> setNewRoutePath(Uri configuration) {
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
