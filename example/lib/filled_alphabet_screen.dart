import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'abc_screen.dart';
import 'adc_screen.dart';
import 'inner_shell_screen.dart';

final abcId = NodeId<ABCRouteNode>();
final adcId = NodeId<ADCRouteNode>();
final adShellId = NodeId<ADNestedRouteNode>();

class ABRouteNode extends Location<ABRouteNode> {
  final WorkingRouterKey rootRouterKey;

  ABRouteNode({
    super.id,
    super.parentRouterKey,
    required this.rootRouterKey,
  });

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('b');
    builder.content = Content.widget(const FilledAlphabetScreen());
    builder.children = [
      ABCRouteNode(
        id: abcId,
        parentRouterKey: rootRouterKey,
      ),
    ];
  }
}

class ADRouteNode extends Location<ADRouteNode> {
  final WorkingRouterKey rootRouterKey;
  final WorkingRouterKey? outerShellRouterKey;

  ADRouteNode({
    super.id,
    super.parentRouterKey,
    required this.rootRouterKey,
    this.outerShellRouterKey,
  });

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('d');
    builder.content = Content.widget(const FilledAlphabetScreen());
    builder.children = [
      ADCRouteNode(
        id: adcId,
        parentRouterKey: rootRouterKey,
      ),
      if (outerShellRouterKey != null)
        ADNestedRouteNode(
          id: adShellId,
          parentRouterKey: outerShellRouterKey,
        ),
    ];
  }
}

class FilledAlphabetScreen extends StatelessWidget {
  const FilledAlphabetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: Colors.blueGrey,
        child: Column(
          children: [
            MaterialButton(
              child: const Text('push'),
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, _, __) => const Placeholder(),
                  ),
                );
              },
            ),
            const BackButton(),
          ],
        ),
      ),
    );
  }
}
