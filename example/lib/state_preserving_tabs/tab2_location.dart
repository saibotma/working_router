import 'package:working_router/working_router.dart';

class Tab2Node extends AbstractLocation<Tab2Node> {
  Tab2Node();

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('tab2');
  }
}
