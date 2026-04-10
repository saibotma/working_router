import 'package:working_router/working_router.dart';

import 'abc_screen.dart';
import 'adc_screen.dart';
import 'alphabet_sidebar_screen.dart';
import 'empty_alphabet_screen.dart';
import 'filled_alphabet_screen.dart';
import 'inner_shell_root_screen.dart';
import 'inner_shell_screen.dart';
import 'location_id.dart';
import 'platform_modal/platform_modal_page.dart';
import 'pop_until_target.dart';
import 'shell_bypass_screen.dart';

class SplashLocation extends Location<LocationId, SplashLocation> {
  SplashLocation({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ABLocation extends Location<LocationId, ABLocation> {
  ABLocation({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ABCLocation extends Location<LocationId, ABCLocation> {
  ABCLocation({
    super.id,
    required super.parentRouterKey,
    required super.build,
  });
}

class ADLocation extends Location<LocationId, ADLocation> {
  ADLocation({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADShellLocation extends Location<LocationId, ADShellLocation> {
  ADShellLocation({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADCLocation extends Location<LocationId, ADCLocation> {
  ADCLocation({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADELocation extends Location<LocationId, ADELocation> {
  ADELocation({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ALocation extends Location<LocationId, ALocation> {
  final bool rendersStandaloneSidebar;
  final WorkingRouterKey rootRouterKey;
  final WorkingRouterKey? outerShellRouterKey;

  ALocation({
    super.id,
    super.parentRouterKey,
    required this.rendersStandaloneSidebar,
    required this.rootRouterKey,
    this.outerShellRouterKey,
  }) : super.override(
          tags: [PopUntilTarget()],
        );

  @override
  void build(LocationBuilder<LocationId> builder) {
    builder.pathLiteral('a');
    builder.widget(
      rendersStandaloneSidebar
          ? const AlphabetSidebarScreen()
          : const EmptyAlphabetScreen(),
    );

    builder.children = [
      ABLocation(
        id: LocationId.ab,
        build: (builder, location) {
          builder.pathLiteral('b');
          builder.widget(const FilledAlphabetScreen());

          builder.children = [
            ABCLocation(
              id: LocationId.abc,
              parentRouterKey: rootRouterKey,
              build: (builder, location) {
                builder.pathLiteral('c');
                final id = builder.stringPathParam();
                final bParam = builder.stringQueryParam('b');
                final cParam = builder.stringQueryParam('c');

                builder.widgetBuilder((context, data) {
                  return ABCScreen(
                    id: data.pathParam(id),
                    b: data.queryParam(bParam),
                    c: data.queryParam(cParam),
                  );
                });
                builder.page((key, child) {
                  return PlatformModalPage<dynamic>(key: key, child: child);
                });
              },
            ),
          ];
        },
      ),
      ADLocation(
        id: LocationId.ad,
        build: (builder, location) {
          builder.pathLiteral('d');
          builder.widget(const FilledAlphabetScreen());

          builder.children = [
            ADCLocation(
              id: LocationId.adc,
              parentRouterKey: rootRouterKey,
              build: (builder, location) {
                builder.pathLiteral('c');
                builder.widget(const ADCScreen());
                builder.page((key, child) {
                  return PlatformModalPage<dynamic>(key: key, child: child);
                });
              },
            ),
            if (outerShellRouterKey != null)
              Shell(
                build: (builder, shell, routerKey) {
                  builder.widgetBuilder(
                    (context, data, child) => InnerShellScreen(child: child),
                  );

                  builder.children = [
                    ADShellLocation(
                      id: LocationId.adShell,
                      build: (builder, location) {
                        builder.widget(const InnerShellRootScreen());

                        builder.children = [
                          ADELocation(
                            id: LocationId.ade,
                            parentRouterKey: outerShellRouterKey ?? routerKey,
                            build: (builder, location) {
                              builder.pathLiteral('e');
                              builder.widget(const ShellBypassScreen());
                            },
                          ),
                        ];
                      },
                    ),
                  ];
                },
              ),
          ];
        },
      ),
    ];
  }
}
