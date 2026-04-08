import 'package:flutter/material.dart';
import 'package:working_router/src/route_node.dart';
import 'package:working_router/src/working_router_data.dart';

typedef ShellWidgetBuilder<ID> =
    Widget Function(
      BuildContext context,
      WorkingRouterData<ID> data,
      Widget child,
    );

typedef ShellPageBuilder =
    Page<dynamic> Function(
      LocalKey? key,
      Widget child,
    );

class Shell<ID> extends RouteNode<ID> {
  final GlobalKey<NavigatorState> navigatorKey;
  final ShellWidgetBuilder<ID> _buildWidget;
  final ShellPageBuilder? _buildPage;

  @override
  final List<RouteNode<ID>> children;

  Shell({
    required this.navigatorKey,
    required this.children,
    required ShellWidgetBuilder<ID> buildWidget,
    ShellPageBuilder? buildPage,
    super.parentNavigatorKey,
  }) : _buildWidget = buildWidget,
       _buildPage = buildPage;

  Widget buildWidget(
    BuildContext context,
    WorkingRouterData<ID> data,
    Widget child,
  ) {
    return _buildWidget(context, data, child);
  }

  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return _buildPage?.call(key, child) ??
        MaterialPage<dynamic>(key: key, child: child);
  }
}
