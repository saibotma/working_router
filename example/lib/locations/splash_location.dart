import 'package:working_router/working_router.dart';

import '../location_id.dart';

class SplashLocation extends Location<LocationId> {
  SplashLocation({required super.id, required super.children});

  @override
  String get path => "/";
}
