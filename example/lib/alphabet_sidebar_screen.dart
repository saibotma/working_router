import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'alphabet_sidebar.dart';
import 'empty_alphabet_screen.dart';
import 'filled_alphabet_screen.dart';
import 'pop_until_target.dart';

final abId = NodeId<ABNode>();
final adId = NodeId<ADNode>();

class ANode extends Location<ANode> {
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
        rootRouterKey: rootRouterKey,
      ),
      ADNode(
        id: adId,
        rootRouterKey: rootRouterKey,
        outerShellRouterKey: outerShellRouterKey,
      ),
    ];
  }
}

class AlphabetSidebarScreen extends StatelessWidget {
  const AlphabetSidebarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AlphabetSidebar(showInnerShellBypassRoute: false),
    );
  }
}
