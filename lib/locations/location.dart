import 'package:fast_immutable_collections/fast_immutable_collections.dart';

abstract class Location<ID> {
  final ID id;
  final List<Location> children;

  Location({required this.id, required this.children});

  String get path;

  late final Uri _uri = Uri.parse(path);

  List<String> get pathSegments => _uri.pathSegments;

  IList<Location> match(IList<String> pathSegments) {
    final List<Location> matches = [];
    final thisPathSegments = _uri.pathSegments.toIList();
    if (startsWith(pathSegments, thisPathSegments)) {
      matches.add(this);

      final nextPathSegments = thisPathSegments.isEmpty
          ? pathSegments
          : pathSegments.sublist(thisPathSegments.length);
      for (final child in children) {
        final childMatches = child.match(nextPathSegments);
        if (childMatches.isNotEmpty) {
          matches.addAll(childMatches);
          break;
        }
      }

      if (matches.length == 1 && nextPathSegments.isNotEmpty) {
        return IList();
      }
    }

    return matches.toIList();
  }

  Map<String, String> selectQueryParameters(Map<String, String> source) {
    return {};
  }

  Location? pop();
}

bool startsWith<T>(IList<T> list, IList<T> startsWith) {
  if (list.length < startsWith.length) {
    return false;
  }
  return list.sublist(0, startsWith.length) == startsWith;
}
