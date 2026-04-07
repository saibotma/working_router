import 'package:flutter/material.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';

abstract class Shell<ID> extends RouteNode<ID> {
  final GlobalKey<NavigatorState> navigatorKey;

  Shell({
    required this.navigatorKey,
    super.children = const [],
    super.parentNavigatorKey,
  });

  Widget buildWidget(
    BuildContext context,
    WorkingRouterData<ID> data,
    Widget child,
  );

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return MaterialPage<dynamic>(key: key, child: child);
  }
}
