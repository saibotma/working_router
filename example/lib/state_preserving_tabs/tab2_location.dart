import 'package:working_router/working_router.dart';

class Tab2Location extends Location<String, Tab2Location> {
  Tab2Location() : super.override();

  @override
  void build(LocationBuilder<String> builder) {
    builder.pathLiteral('tab2');
  }
}
