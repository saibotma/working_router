import 'package:working_router/working_router.dart';

class ScaffoldLocation extends Location<String> {
  ScaffoldLocation({required super.children});

  @override
  List<PathSegment> get path => const [];
}
