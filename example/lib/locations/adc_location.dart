import 'package:flutter/material.dart';
import 'package:working_router/working_router.dart';

import '../location_id.dart';
import '../platform_modal/platform_modal_page.dart';
import '../pop_until_target.dart';

class ADCLocation extends Location<LocationId> {
  ADCLocation({
    required super.id,
    required super.parentNavigatorKey,
  });

  @override
  List<PathSegment> get path => [literal('c')];

  @override
  bool get buildsOwnPage => true;

  @override
  Page<dynamic> buildPage(LocalKey? key, Widget child) {
    return PlatformModalPage<dynamic>(key: key, child: child);
  }

  @override
  Widget buildWidget(BuildContext context, WorkingRouterData<LocationId> data) {
    return Material(
      color: Colors.green,
      child: SizedBox(
        width: 300,
        height: 300,
        child: LocationObserver(
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
                      child: const Text('Press to allow pop.'),
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
          child: Center(
            child: MaterialButton(
              child: const Text('Press to pop to FallbackLocation.'),
              onPressed: () {
                WorkingRouter.of<LocationId>(context).routeBackUntil(
                  (location) => location.hasTag(PopUntilTarget()),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
