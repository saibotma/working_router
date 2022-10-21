import 'package:flutter/material.dart';
import 'package:navigator_test/appella_router_delegate.dart';
import 'package:navigator_test/location_guard.dart';
import 'package:navigator_test/locations/adc_location.dart';
import 'package:navigator_test/my_route_information_parser.dart';
import 'package:navigator_test/my_router.dart';
import 'package:navigator_test/platform_modal/platform_modal_page.dart';
import 'package:navigator_test/responsive.dart';

import 'locations/location.dart';
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
    return MyRouterDataProvider(
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
  final splashPage = LocationPageSkeleton(
    child: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: MaterialButton(
              child: const Text("Splash screen"),
              onPressed: () {
                MyRouter.of(context).routeToId(LocationId.a);
              },
            ),
          );
        },
      ),
    ),
  );

  final nestedPage = LocationPageSkeleton(
    buildPage: (key, child) => MaterialPage(key: key, child: child),
    buildKey: (location) => ValueKey(location),
    child: const NestedScreen(),
  );

  final dialogPage = LocationPageSkeleton(
    buildPage: (_, child) => PlatformModalPage(child: child),
    child: Builder(
      builder: (context) {
        final myRouter = MyRouter.of(context);
        return Container(
          color: Colors.white,
          width: 300,
          height: 300,
          child: Text(
            "${myRouter.currentPath!.queryParameters["b"]}, ${myRouter.currentPath!.queryParameters["c"]}",
          ),
        );
      },
    ),
  );

  final fullScreenDialogPage = LocationPageSkeleton(
    child: Container(color: Colors.white, width: 300, height: 300),
  );

  final conditionalDialogPage = LocationPageSkeleton(
    buildPage: (_, child) => PlatformModalPage(child: child),
    child: Builder(
      builder: (context) {
        return LocationGuard(
          mayLeave: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) {
                return Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    color: Colors.white,
                    child: MaterialButton(onPressed: () {
                      Navigator.of(context).pop(true);
                    }),
                  ),
                );
              },
            );
            return result ?? false;
          },
          child: Container(color: Colors.black, width: 300, height: 300),
        );
      },
    ),
  );

  final routeInformationParser = MyRouteInformationParser();

  late final _routerDelegate = AppellaRouterDelegate(
    isRootRouter: true,
    myRouter: widget.router,
    buildPages: (location, topLocation) {
      if (location.id == LocationId.splash &&
          topLocation.id == LocationId.splash) {
        return [splashPage];
      }
      if (location.id == LocationId.a) {
        return [nestedPage];
      }
      if (location.id == LocationId.abc) {
        if (widget.screenSize == ScreenSize.Large) {
          return [dialogPage];
        } else {
          return [fullScreenDialogPage];
        }
      }

      if (location.id == LocationId.adc) {
        return [conditionalDialogPage];
      }

      return [];
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
