import 'dart:collection';
import '../core/state_snapshot.dart';

/// A two-tier cache for [StateSnapshot]s.
///
/// - **Hot tier**: an LRU cache of up to [hotCapacity] snapshots stored
///   entirely in RAM. Access is O(1).
/// - **Cold tier**: an LRU cache of up to [coldCapacity] compressed snapshot
///   keys. Decompression happens on demand via a user-supplied callback.
///
/// Usage:
/// ```dart
/// final cache = MemoryCache<StateSnapshot>(
///   hotCapacity: 500,
///   coldCapacity: 5000,
///   decompress: (key) async => await disk.loadSnapshot(key),
/// );
/// await cache.put(snap.stepNumber, snap);
/// final s = await cache.get(42);
/// ```
class MemoryCache<T> {
  final int hotCapacity;
  final int coldCapacity;

  /// Called when a key is in the cold tier but not hot — must return the
  /// value (e.g. load from disk).
  final Future<T?> Function(int key)? decompress;

  // Hot tier: LinkedHashMap preserves insertion order for LRU.
  final LinkedHashMap<int, T> _hot = LinkedHashMap();

  // Cold tier: just the set of keys whose values have been evicted from hot.
  final LinkedHashSet<int> _cold = LinkedHashSet();

  int _hits = 0;
  int _misses = 0;

  MemoryCache({
    this.hotCapacity = 500,
    this.coldCapacity = 5000,
    this.decompress,
  });

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Stores [value] in the hot tier.
  Future<void> put(int key, T value) async {
    if (_hot.containsKey(key)) {
      // Refresh position for LRU.
      _hot.remove(key);
    } else if (_hot.length >= hotCapacity) {
      _demoteOldest();
    }
    _hot[key] = value;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the value for [key], promoting from cold tier if needed.
  ///
  /// Returns `null` if the key is completely unknown.
  Future<T?> get(int key) async {
    // Hot hit.
    if (_hot.containsKey(key)) {
      _hits++;
      final v = _hot.remove(key)!; // remove and re-insert to bump LRU.
      _hot[key] = v;
      return v;
    }

    // Cold hit: promote.
    if (_cold.contains(key)) {
      _misses++;
      final v = await decompress?.call(key);
      if (v != null) await put(key, v);
      _cold.remove(key);
      return v;
    }

    _misses++;
    return null;
  }

  /// Returns whether [key] is in the hot tier (no I/O).
  bool isHot(int key) => _hot.containsKey(key);

  /// Returns whether [key] is known (hot or cold).
  bool contains(int key) => _hot.containsKey(key) || _cold.contains(key);

  // ── Invalidation ─────────────────────────────────────────────────────────

  void invalidate(int key) {
    _hot.remove(key);
    _cold.remove(key);
  }

  void clear() {
    _hot.clear();
    _cold.clear();
    _hits = 0;
    _misses = 0;
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  int get hotSize => _hot.length;
  int get coldSize => _cold.length;
  int get hits => _hits;
  int get misses => _misses;
  double get hitRate =>
      (_hits + _misses) == 0 ? 0 : _hits / (_hits + _misses);

  @override
  String toString() =>
      'MemoryCache(hot=$hotSize/$hotCapacity, cold=$coldSize/$coldCapacity, '
      'hitRate=${(hitRate * 100).toStringAsFixed(1)}%)';

  // ── Private ───────────────────────────────────────────────────────────────

  /// Moves the least-recently-used hot entry to the cold tier.
  void _demoteOldest() {
    if (_hot.isEmpty) return;
    final oldestKey = _hot.keys.first;
    _hot.remove(oldestKey);

    if (_cold.length >= coldCapacity) {
      _cold.remove(_cold.first);
    }
    _cold.add(oldestKey);
  }
}

// ── Specialised convenience type ─────────────────────────────────────────────

/// A [MemoryCache] pre-typed for [StateSnapshot]s.
typedef SnapshotCache = MemoryCache<StateSnapshot>;
