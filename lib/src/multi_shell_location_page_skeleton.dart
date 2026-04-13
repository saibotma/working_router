import 'package:flutter/material.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_page_skeleton.dart';
import 'package:working_router/src/multi_shell_location.dart';
import 'package:working_router/src/widgets/nested_routing.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';

class MultiShellLocationPageSkeleton<ID>
    extends BuilderLocationPageSkeleton<ID> {
  MultiShellLocationPageSkeleton({
    required WorkingRouter<ID> router,
    required List<LocationPageSkeleton<ID>> Function(
      WorkingRouter<ID> router,
      AnyLocation<ID> location,
      WorkingRouterData<ID> data,
    )
    buildPages,
    required Iterable<MultiShellSlot> activeSlots,
    required Widget Function(
      BuildContext context,
      WorkingRouterData<ID> data,
      MultiShellSlotChildren<ID> slots,
    )
    buildChild,
    super.buildPage,
    super.buildPageKey,
    String? debugLabel,
  }) : super(
         buildChild: (context, data) {
           final slotChildren = MultiShellSlotChildren<ID>({
             for (final slot in activeSlots)
               slot: NestedRouting<ID>(
                 router: router,
                 buildPages: buildPages,
                 routerKey: slot.routerKey,
                 debugLabel: slot.debugLabel ?? '$debugLabel/$slot',
               ),
           });
           return buildChild(context, data, slotChildren);
         },
       );
}
