import 'package:example/state_preserving_tabs/scaffold_location.dart';
import 'package:example/state_preserving_tabs/tab1_location.dart';
import 'package:example/state_preserving_tabs/tab2_location.dart';
import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

// A better solution would be to use the Restoration API, however it is
// currently not possible to restore any StatefulWidget at runtime:
// https://github.com/flutter/flutter/issues/80303
//
// Another solution to test out would be this draft:
// https://github.com/lulupointu/vrouter/issues/32#issuecomment-816510075

void main() {
  runApp(const StatePreservingTabs());
}

List<RouteNode> buildRouteNodes(WorkingRouterKey _) => [
      ScaffoldNode(
        childNodes: [
          Tab1Node(),
          Tab2Node(),
        ],
      ),
    ];

class StatePreservingTabs extends StatefulWidget {
  const StatePreservingTabs({super.key});

  @override
  State<StatePreservingTabs> createState() => _StatePreservingTabsState();
}

class _StatePreservingTabsState extends State<StatePreservingTabs> {
  final tab1RouterKey = WorkingRouterKey();
  final tab2RouterKey = WorkingRouterKey();

  late final WorkingRouter router = WorkingRouter(
    noContentWidget: const Text("No content"),
    buildRouteNodes: buildRouteNodes,
    buildRootPages: (_, location, data) {
      // Need to have one nested navigator for each tab, because otherwise
      // the same navigator (with the same global navigator key) would be
      // inside the IndexedStack which flutter does not allow.
      // This also has the added benefit, that this could be extended to also
      // not just persist widget state, but also the route state per
      // nested navigator like it is done here:
      // https://github.com/lulupointu/vrouter/issues/32#issuecomment-884901775
      final leaf = data.leaf;

      if (location is ScaffoldNode &&
          leaf is Tab1Node &&
          data.isChildOf(
            (candidate) => candidate is ScaffoldNode,
            leaf,
          )) {
        return [buildScaffoldPage(index: 0)];
      }

      if (location is ScaffoldNode &&
          leaf is Tab2Node &&
          data.isChildOf(
            (candidate) => candidate is ScaffoldNode,
            leaf,
          )) {
        return [buildScaffoldPage(index: 1)];
      }

      return [];
    },
  );

  LocationPageSkeleton buildScaffoldPage({required int index}) {
    return NestedLocationPageSkeleton(
      router: router,
      routerKey: index == 0 ? tab1RouterKey : tab2RouterKey,
      buildChild: (context, _, child) {
        return StatePreservingScaffold(index: index, child: child);
      },
      buildPages: (_, location, routerData) {
        // Return the correct tab page depending on the index.
        // Have to return the tab for the index, also when another index
        // is currently active, because also the "temporarily deactivated"
        // navigators will still be active in the IndexedStack.
        if ((location is Tab1Node) && index == 0) {
          return [tab1Page];
        }
        if ((location is Tab2Node) && index == 1) {
          return [tab2Page];
        }
        return [emptyPage];
      },
    );
  }

  final emptyPage =
      ChildLocationPageSkeleton(child: const Placeholder());
  // Give each tab page a unique key, so that it does not get rebuilt
  // (and thus looses state) when switching between tabs. This is required,
  // because tab1Page will also be returned (above) when Tab2Node is active
  // and vice versa.
  final tab1Page = ChildLocationPageSkeleton(
    buildPageKey: (_, __) => const ValueKey("tab1"),
    child: const ScreenWithState(color: Colors.red),
  );
  final tab2Page = ChildLocationPageSkeleton(
    buildPageKey: (_, __) => const ValueKey("tab2"),
    child: const ScreenWithState(color: Colors.blue),
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
  final Widget child;

  const StatePreservingScaffold({
    required this.index,
    required this.child,
    super.key,
  });

  @override
  State<StatePreservingScaffold> createState() =>
      _StatePreservingScaffoldState();
}

class _StatePreservingScaffoldState extends State<StatePreservingScaffold> {
  List<Widget> tabs = [const SizedBox(), const SizedBox()];

  @override
  Widget build(BuildContext context) {
    final router = WorkingRouter.of(context);

    // Got the tab logic from:
    // https://github.com/lulupointu/vrouter/issues/32#issuecomment-884901775
    tabs[widget.index] = widget.child;

    return Scaffold(
      body: IndexedStack(index: widget.index, children: tabs),
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
