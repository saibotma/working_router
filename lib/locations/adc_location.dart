import 'package:navigator_test/locations/ad_location.dart';
import 'package:navigator_test/locations/location.dart';

class ADCLocation extends Location {
  ADCLocation({required super.id, required super.children});

  @override
  Location? pop() {
    return null;
  }

  @override
  String get path => "/c";
}
