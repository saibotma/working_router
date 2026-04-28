import 'package:flutter/material.dart';
import 'package:working_router/src/inherited_working_router_data.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/location_page_skeleton.dart';
import 'package:working_router/src/multi_shell.dart';
import 'package:working_router/src/widgets/nested_routing.dart';
import 'package:working_router/src/working_router.dart';
import 'package:working_router/src/working_router_data.dart';

class MultiShellLocationPageSkeleton extends BuilderLocationPageSkeleton {
  MultiShellLocationPageSkeleton({
    required WorkingRouter router,
    required List<LocationPageSkeleton> Function(
      WorkingRouter router,
      AnyLocation location,
      WorkingRouterData data,
    )
    buildPages,
    required Iterable<MultiShellResolvedSlot> slots,
    required Widget Function(
      BuildContext context,
      WorkingRouterData data,
      MultiShellSlotChildren slots,
    )
    buildChild,
    super.buildPage,
    super.buildPageKey,
    String? debugLabel,
  }) : super(
         buildChild: (context, data) {
           final slotChildren = MultiShellSlotChildren({
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

  static MultiShellResolvedSlotChild _buildSlotChild({
    required BuildContext context,
    required WorkingRouterData data,
    required MultiShellResolvedSlot resolvedSlot,
    required WorkingRouter router,
    required List<LocationPageSkeleton> Function(
      WorkingRouter router,
      AnyLocation location,
      WorkingRouterData data,
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
      child: NestedRouting(
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

  static Page<dynamic> _buildDefaultPage({
    required WorkingRouterData data,
    required MultiShellResolvedSlot resolvedSlot,
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
