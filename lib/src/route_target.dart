import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:working_router/src/location.dart';
import 'package:working_router/src/route_node.dart';

sealed class RouteTarget<ID extends Enum> {
  const RouteTarget();
}

final class UriRouteTarget<ID extends Enum> extends RouteTarget<ID> {
  final Uri uri;

  const UriRouteTarget(this.uri);
}

base class IdRouteTarget<ID extends Enum> extends RouteTarget<ID> {
  final ID id;
  final Map<String, String> queryParameters;
  final WritePathParameters<ID>? writePathParameters;

  const IdRouteTarget(
    this.id, {
    this.queryParameters = const {},
    this.writePathParameters,
  });
}

/// A safe child route target anchored at a concrete start location instance.
///
/// Routing with this target starts from [start], not from the current active
/// leaf. The [resolveChildPathNodes] callback runs at navigation time and must
/// return the exact live descendant route-node chain below [start] that should
/// be appended to the route.
///
/// This is intentionally stronger than a leaf predicate. It avoids ambiguous
/// first-match routing when multiple descendants under the same subtree could
/// satisfy the same type, `id`, or `localId`-based match.
base class ChildRouteTarget<ID extends Enum> extends RouteTarget<ID> {
  /// The concrete location instance that child routing starts from.
  final AnyLocation<ID> start;

  /// Resolves the exact live descendant route-node chain below [start].
  ///
  /// Generated `childXTarget(...)` helpers typically set this to a callback
  /// that walks `start.children` layer by layer and returns the intended child
  /// path for the current runtime tree shape.
  final IList<RouteNode<ID>>? Function() resolveChildPathNodes;
  final Map<String, String> queryParameters;
  final WritePathParameters<ID>? writePathParameters;

  const ChildRouteTarget(
    {
    required this.start,
    required this.resolveChildPathNodes,
    this.queryParameters = const {},
    this.writePathParameters,
  });
}

/// An explicit first-match child route target.
///
/// This starts from the current active leaf and walks descendants depth-first
/// until [predicate] matches. It is less precise than [ChildRouteTarget], but
/// useful when first-match semantics are intentional.
base class FirstChildRouteTarget<ID extends Enum> extends RouteTarget<ID> {
  final bool Function(AnyLocation<ID> location) predicate;
  final Map<String, String> queryParameters;
  final WritePathParameters<ID>? writePathParameters;

  const FirstChildRouteTarget(
    this.predicate, {
    this.queryParameters = const {},
    this.writePathParameters,
  });
}
