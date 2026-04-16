import 'package:working_router/working_router.dart';

class Tab2Node extends AbstractLocation<String, Tab2Node> {
  Tab2Node();

  @override
  void build(LocationBuilder<String> builder) {
    builder.pathLiteral('tab2');
  }
}
