import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ADPLocation extends Location<LocationId> {
  ADPLocation({required super.id, required super.children});

  @override
  String get path => "/p";
}
