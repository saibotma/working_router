import 'package:fast_immutable_collections/fast_immutable_collections.dart';

abstract class Location<ID> {
  final ID id;
  final List<Location<ID>> children;

  Location({required this.id, required this.children});

  String get path;

  late final Uri _uri = Uri.parse(path);

  List<String> get pathSegments => _uri.pathSegments;

  Tuple2<IList<Location<ID>>, IMap<String, String>> match(
      IList<String> pathSegments) {
    final List<Location<ID>> matches = [];
    final Map<String, String> pathParameters = {};

    final thisPathSegments = _uri.pathSegments.toIList();
    final thisPathParameters = startsWith(pathSegments, thisPathSegments);
    if (thisPathParameters != null) {
      matches.add(this);
      pathParameters.addAll(thisPathParameters);

      final nextPathSegments = thisPathSegments.isEmpty
          ? pathSegments
          : pathSegments.sublist(thisPathSegments.length);
      for (final child in children) {
        final childMatches = child.match(nextPathSegments);
        if (childMatches.first.isNotEmpty) {
          matches.addAll(childMatches.first);
          pathParameters.addAll(childMatches.second.unlock);
          break;
        }
      }

      if (matches.length == 1 && nextPathSegments.isNotEmpty) {
        return Tuple2(IList(), IMap());
      }
    }

    return Tuple2(matches.toIList(), pathParameters.toIMap());
  }

  IList<Location<ID>> matchId(ID id) {
    final List<Location<ID>> matches = [];
    if (this.id == id) {
      matches.add(this);
    } else {
      for (final child in children) {
        final childMatches = child.matchId(id);
        if (childMatches.isNotEmpty) {
          matches.add(this);
          matches.addAll(childMatches);
          break;
        }
      }
    }

    return matches.toIList();
  }

  IList<Location<ID>> matchRelative(
    bool Function(Location<ID> location) matches,
  ) {
    for (final child in children) {
      final childMatches = child._matchRelative(matches);
      if (childMatches.isNotEmpty) {
        return childMatches;
      }
    }

    return IList();
  }

  IList<Location<ID>> _matchRelative(
    bool Function(Location<ID> location) matches,
  ) {
    if (matches(this)) {
      return [this].toIList();
    }

    for (final child in children) {
      final childMatches = child.matchRelative(matches);
      if (childMatches.isNotEmpty) {
        return [this, ...childMatches].toIList();
      }
    }

    return IList();
  }

  IMap<String, String> selectQueryParameters(IMap<String, String> source) {
    return IMap();
  }

  IMap<String, String> selectPathParameters(IMap<String, String> source) {
    return IMap();
  }

  Location<ID>? pop() {
    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Location && runtimeType == other.runtimeType && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

Map<String, String>? startsWith(
  IList<String> list,
  IList<String> startsWith,
) {
  if (list.length < startsWith.length) {
    return null;
  }

  final Map<String, String> pathParameters = {};

  for (int i = 0; i < startsWith.length; i++) {
    final listItem = list[i];
    final startsWithItem = startsWith[i];

    if (!startsWithItem.startsWith(":")) {
      if (listItem != startsWithItem) {
        return null;
      }
    } else {
      pathParameters[startsWithItem.replaceRange(0, 1, "")] = listItem;
    }
  }

  return pathParameters;
}
