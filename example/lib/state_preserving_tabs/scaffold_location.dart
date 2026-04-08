import 'package:working_router/working_router.dart';

class ScaffoldLocation extends Location<String> {
  @override
  final List<RouteNode<String>> children;

  ScaffoldLocation({required this.children});

  @override
  List<PathSegment> get path => const [];
}
