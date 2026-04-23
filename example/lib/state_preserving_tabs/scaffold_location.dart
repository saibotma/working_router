import 'package:working_router/working_router.dart';

class ScaffoldNode extends AbstractLocation<ScaffoldNode> {
  final List<RouteNode> childNodes;

  ScaffoldNode({required this.childNodes});

  @override
  void build(LocationBuilder builder) {
    builder.children = childNodes;
  }
}
