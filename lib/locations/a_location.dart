import 'package:navigator_test/locations/location.dart';

class ALocation extends Location {
  @override
  Location pop() {
    return ALocation();
  }
}
