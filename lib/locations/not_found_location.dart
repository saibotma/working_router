import 'package:navigator_test/locations/location.dart';

class NotFoundLocation extends Location {
  @override
  Location pop() {
    return NotFoundLocation();
  }
}
