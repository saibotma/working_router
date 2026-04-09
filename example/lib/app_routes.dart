import 'package:working_router/working_router.dart';

import 'location_id.dart';
import 'locations.dart';
import 'nested_screen.dart';
import 'responsive.dart';
import 'splash_screen.dart';

part 'app_routes.g.dart';

@Locations()
List<LocationTreeElement<LocationId>> buildLocations({
  required ScreenSize screenSize,
  required WorkingRouterKey rootRouterKey,
}) {
  return [
    SplashLocation(
      id: LocationId.splash,
      build: (builder, location) {
        builder.widget(const SplashScreen());

        if (screenSize == ScreenSize.small) {
          builder.children = [
            ALocation(
              id: LocationId.a,
              rendersStandaloneSidebar: true,
              rootRouterKey: rootRouterKey,
            ),
          ];
          return;
        }

        builder.children = [
          Shell(
            build: (builder, routerKey) {
              builder.widgetBuilder(
                (context, data, child) => NestedScreen(child: child),
              );

              builder.children = [
                ALocation(
                  id: LocationId.a,
                  rendersStandaloneSidebar: false,
                  rootRouterKey: rootRouterKey,
                  outerShellRouterKey: routerKey,
                ),
              ];
            },
          ),
        ];
      },
    ),
  ];
}
