abstract class Location<ID> {
  final ID id;
  final List<Location> children;

  Location({required this.id, required this.children});

  String get path;

  List<Location> match(String path) {
    final List<Location> matches = [];
    if (path.startsWith(this.path)) {
      matches.add(this);

      final pathEnd = this.path == "/" ? path : path.replaceFirst(this.path, "");
      for(final child in children) {
        final childMatches = child.match(pathEnd);
        if (childMatches.isNotEmpty) {
          matches.addAll(childMatches);
          break;
        }
      }
    }

    return matches;
  }

  Location? pop();
}
