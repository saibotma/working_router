import 'package:flutter/material.dart';
import 'package:navigator_test/appella_router_delegate.dart';
import 'package:navigator_test/location_guard.dart';
import 'package:navigator_test/locations/adc_location.dart';
import 'package:navigator_test/my_route_information_parser.dart';
import 'package:navigator_test/my_router.dart';
import 'package:navigator_test/platform_modal/platform_modal_page.dart';
import 'package:navigator_test/responsive.dart';

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
  final conditionalDialogPage = PlatformModalPage(
    child: Builder(builder: (context) {
      return LocationGuard(
        guard: (location) => location is ADCLocation,
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
    }),
  );

  final routeInformationParser = MyRouteInformationParser();

  late final _routerDelegate = AppellaRouterDelegate(
    isRootRouter: true,
    myRouter: widget.router,
    buildPages: (locations) {
      if (locations.isEmpty) {
        return [notFoundPage];
      }

      final location = locations.last;
      if (location.id == LocationId.splash) {
        return [splashPage];
      }
      if (location.id == LocationId.a ||
          location.id == LocationId.ab ||
          location.id == LocationId.ad) {
        return [nestedPage];
      }
      if (location.id == LocationId.abc) {
        return [
          nestedPage,
          if (widget.screenSize == ScreenSize.Large) ...[
            dialogPage
          ] else ...[
            fullScreenDialogPage
          ],
        ];
      }

      if (location.id == LocationId.adc) {
        return [nestedPage, conditionalDialogPage];
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
