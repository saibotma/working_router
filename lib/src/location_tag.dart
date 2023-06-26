abstract class LocationTag {
  @override
  bool operator ==(Object other) =>
      other is LocationTag && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
