import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

// A better solution would be to use the Restoration API, however it is
// currently not possible to restore any StatefulWidget at runtime:
// https://github.com/flutter/flutter/issues/80303
//
// Another solution to test out would be this draft:
// https://github.com/lulupointu/vrouter/issues/32#issuecomment-816510075

class ScaffoldRouteNode extends AbstractMultiShell<ScaffoldRouteNode> {
  @override
  void build(MultiShellBuilder builder) {
    final tab1Slot = builder.slot(
      debugLabel: 'tab1',
      defaultContent: DefaultContent.widget(
        const ScreenWithState(color: Colors.red),
      ),
      defaultPage: (key, child) {
        return MaterialPage<dynamic>(key: key, child: child);
      },
    );
    final tab2Slot = builder.slot(
      debugLabel: 'tab2',
      defaultContent: DefaultContent.widget(
        const ScreenWithState(color: Colors.blue),
      ),
      defaultPage: (key, child) {
        return MaterialPage<dynamic>(key: key, child: child);
      },
    );
    builder.content = MultiShellContent.builder((context, data, slots) {
      final index = data.leaf is Tab2RouteNode ? 1 : 0;
      return StatePreservingScaffold(
        index: index,
        children: [
          slots.child(tab1Slot),
          slots.child(tab2Slot),
        ],
      );
    });
    builder.children = [
      Tab1RouteNode(parentRouterKey: tab1Slot.routerKey),
      Tab2RouteNode(parentRouterKey: tab2Slot.routerKey),
    ];
  }
}

class Tab1RouteNode extends Location<Tab1RouteNode> {
  Tab1RouteNode({super.parentRouterKey});

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('tab1');
    builder.pageKey = PageKey.custom((_) => const ValueKey('tab1'));
    builder.content = Content.widget(
      const ScreenWithState(color: Colors.red),
    );
  }
}

class Tab2RouteNode extends Location<Tab2RouteNode> {
  Tab2RouteNode({super.parentRouterKey});

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('tab2');
    builder.pageKey = PageKey.custom((_) => const ValueKey('tab2'));
    builder.content = Content.widget(
      const ScreenWithState(color: Colors.blue),
    );
  }
}

void main() {
  runApp(const StatePreservingTabs());
}

List<RouteNode> buildRouteNodes(WorkingRouterKey _) => [
      ScaffoldRouteNode(),
    ];

class StatePreservingTabs extends StatefulWidget {
  const StatePreservingTabs({super.key});

  @override
  State<StatePreservingTabs> createState() => _StatePreservingTabsState();
}

class _StatePreservingTabsState extends State<StatePreservingTabs> {
  late final WorkingRouter router = WorkingRouter(
    noContentWidget: const Text("No content"),
    buildRouteNodes: buildRouteNodes,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: router);
  }
}

class ScreenWithState extends StatefulWidget {
  final Color color;

  const ScreenWithState({required this.color, super.key});

  @override
  State<ScreenWithState> createState() => _ScreenWithStateState();
}

class _ScreenWithStateState extends State<ScreenWithState> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.color,
      child: Column(
        children: [
          // ignore: deprecated_member_use
          Text("${widget.color.value}: ${counter.toString()}"),
          MaterialButton(
            onPressed: () => setState(() => counter++),
            child: const Text("Count"),
          ),
        ],
      ),
    );
  }
}

class StatePreservingScaffold extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const StatePreservingScaffold({
    required this.index,
    required this.children,
    super.key,
  });

  @override
  State<StatePreservingScaffold> createState() =>
      _StatePreservingScaffoldState();
}

class _StatePreservingScaffoldState extends State<StatePreservingScaffold> {
  @override
  Widget build(BuildContext context) {
    final router = WorkingRouter.of(context);

    // Got the tab logic from:
    // https://github.com/lulupointu/vrouter/issues/32#issuecomment-884901775
    return Scaffold(
      body: IndexedStack(index: widget.index, children: widget.children),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.ice_skating),
            label: "Tab1",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_alarm),
            label: "Tab2",
          )
        ],
        onTap: (index) {
          if (index == 0) {
            router.routeToUriString("/tab1");
          } else {
            router.routeToUriString("/tab2");
          }
        },
      ),
    );
  }
}
