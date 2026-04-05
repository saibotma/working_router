import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ABCLocation extends Location<LocationId> {
  ABCLocation({required super.id, required super.children});

  @override
  List<PathSegment> get path => [
        PathSegment.literal('c'),
        PathSegment.param<String>(
          'id',
          codec: StringRouteParamCodec(),
        ),
      ];
}
