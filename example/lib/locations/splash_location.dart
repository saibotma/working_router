import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../app_routes.dart';
import '../location_id.dart';
import 'alphabet_shell.dart';

class SplashLocation extends Location<LocationId> {
  final GlobalKey<NavigatorState> rootNavigatorKey;
  final GlobalKey<NavigatorState> alphabetNavigatorKey;

  SplashLocation({
    required super.id,
    required this.rootNavigatorKey,
    required this.alphabetNavigatorKey,
  });

  @override
  late final children = [
    AlphabetShell(
      navigatorKey: alphabetNavigatorKey,
      rootNavigatorKey: rootNavigatorKey,
    ),
  ];

  @override
  List<PathSegment> get path => const [];

  @override
  bool get buildsOwnPage => true;

  @override
  Widget buildWidget(BuildContext context, WorkingRouterData<LocationId> data) {
    final router = WorkingRouter.of<LocationId>(context);

    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            router.routeToA();
          },
          child: const Text('Splash screen'),
        ),
      ),
    );
  }
}
