import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'inner_shell_root_screen.dart';
import 'shell_bypass_screen.dart';

final adeId = NodeId<ADENode>();

class ADNestedNode extends ShellLocation<ADNestedNode> {
  ADNestedNode({
    super.id,
    super.parentRouterKey,
  });

  @override
  void build(ShellLocationBuilder builder) {
    builder.shellContent = ShellContent.builder(
      (context, data, child) => InnerShellScreen(child: child),
    );
    builder.content = Content.widget(const InnerShellRootScreen());
    builder.children = [
      ADENode(
        id: adeId,
        parentRouterKey: parentRouterKey ?? routerKey,
      ),
    ];
  }
}

class InnerShellScreen extends StatelessWidget {
  final Widget child;

  const InnerShellScreen({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFD7EAF8),
      child: Center(
        child: Container(
          width: 520,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FB),
            border: Border.all(
              color: const Color(0xFF4B8DB6),
              width: 4,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF4B8DB6),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: const Text(
                  'Inner shell navigator',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
