import 'package:working_router/working_router.dart';

import 'abc_screen.dart';
import 'adc_screen.dart';
import 'alphabet_sidebar_screen.dart';
import 'empty_alphabet_screen.dart';
import 'filled_alphabet_screen.dart';
import 'inner_shell_root_screen.dart';
import 'inner_shell_screen.dart';
import 'platform_modal/platform_modal_page.dart';
import 'pop_until_target.dart';
import 'shell_bypass_screen.dart';

final splashId = NodeId<SplashNode>();
final aId = NodeId<ANode>();
final abId = NodeId<ABNode>();
final abcId = NodeId<ABCNode>();
final adId = NodeId<ADNode>();
final adcId = NodeId<ADCNode>();
final adShellId = NodeId<ADNestedNode>();
final adeId = NodeId<ADENode>();

class SplashNode extends Location<SplashNode> {
  SplashNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ABNode extends Location<ABNode> {
  ABNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ABCNode extends Location<ABCNode> {
  ABCNode({
    super.id,
    required super.parentRouterKey,
    required super.build,
  });
}

class ADNode extends Location<ADNode> {
  ADNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADNestedNode extends ShellLocation<ADNestedNode> {
  ADNestedNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADCNode extends Location<ADCNode> {
  ADCNode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ADENode extends Location<ADENode> {
  ADENode({
    super.id,
    super.parentRouterKey,
    required super.build,
  });
}

class ANode extends AbstractLocation<ANode> {
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
  void build(LocationBuilder builder) {
    builder.pathLiteral('a');
    builder.content = Content.widget(
      rendersStandaloneSidebar
          ? const AlphabetSidebarScreen()
          : const EmptyAlphabetScreen(),
    );

    builder.children = [
      ABNode(
        id: abId,
        build: (builder, location) {
          builder.pathLiteral('b');
          builder.content = Content.widget(const FilledAlphabetScreen());

          builder.children = [
            ABCNode(
              id: abcId,
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
        id: adId,
        build: (builder, location) {
          builder.pathLiteral('d');
          builder.content = Content.widget(const FilledAlphabetScreen());

          builder.children = [
            ADCNode(
              id: adcId,
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
                id: adShellId,
                build: (builder, location, routerKey) {
                  builder.shellContent = ShellContent.builder(
                    (context, data, child) => InnerShellScreen(child: child),
                  );
                  builder.content = Content.widget(
                    const InnerShellRootScreen(),
                  );

                  builder.children = [
                    ADENode(
                      id: adeId,
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
