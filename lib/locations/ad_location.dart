import 'package:navigator_test/locations/a_location.dart';
import 'package:navigator_test/locations/location.dart';

class ADLocation extends Location {
  @override
  Location pop() {
    return ALocation();
  }
}
