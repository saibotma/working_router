import 'package:working_router/working_router.dart';

class Tab2Location extends Location<String, Tab2Location> {
  @override
  void build(LocationBuilder<String> builder) {
    builder.pathLiteral('tab2');
  }
}
