import 'package:navigator_test/locations/location.dart';
import 'package:navigator_test/my_router.dart';

class SplashLocation extends Location<LocationId> {
  SplashLocation({required super.id, required super.children});

  @override
  Location? pop() {
    return null;
  }

  @override
  String get path => "/";
}
