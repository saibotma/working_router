import 'package:flutter/material.dart';
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

    if (resolvedSlot.hasRoutedContent) {
      return MultiShellResolvedSlotChild(
        isEnabled: true,
        child: NestedRouting<ID>(
          router: router,
          buildPages: buildPages,
          routerKey: resolvedSlot.slot.routerKey,
          debugLabel: resolvedSlot.slot.debugLabel ?? '$debugLabel/${resolvedSlot.slot}',
        ),
      );
    }

    final buildFallbackWidget = resolvedSlot.definition.buildFallbackWidget;
    if (buildFallbackWidget == null) {
      throw StateError(
        'Enabled slot ${resolvedSlot.slot} has neither routed content nor fallback content.',
      );
    }

    final fallbackChild = buildFallbackWidget(context, data);
    final fallbackPage =
        resolvedSlot.definition.buildFallbackPage?.call(
          ValueKey((resolvedSlot.slot.routerKey, 'fallback')),
          fallbackChild,
        ) ??
        MaterialPage<dynamic>(
          key: ValueKey((resolvedSlot.slot.routerKey, 'fallback')),
          child: fallbackChild,
        );

    return MultiShellResolvedSlotChild(
      isEnabled: true,
      child: Navigator(
        key: ValueKey(('multi-shell-fallback', resolvedSlot.slot.routerKey)),
        pages: [fallbackPage],
        onDidRemovePage: (page) {},
      ),
    );
  }
}
