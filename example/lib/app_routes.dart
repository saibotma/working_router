import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'adc_screen.dart';
import 'empty_alphabet_screen.dart';
import 'filled_alphabet_screen.dart';
import 'location_id.dart';
import 'locations/abc_location.dart';
import 'nested_screen.dart';
import 'platform_modal/platform_modal_page.dart';
import 'pop_until_target.dart';
import 'splash_screen.dart';

part 'app_routes.g.dart';

@RouteNodes()
void buildRouteNodes(
  RouteNodesBuilder<LocationId> builder, {
  required GlobalKey<NavigatorState> rootNavigatorKey,
  required GlobalKey<NavigatorState> alphabetNavigatorKey,
}) {
  builder.location((builder) {
    builder.id(LocationId.splash);
    builder.buildWidget((context, data) => const SplashScreen());

    builder.shell((builder) {
      builder.navigatorKey(alphabetNavigatorKey);
      builder.buildWidget(
        (context, data, child) => NestedScreen(child: child),
      );

      builder.location((builder) {
        builder.id(LocationId.a);
        builder.tag(PopUntilTarget());
        builder.pathLiteral('a');
        builder.buildWidget(
          (context, data) => const EmptyAlphabetScreen(),
        );

        builder.location((builder) {
          builder.id(LocationId.ab);
          builder.pathLiteral('b');
          builder.buildWidget(
            (context, data) => const FilledAlphabetScreen(),
          );

          builder.child(
            ABCLocation(
              id: LocationId.abc,
              parentNavigatorKey: rootNavigatorKey,
            ),
          );
        });
        builder.location((builder) {
          builder.id(LocationId.ad);
          builder.pathLiteral('d');
          builder.buildWidget(
            (context, data) => const FilledAlphabetScreen(),
          );

          builder.location((builder) {
            builder.id(LocationId.adc);
            builder.parentNavigatorKey(rootNavigatorKey);
            builder.pathLiteral('c');
            builder.buildPage(
              buildPage: (key, child) {
                return PlatformModalPage<dynamic>(
                  key: key,
                  child: child,
                );
              },
              buildWidget: (context, data) => const ADCScreen(),
            );
          });
        });
      });
    });
  });
}
