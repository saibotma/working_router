import 'package:navigator_test/locations/location.dart';

class ADLocation extends Location {
  @override
  Location pop() {
    return ADLocation();
  }
}
