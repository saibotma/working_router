import 'package:fast_immutable_collections/fast_immutable_collections.dart';

extension KeepKeysX<K, V> on IMap<K, V> {
  IMap<K, V> keepKeys(ISet<K> keys) {
    final map = <K, V>{};
    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        map[key] = value;
      }
    }
    return map.toIMap();
  }
}
