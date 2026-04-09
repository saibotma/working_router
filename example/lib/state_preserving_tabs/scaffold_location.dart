import 'package:working_router/working_router.dart';

class ScaffoldLocation extends Location<String, ScaffoldLocation> {
  final List<LocationTreeElement<String>> childNodes;

  ScaffoldLocation({required this.childNodes});

  @override
  void build(LocationBuilder<String> builder) {
    builder.children = childNodes;
  }
}
