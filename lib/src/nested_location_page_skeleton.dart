import 'package:flutter/material.dart';

import 'package:working_router/working_router.dart';

class NestedLocationPageSkeleton<ID> extends BuilderLocationPageSkeleton<ID> {
  final Widget Function(BuildContext context, Widget child)? builder;

  NestedLocationPageSkeleton({
    required WorkingRouter<ID> router,
    required BuildPages<ID> buildPages,
    this.builder,
    super.buildPage,
    super.buildKey,
    String? debugLabel,
  }) : super(
         buildChild: (context, _) {
           final nested = NestedRouting(
             router: router,
             buildPages: buildPages,
             debugLabel: debugLabel,
           );
           if (builder == null) {
             return nested;
           }
           return builder(context, nested);
         },
       );
}
