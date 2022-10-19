import 'package:flutter/material.dart';
import 'package:navigator_test/appella_router_delegate.dart';
import 'package:navigator_test/my_route_information_parser.dart';
import 'package:navigator_test/my_router.dart';
import 'package:navigator_test/platform_modal/platform_modal_page.dart';
import 'package:navigator_test/responsive.dart';

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
  final myRouter = MyRouter();

  @override
  Widget build(BuildContext context) {
    return MyRouterProvider(
      myRouter: myRouter,
      child: Responsive(
        builder: (context, size) => _DependentMaterialApp(
          router: myRouter,
          screenSize: size,
        ),
      ),
    );
  }
}

class _DependentMaterialApp extends StatefulWidget {
  final MyRouter router;
  final ScreenSize screenSize;

  const _DependentMaterialApp({
    required this.router,
    required this.screenSize,
    Key? key,
  }) : super(key: key);

  @override
  State<_DependentMaterialApp> createState() => _DependentMaterialAppState();
}

class _DependentMaterialAppState extends State<_DependentMaterialApp> {
  final splashPage = const MaterialPage(child: Text("Splash screen"));
  final nestedPage =
      MaterialPage(key: UniqueKey(), child: const NestedScreen());
  final dialogPage = PlatformModalPage(
      child: Container(color: Colors.white, width: 300, height: 300));
  final fullScreenDialogPage = MaterialPage(
      child: Container(color: Colors.white, width: 300, height: 300));
  final notFoundPage = const MaterialPage(child: Text("Not found"));

  final routeInformationParser = MyRouteInformationParser();

  late final _routerDelegate = AppellaRouterDelegate(
    isRootRouter: true,
    myRouter: widget.router,
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
        return [
          nestedPage,
          if (widget.screenSize == ScreenSize.Large) ...[
            dialogPage
          ] else ...[
            fullScreenDialogPage
          ],
        ];
      }

      if (location is NotFoundLocation) {
        return [notFoundPage];
      }

      throw Exception("Unknown location");
    },
  );

  @override
  void didUpdateWidget(covariant _DependentMaterialApp oldWidget) {
    if (oldWidget.screenSize != widget.screenSize) {
      _routerDelegate.refresh();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerDelegate: _routerDelegate,
      routeInformationParser: routeInformationParser,
    );
  }
}
