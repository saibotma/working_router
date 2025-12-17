import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

class NestedLocationPageSkeleton<ID> extends BuilderLocationPageSkeleton<ID> {
  NestedLocationPageSkeleton({
    required WorkingRouter<ID> router,
    required BuildPages<ID> buildPages,
    Widget Function(
      BuildContext context,
      WorkingRouterData<ID> data,
      Widget child,
    )?
    buildChild,
    super.buildPage,
    super.buildKey,
    String? debugLabel,
  }) : super(
         buildChild: (context, data) {
           final nested = NestedRouting(
             router: router,
             buildPages: buildPages,
             debugLabel: debugLabel,
           );
           if (buildChild == null) {
             return nested;
           }
           return buildChild(context, data, nested);
         },
       );
}
