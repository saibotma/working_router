import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import '../working_router.dart';

class WorkingRouterData<ID> {
  final Uri uri;

  // TODO(saibotma): This is different from e.g. VRouter where a name is only added, when it's page is also displayed. Here a location gets added, when the path matches, but the page must not be displayed. This could be changed, by respecting whether buildPages from router delegate returns an empty list or not for a location.
  final IList<Location<ID>> locations;
  final IMap<String, String> pathParameters;
  final IMap<String, String> queryParameters;

  WorkingRouterData({
    required this.uri,
    required this.locations,
    required this.pathParameters,
    required this.queryParameters,
  });

  bool isIdMatched(ID id) {
    return isMatched((location) => location.id == id);
  }

  bool isMatched(bool Function(Location<ID> location) match) {
    return locations.any(match);
  }

  bool isIdActive(ID id) {
    return isActive((location) => location.id == id);
  }

  bool isActive(bool Function(Location<ID> location) match) {
    final last = locations.lastOrNull;
    if (last == null) {
      return false;
    }
    return match(last);
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
