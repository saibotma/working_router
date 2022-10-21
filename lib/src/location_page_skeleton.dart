import 'package:flutter/material.dart';
import 'location.dart';
import 'location_page.dart';
import 'widgets/nearest_location.dart';

class LocationPageSkeleton<ID> {
  final Widget child;
  final Page<dynamic> Function(LocalKey? key, Widget child)? buildPage;
  final LocalKey Function(Location<ID> location)? buildKey;

  LocationPageSkeleton({required this.child, this.buildPage, this.buildKey});

  LocationPage inflate(Location<ID> location) {
    final wrappedChild = NearestLocation<ID>(location: location, child: child);
    final key = buildKey?.call(location);
    return LocationPage(
      buildPage?.call(key, wrappedChild) ??
          MaterialPage<dynamic>(key: key, child: wrappedChild),
    );
  }
}
