import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

class NestedLocationPageSkeleton<ID extends Enum>
    extends BuilderLocationPageSkeleton<ID> {
  NestedLocationPageSkeleton({
    required WorkingRouter<ID> router,
    required BuildPages<ID> buildPages,
    List<Page<dynamic>> Function(WorkingRouterData<ID> data)? buildDefaultPages,
    required WorkingRouterKey routerKey,
    Widget Function(
      BuildContext context,
      WorkingRouterData<ID> data,
      Widget child,
    )?
    buildChild,
    super.buildPage,
    super.buildPageKey,
    String? debugLabel,
  }) : super(
         buildChild: (context, data) {
           final nested = NestedRouting(
             router: router,
             buildPages: buildPages,
             buildDefaultPages: buildDefaultPages,
             routerKey: routerKey,
             debugLabel: debugLabel,
           );
           if (buildChild == null) {
             return nested;
           }
           return buildChild(context, data, nested);
         },
       );
}
