import '../models/variable_record.dart';

/// A watchpoint monitors a variable and fires a callback every time it
/// changes value, optionally filtering by a predicate.
///
/// Unlike breakpoints, watchpoints do **not** stop execution — they are
/// pure observers used for analytics and live dashboards.
class Watchpoint {
  final String id;
  final String variableName;
  final bool Function(dynamic newValue, dynamic oldValue)? filter;
  final void Function(VariableRecord record) callback;
  bool enabled;
  int hitCount = 0;

  Watchpoint({
    required this.id,
    required this.variableName,
    this.filter,
    required this.callback,
    this.enabled = true,
  });
}

/// Manages a set of [Watchpoint]s.
///
/// ```dart
/// manager.add(
///   variableName: 'score',
///   callback: (r) => print('Score changed: ${r.newValue}'),
/// );
///
/// // In recording loop:
/// manager.notify(record);
/// ```
class WatchpointManager {
  final Map<String, Watchpoint> _watchpoints = {};
  int _counter = 0;

  // ── Add / remove ──────────────────────────────────────────────────────────

  /// Adds a watchpoint and returns its auto-generated ID.
  String add({
    required String variableName,
    required void Function(VariableRecord) callback,
    bool Function(dynamic newVal, dynamic oldVal)? filter,
    bool enabled = true,
  }) {
    final id = 'wp_${_counter++}';
    _watchpoints[id] = Watchpoint(
      id: id,
      variableName: variableName,
      filter: filter,
      callback: callback,
      enabled: enabled,
    );
    return id;
  }

  void remove(String id) => _watchpoints.remove(id);
  void removeAll() => _watchpoints.clear();

  void enable(String id) {
    final wp = _watchpoints[id];
    if (wp != null) wp.enabled = true;
  }

  void disable(String id) {
    final wp = _watchpoints[id];
    if (wp != null) wp.enabled = false;
  }

  // ── Evaluation ────────────────────────────────────────────────────────────

  /// Notifies all matching active watchpoints about [record].
  void notify(VariableRecord record) {
    for (final wp in _watchpoints.values) {
      if (!wp.enabled) continue;
      if (wp.variableName != record.variableName) continue;
      final pass =
          wp.filter == null || wp.filter!(record.newValue, record.oldValue);
      if (!pass) continue;
      wp.hitCount++;
      try {
        wp.callback(record);
      } catch (_) {
        // Never let a watchpoint callback crash the recording path.
      }
    }
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  int get count => _watchpoints.length;
  List<Watchpoint> get all => _watchpoints.values.toList();

  Watchpoint? find(String id) => _watchpoints[id];
}
