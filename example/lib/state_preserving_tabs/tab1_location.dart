import 'package:working_router/working_router.dart';

class Tab1Location extends Location<String, Tab1Location> {
  @override
  void build(LocationBuilder<String> builder) {
    builder.pathLiteral('tab1');
  }
}
