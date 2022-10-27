import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ALocation extends Location<LocationId> {
  ALocation({required super.id, required super.children});

  @override
  Location<LocationId>? pop() {
    return null;
  }

  @override
  IMap<String, String> selectQueryParameters(IMap<String, String> source) {
    return {"afterUpdate": "true"}.toIMap();
  }

  @override
  String get path => "/a";
}
