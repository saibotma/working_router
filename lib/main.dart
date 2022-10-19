import 'package:flutter/material.dart';
import 'package:navigator_test/appella_router_delegate.dart';
import 'package:navigator_test/my_route_information_parser.dart';
import 'package:navigator_test/my_router.dart';
import 'package:navigator_test/platform_modal/platform_modal_page.dart';

import 'locations/a_location.dart';
import 'locations/ab_location.dart';
import 'locations/abc_location.dart';
import 'locations/ad_location.dart';
import 'locations/adc_location.dart';
import 'locations/not_found_location.dart';
import 'locations/splash_location.dart';
import 'nested_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final splashPage = const MaterialPage(child: Text("Splash screen"));
  final nestedPage =
      MaterialPage(key: UniqueKey(), child: const NestedScreen());
  final dialogPage = PlatformModalPage(
      child: Container(color: Colors.white, width: 300, height: 300));
  final notFoundPage = const MaterialPage(child: Text("Not found"));

  final myRouter = MyRouter();
  late final routerDelegate = AppellaRouterDelegate(
    isRootRouter: true,
    myRouter: myRouter,
    buildPages: (location) {
      if (location is SplashLocation) {
        return [splashPage];
      }
      if (location is ALocation ||
          location is ABLocation ||
          location is ADLocation) {
        return [nestedPage];
      }
      if (location is ABCLocation || location is ADCLocation) {
        return [nestedPage, dialogPage];
      }

      if (location is NotFoundLocation) {
        return [notFoundPage];
      }

      throw Exception("Unknown location");
    },
  );
  final routeInformationParser = MyRouteInformationParser();

  @override
  Widget build(BuildContext context) {
    return MyRouterProvider(
      myRouter: myRouter,
      child: MaterialApp.router(
        routerDelegate: routerDelegate,
        routeInformationParser: routeInformationParser,
      ),
    );
  }
}
