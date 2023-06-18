import 'package:flutter/material.dart';

import '../working_router.dart';

class NestedLocationPageSkeleton<ID> extends LocationPageSkeleton<ID> {
  final Widget Function(BuildContext context, Widget child)? builder;

  NestedLocationPageSkeleton({
    required WorkingRouter<ID> router,
    required BuildPages<ID> buildPages,
    this.builder,
    super.buildPage,
    super.buildKey,
    String? debugLabel,
  }) : super(
          child: Builder(
            builder: (context) {
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
          ),
        );
}
