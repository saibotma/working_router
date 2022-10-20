import 'package:navigator_test/locations/location.dart';

class ALocation extends Location {
  ALocation({required super.id, required super.children});

  @override
  Location? pop() {
    return null;
  }

  @override
  String get path => "/a";
}
