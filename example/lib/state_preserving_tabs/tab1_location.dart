import 'package:working_router/working_router.dart';

class Tab1Node extends AbstractLocation<Tab1Node> {
  Tab1Node();

  @override
  void build(LocationBuilder builder) {
    builder.pathLiteral('tab1');
  }
}
