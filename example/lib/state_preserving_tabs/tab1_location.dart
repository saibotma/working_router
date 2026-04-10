import 'package:working_router/working_router.dart';

class Tab1Location extends AbstractLocation<String, Tab1Location> {
  Tab1Location();

  @override
  void build(LocationBuilder<String> builder) {
    builder.pathLiteral('tab1');
  }
}
