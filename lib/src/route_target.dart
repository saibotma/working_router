import 'package:working_router/src/location.dart';
import 'package:working_router/src/route_node.dart';

sealed class RouteTarget<ID> {
  const RouteTarget();
}

final class UriRouteTarget<ID> extends RouteTarget<ID> {
  final Uri uri;

  const UriRouteTarget(this.uri);
}

base class IdRouteTarget<ID> extends RouteTarget<ID> {
  final ID id;
  final Map<String, String> queryParameters;
  final WritePathParameters<ID>? writePathParameters;

  const IdRouteTarget(
    this.id, {
    this.queryParameters = const {},
    this.writePathParameters,
  });
}

base class ChildRouteTarget<ID> extends RouteTarget<ID> {
  final bool Function(AnyLocation<ID> location) predicate;
  final Map<String, String> queryParameters;
  final WritePathParameters<ID>? writePathParameters;

  const ChildRouteTarget(
    this.predicate, {
    this.queryParameters = const {},
    this.writePathParameters,
  });
}
