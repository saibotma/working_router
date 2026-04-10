import 'package:working_router/working_router.dart';

class Tab2Location extends AbstractLocation<String, Tab2Location> {
  Tab2Location();

  @override
  void build(LocationBuilder<String> builder) {
    builder.pathLiteral('tab2');
  }
}
