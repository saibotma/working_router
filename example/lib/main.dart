import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../locations/a_location.dart';
import '../locations/ab_location.dart';
import '../locations/abc_location.dart';
import '../locations/ad_location.dart';
import '../locations/adc_location.dart';
import '../locations/splash_location.dart';
import '../nested_screen.dart';
import '../platform_modal/platform_modal_page.dart';
import 'location_id.dart';
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
    noContentWidget: const Text("No content"),
    buildLocationTree: () {
      return SplashLocation(
        id: LocationId.splash,
        children: [
          ALocation(
            id: LocationId.a,
            tags: [PopUntilTarget()],
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
      );
    },
    buildRootPages: (_, location, data) {
      if (location.id == LocationId.splash &&
          data.activeLocation.id == LocationId.splash) {
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

  final splashPage = ChildLocationPageSkeleton<LocationId>(
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

  final emptyPage = ChildLocationPageSkeleton<LocationId>(
    child: Container(color: Colors.white, child: const Text("Empty page")),
  );

  final filledPage = ChildLocationPageSkeleton<LocationId>(
    child: Scaffold(
      body: Container(
        color: Colors.blueGrey,
        child: Column(
          children: [
            Builder(builder: (context) {
              return MaterialButton(
                  child: const Text("push"),
                  onPressed: () {
                    Navigator.of(context).push(PageRouteBuilder(
                        pageBuilder: (context, _, __) => const Placeholder()));
                  });
            }),
            const BackButton(),
          ],
        ),
      ),
    ),
  );

  late final LocationPageSkeleton<LocationId> nestedPage =
      NestedLocationPageSkeleton<LocationId>(
    router: router,
    buildPages: (_, location, topLocation) {
      if (location is ABLocation ||
          location is ABCLocation ||
          location is ADLocation ||
          location is ADCLocation) {
        return [filledPage];
      }

      return [emptyPage];
    },
    buildPage: (key, child) => MaterialPage<dynamic>(key: key, child: child),
    buildKey: (location) => ValueKey(location),
    builder: (context, child) {
      return LocationGuard(
        afterUpdate: () {
          print(
            "after update: "
            "${WorkingRouterData.of<LocationId>(context).queryParameters["afterUpdate"]}",
          );
        },
        child: NestedScreen(child: child),
      );
    },
  );

  final dialogPage = ChildLocationPageSkeleton<LocationId>(
    buildPage: (key, child) =>
        PlatformModalPage<dynamic>(key: key, child: child),
    child: Builder(
      builder: (context) {
        final data = WorkingRouterData.of<LocationId>(context);
        return Container(
          color: Colors.white,
          width: 300,
          height: 300,
          child: Text(
            "${data.pathParameters["id"]}, "
            "${data.queryParameters["b"]}, "
            "${data.queryParameters["c"]}",
          ),
        );
      },
    ),
  );

  final fullScreenDialogPage = ChildLocationPageSkeleton<LocationId>(
    child: Builder(
      builder: (context) {
        final data = WorkingRouterData.of<LocationId>(context);
        return Container(
          color: Colors.white,
          width: 300,
          height: 300,
          child: Text(
            "${data.pathParameters["id"]}, "
            "${data.queryParameters["b"]}, "
            "${data.queryParameters["c"]}",
          ),
        );
      },
    ),
  );

  final conditionalDialogPage = ChildLocationPageSkeleton<LocationId>(
    buildPage: (_, child) => PlatformModalPage<dynamic>(child: child),
    child: Builder(
      builder: (context) {
        return LocationGuard(
          beforeLeave: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) {
                return Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    color: Colors.white,
                    child: MaterialButton(
                      child: const Text("Press to allow pop."),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ),
                );
              },
            );
            return result ?? false;
          },
          child: Container(
            color: Colors.green,
            width: 300,
            height: 300,
            child: MaterialButton(
              child: const Text("Press to pop to FallbackLocation."),
              onPressed: () {
                WorkingRouter.of<LocationId>(context).routeBackUntil(
                    (location) => location.hasTag(PopUntilTarget()));
              },
            ),
          ),
        );
      },
    ),
  );

  @override
  void didUpdateWidget(covariant _DependentMaterialApp oldWidget) {
    if (oldWidget.screenSize != widget.screenSize) {
      router.refresh();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: router);
  }
}

class PopUntilTarget extends LocationTag {}
