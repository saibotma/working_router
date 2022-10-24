import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ADLocation extends Location<LocationId> {
  ADLocation({required super.id, required super.children});

  @override
  String get path => "/d";
}
