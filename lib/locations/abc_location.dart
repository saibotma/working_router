import 'package:navigator_test/locations/location.dart';

import 'ab_location.dart';

class ABCLocation extends Location {
  @override
  Location pop() {
    return ABLocation();
  }
}
