import 'package:navigator_test/locations/ad_location.dart';
import 'package:navigator_test/locations/location.dart';

class ADCLocation extends Location {
  @override
  Location pop() {
    return ADLocation();
  }
}
