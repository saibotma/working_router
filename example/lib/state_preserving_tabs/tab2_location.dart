import 'package:working_router/working_router.dart';

class Tab2Location extends Location<String> {
  @override
  List<PathSegment> get path => const [PathSegment.literal('tab2')];
}
