import 'package:flutter/material.dart';
import '../working_router.dart';

class LocationPageSkeleton<ID> {
  final Widget child;
  final Page<dynamic> Function(LocalKey? key, Widget child)? buildPage;
  final LocalKey Function(Location<ID> location)? buildKey;

  LocationPageSkeleton({required this.child, this.buildPage, this.buildKey});

  LocationPage inflate({
    required WorkingRouterData<ID> data,
    required Location<ID> location,
    required WorkingRouter<ID> router,
  }) {
    final wrappedChild = WorkingRouterDataProvider(
      router: router,
      data: data,
      location: location,
      child: NearestLocation<ID>(location: location, child: child),
    );
    final key = buildKey?.call(location);
    return LocationPage(
      buildPage?.call(key, wrappedChild) ??
          MaterialPage<dynamic>(key: key, child: wrappedChild),
    );
  }
}
