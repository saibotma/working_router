import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_page_skeleton.dart';
import 'package:working_router/src/multi_shell.dart';
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
    required Iterable<MultiShellResolvedSlot<ID>> slots,
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
             for (final resolvedSlot in slots)
               resolvedSlot.slot: _buildSlotChild(
                 context: context,
                 data: data,
                 resolvedSlot: resolvedSlot,
                 router: router,
                 buildPages: buildPages,
                 debugLabel: debugLabel,
               ),
           });
           return buildChild(context, data, slotChildren);
         },
       );

  static MultiShellResolvedSlotChild _buildSlotChild<ID>({
    required BuildContext context,
    required WorkingRouterData<ID> data,
    required MultiShellResolvedSlot<ID> resolvedSlot,
    required WorkingRouter<ID> router,
    required List<LocationPageSkeleton<ID>> Function(
      WorkingRouter<ID> router,
      AnyLocation<ID> location,
      WorkingRouterData<ID> data,
    )
    buildPages,
    required String? debugLabel,
  }) {
    if (!resolvedSlot.isEnabled) {
      return const MultiShellResolvedSlotChild(
        isEnabled: false,
        child: null,
      );
    }
    final buildDefaultWidget = resolvedSlot.definition.buildDefaultWidget;
    if (!resolvedSlot.hasRoutedContent && buildDefaultWidget == null) {
      return const MultiShellResolvedSlotChild(
        isEnabled: true,
        child: null,
      );
    }

    return MultiShellResolvedSlotChild(
      isEnabled: true,
      child: NestedRouting<ID>(
        router: router,
        buildPages: buildPages,
        buildDefaultPages: buildDefaultWidget == null
            ? null
            : (data) => [
                _buildDefaultPage(
                  data: data,
                  resolvedSlot: resolvedSlot,
                ),
              ],
        routerKey: resolvedSlot.slot.routerKey,
        debugLabel:
            resolvedSlot.slot.debugLabel ?? '$debugLabel/${resolvedSlot.slot}',
      ),
    );
  }

  static Page<dynamic> _buildDefaultPage<ID>({
    required WorkingRouterData<ID> data,
    required MultiShellResolvedSlot<ID> resolvedSlot,
  }) {
    final buildDefaultWidget = resolvedSlot.definition.buildDefaultWidget!;
    final defaultChild = InheritedWorkingRouterData(
      data: data,
      child: Builder(
        builder: (context) {
          return buildDefaultWidget(context, data);
        },
      ),
    );
    final key = ValueKey((resolvedSlot.slot.routerKey, 'default'));
    return resolvedSlot.definition.buildDefaultPage?.call(
          key,
          defaultChild,
        ) ??
        MaterialPage<dynamic>(key: key, child: defaultChild);
  }
}
