import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ALocation extends Location<LocationId> {
  ALocation({required super.id, required super.children, super.tags});

  @override
  Location<LocationId>? pop() {
    return null;
  }

  @override
  String get path => "/a";
}
