import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import 'location_id.dart';
import '../locations/a_location.dart';
import '../locations/ab_location.dart';
import '../locations/abc_location.dart';
import '../locations/ad_location.dart';
import '../locations/adc_location.dart';
import '../locations/splash_location.dart';
import '../nested_screen.dart';
import '../platform_modal/platform_modal_page.dart';
import 'responsive.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Responsive(
      builder: (context, size) {
        return _DependentMaterialApp(screenSize: size);
      },
    );
  }
}

class _DependentMaterialApp extends StatefulWidget {
  final ScreenSize screenSize;

  const _DependentMaterialApp({
    required this.screenSize,
    Key? key,
  }) : super(key: key);

  @override
  State<_DependentMaterialApp> createState() => _DependentMaterialAppState();
}

class _DependentMaterialAppState extends State<_DependentMaterialApp> {
  late final router = WorkingRouter<LocationId>(
      locationTree: SplashLocation(
    id: LocationId.splash,
    children: [
      ALocation(
        id: LocationId.a,
        children: [
          ABLocation(
            id: LocationId.ab,
            children: [
              ABCLocation(id: LocationId.abc, children: []),
            ],
          ),
          ADLocation(
            id: LocationId.ad,
            children: [
              ADCLocation(id: LocationId.adc, children: []),
            ],
          ),
        ],
      ),
    ],
  ));

  final splashPage = LocationPageSkeleton<LocationId>(
    child: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: MaterialButton(
              child: const Text("Splash screen"),
              onPressed: () {
                WorkingRouter.of<LocationId>(context).routeToId(LocationId.a);
              },
            ),
          );
        },
      ),
    ),
  );

  final nestedPage = LocationPageSkeleton<LocationId>(
    buildPage: (key, child) => MaterialPage<dynamic>(key: key, child: child),
    buildKey: (location) => ValueKey(location),
    child: const NestedScreen(),
  );

  final dialogPage = LocationPageSkeleton<LocationId>(
    buildPage: (_, child) => PlatformModalPage<dynamic>(child: child),
    child: Builder(
      builder: (context) {
        final router = WorkingRouter.of<LocationId>(context);
        return Container(
          color: Colors.white,
          width: 300,
          height: 300,
          child: Text(
            "${router.data!.pathParameters["id"]}, "
            "${router.data!.queryParameters["b"]}, "
            "${router.data!.queryParameters["c"]}",
          ),
        );
      },
    ),
  );

  final fullScreenDialogPage = LocationPageSkeleton<LocationId>(
    child: Container(color: Colors.white, width: 300, height: 300),
  );

  final conditionalDialogPage = LocationPageSkeleton<LocationId>(
    buildPage: (_, child) => PlatformModalPage<dynamic>(child: child),
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

  late final _routerDelegate = WorkingRouterDelegate(
    isRootRouter: true,
    router: router,
    buildPages: (location, topLocation) {
      if (location.id == LocationId.splash &&
          topLocation.id == LocationId.splash) {
        return [splashPage];
      }
      if (location.id == LocationId.a) {
        return [nestedPage];
      }
      if (location.id == LocationId.abc) {
        if (widget.screenSize == ScreenSize.large) {
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
