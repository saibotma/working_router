import 'package:navigator_test/locations/a_location.dart';
import 'package:navigator_test/locations/location.dart';

class ADLocation extends Location {
  ADLocation({required super.id, required super.children});

  @override
  Location? pop() {
    return null;
  }

  @override
  String get path => "/d";
}
