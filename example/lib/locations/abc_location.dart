import 'package:working_router/working_router.dart';

import '../location_id.dart';

class ABCLocation extends Location<LocationId> {
  final idParameter = pathParam(const StringRouteParamCodec());

  ABCLocation({required super.id, required super.children});

  @override
  List<PathSegment> get path => [
        PathSegment.literal('c'),
        idParameter,
      ];
}
