import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ADCLocation extends Location<LocationId> {
  ADCLocation({required super.id, required super.children});

  @override
  String get path => "/c";
}
