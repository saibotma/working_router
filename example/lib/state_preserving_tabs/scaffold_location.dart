import 'package:working_router/working_router.dart';

class ScaffoldNode extends AbstractLocation<String, ScaffoldNode> {
  final List<RouteNode<String>> childNodes;

  ScaffoldNode({required this.childNodes});

  @override
  void build(LocationBuilder<String> builder) {
    builder.children = childNodes;
  }
}
