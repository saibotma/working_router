import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../working_router.dart';

class WorkingRouterData<ID> {
  final Uri uri;
  final IList<Location<ID>> locations;
  final IMap<String, String> pathParameters;
  final IMap<String, String> queryParameters;

  WorkingRouterData({
    required this.uri,
    required this.locations,
    required this.pathParameters,
    required this.queryParameters,
  });

  bool isIdActive(ID id) {
    return isActive((location) => location.id == id);
  }

  bool isActive(bool Function(Location<ID> location) match) {
    return locations.any(match);
  }

  WorkingRouterData<ID> copyWith({
    Uri? uri,
    IList<Location<ID>>? locations,
    IMap<String, String>? pathParameters,
    IMap<String, String>? queryParameters,
  }) {
    return WorkingRouterData(
      uri: uri ?? this.uri,
      locations: locations ?? this.locations,
      pathParameters: pathParameters ?? this.pathParameters,
      queryParameters: queryParameters ?? this.queryParameters,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkingRouterData &&
            runtimeType == other.runtimeType &&
            uri == other.uri &&
            locations == other.locations &&
            pathParameters == other.pathParameters &&
            queryParameters == other.queryParameters;
  }

  @override
  int get hashCode {
    return uri.hashCode ^
        locations.hashCode ^
        pathParameters.hashCode ^
        queryParameters.hashCode;
  }
}
