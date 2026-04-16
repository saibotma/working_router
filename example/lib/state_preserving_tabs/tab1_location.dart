import 'package:working_router/working_router.dart';

class Tab1Node extends AbstractLocation<String, Tab1Node> {
  Tab1Node();

  @override
  void build(LocationBuilder<String> builder) {
    builder.pathLiteral('tab1');
  }
}
