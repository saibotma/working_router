import 'package:navigator_test/locations/location.dart';

import 'ab_location.dart';

class ABCLocation extends Location {
  ABCLocation({required super.id, required super.children});

  @override
  Location? pop() {
    return null;
  }

  @override
  String get path => "/c";
}
