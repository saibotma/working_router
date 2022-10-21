import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ALocation extends Location<LocationId> {
  ALocation({required super.id, required super.children});

  @override
  Location<LocationId>? pop() {
    return null;
  }

  @override
  String get path => "/a";
}
