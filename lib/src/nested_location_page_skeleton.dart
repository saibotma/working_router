import 'package:flutter/material.dart';

import '../working_router.dart';

class NestedLocationPageSkeleton<ID> extends LocationPageSkeleton<ID> {
  final Widget Function(BuildContext context, Widget child) builder;

  NestedLocationPageSkeleton({
    required WorkingRouter<ID> router,
    required BuildPages<ID> buildPages,
    required this.builder,
    super.buildPage,
    super.buildKey,
  }) : super(
          child: Builder(
            builder: (context) {
              return builder(
                context,
                NestedRouting(router: router, buildPages: buildPages),
              );
            },
          ),
        );
}
