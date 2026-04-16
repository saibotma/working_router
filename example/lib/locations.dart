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

class SplashNode extends Location<LocationId, SplashNode> {
  SplashNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ABNode extends Location<LocationId, ABNode> {
  ABNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ABCNode extends Location<LocationId, ABCNode> {
  ABCNode({
    super.id,
    required super.parentRouterKey,
    required super.build,
  });
}

class ADNode extends Location<LocationId, ADNode> {
  ADNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADNestedNode extends ShellLocation<LocationId, ADNestedNode> {
  ADNestedNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADCNode extends Location<LocationId, ADCNode> {
  ADCNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADENode extends Location<LocationId, ADENode> {
  ADENode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ANode extends AbstractLocation<LocationId, ANode> {
  final bool rendersStandaloneSidebar;
  final WorkingRouterKey rootRouterKey;
  final WorkingRouterKey? outerShellRouterKey;

  ANode({
    super.id,
    super.parentRouterKey,
    required this.rendersStandaloneSidebar,
    required this.rootRouterKey,
    this.outerShellRouterKey,
  }) : super(
          tags: [PopUntilTarget()],
        );

  @override
  void build(LocationBuilder<LocationId> builder) {
    builder.pathLiteral('a');
    builder.content = Content.widget(
      rendersStandaloneSidebar
          ? const AlphabetSidebarScreen()
          : const EmptyAlphabetScreen(),
    );

    builder.children = [
      ABNode(
        id: LocationId.ab,
        build: (builder, location) {
          builder.pathLiteral('b');
          builder.content = Content.widget(const FilledAlphabetScreen());

          builder.children = [
            ABCNode(
              id: LocationId.abc,
              parentRouterKey: rootRouterKey,
              build: (builder, location) {
                builder.pathLiteral('c');
                final id = builder.stringPathParam();
                final bParam = builder.stringQueryParam('b');
                final cParam = builder.stringQueryParam('c');

                builder.content = Content.builder((context, data) {
                  return ABCScreen(
                    id: data.param(id),
                    b: data.param(bParam),
                    c: data.param(cParam),
                  );
                });
                builder.page = (key, child) {
                  return PlatformModalPage<dynamic>(key: key, child: child);
                };
              },
            ),
          ];
        },
      ),
      ADNode(
        id: LocationId.ad,
        build: (builder, location) {
          builder.pathLiteral('d');
          builder.content = Content.widget(const FilledAlphabetScreen());

          builder.children = [
            ADCNode(
              id: LocationId.adc,
              parentRouterKey: rootRouterKey,
              build: (builder, location) {
                builder.pathLiteral('c');
                builder.content = Content.widget(const ADCScreen());
                builder.page = (key, child) {
                  return PlatformModalPage<dynamic>(key: key, child: child);
                };
              },
            ),
            if (outerShellRouterKey != null)
              ADNestedNode(
                id: LocationId.adShell,
                build: (builder, location, routerKey) {
                  builder.shellContent = ShellContent.builder(
                    (context, data, child) => InnerShellScreen(child: child),
                  );
                  builder.content = Content.widget(
                    const InnerShellRootScreen(),
                  );

                  builder.children = [
                    ADENode(
                      id: LocationId.ade,
                      parentRouterKey: outerShellRouterKey ?? routerKey,
                      build: (builder, location) {
                        builder.pathLiteral('e');
                        builder.content = Content.widget(
                          const ShellBypassScreen(),
                        );
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
