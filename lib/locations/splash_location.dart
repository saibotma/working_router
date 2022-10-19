import 'package:navigator_test/locations/location.dart';

class SplashLocation extends Location {
  @override
  Location pop() {
    return SplashLocation();
  }
}
