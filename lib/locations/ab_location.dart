import 'package:navigator_test/locations/location.dart';

class ABLocation extends Location {
  ABLocation({required super.id, required super.children});

  @override
  Location? pop() {
    return null;
  }

  @override
  String get path => "/b";
}
