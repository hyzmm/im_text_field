class TypedMap {
  final Map<String, dynamic> _data;

  TypedMap([Map<String, dynamic>? source]) : _data = Map.of(source ?? const {});

  /// Returns a typed value for [key].
  T? get<T>(String key) {
    final value = _data[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  /// Inserts or replaces a value.
  void put<T>(String key, T value) => _data[key] = value;

  bool contains(String key) => _data.containsKey(key);

  dynamic remove(String key) => _data.remove(key);

  /// Merges [other] into this map (overwrites existing keys).
  void merge(Map<String, dynamic> other) => _data.addAll(other);

  /// Returns a mutable copy of the internal map.
  Map<String, dynamic> toMap() => Map<String, dynamic>.from(_data);

  /// Iterates keys.
  Iterable<String> get keys => _data.keys;

  /// Number of entries.
  int get length => _data.length;

  bool get isEmpty => _data.isEmpty;
  bool get isNotEmpty => _data.isNotEmpty;
}
