import 'dart:collection';
import 'package:collection/collection.dart';
import '../models/variable_record.dart';

/// Statistics about a single tracked variable.
class VariableStats {
  /// Total number of times this variable changed value.
  final int changeCount;

  /// Step index of the first recorded change.
  final int firstChangeStep;

  /// Step index of the most recent change.
  final int lastChangeStep;

  /// All step indices where this variable was mutated.
  final List<int> mutationSteps;

  const VariableStats({
    required this.changeCount,
    required this.firstChangeStep,
    required this.lastChangeStep,
    required this.mutationSteps,
  });
}

/// Low-level store for every [VariableRecord] captured during a session.
///
/// Maintains two indices:
/// - A flat chronological list (`_records`).
/// - An inverted index mapping variable names → list of record indices,
///   enabling O(1) first/last lookup and O(k) full-history lookup.
///
/// When [maxRecords] is exceeded, the oldest records are evicted using
/// a sliding-window strategy, and the inverted index is updated to
/// reflect absolute positions.
class MemoryRecorder {
  /// Maximum number of [VariableRecord]s to keep in hot memory.
  /// Older records beyond this limit are evicted (not deleted — they are
  /// first handed to the cold-cache callback, if registered).
  final int maxRecords;

  /// Called just before a record is evicted from hot memory.
  /// Use this hook to persist the record to disk / cold cache.
  final void Function(VariableRecord record)? onEvict;

  final List<VariableRecord> _records = [];

  /// variableName → sorted list of absolute record indices.
  final Map<String, List<int>> _index = {};

  /// Running offset: how many records have been evicted so far.
  int _evictedCount = 0;

  /// Rolling latency samples for performance stats (microseconds).
  final Queue<int> _latencySamples = Queue();
  static const int _latencyWindowSize = 1000;

  MemoryRecorder({
    this.maxRecords = 50000,
    this.onEvict,
  });

  // ── Core operations ──────────────────────────────────────────────────────

  /// Appends a [VariableRecord] to the recorder.
  ///
  /// Returns the absolute index assigned to this record.
  int addRecord(VariableRecord record) {
    final sw = Stopwatch()..start();

    if (_records.length >= maxRecords) {
      _evict();
    }

    final absoluteIndex = _evictedCount + _records.length;
    final indexed = record.withIndex(absoluteIndex);
    _records.add(indexed);

    _index.putIfAbsent(record.variableName, () => []).add(absoluteIndex);

    sw.stop();
    _trackLatency(sw.elapsedMicroseconds);

    return absoluteIndex;
  }

  /// Removes the oldest record, notifying [onEvict] first.
  void _evict() {
    if (_records.isEmpty) return;
    final oldest = _records.removeAt(0);
    onEvict?.call(oldest);
    _evictedCount++;
  }

  // ── Lookup API ────────────────────────────────────────────────────────────

  /// All records currently in hot memory, in chronological order.
  List<VariableRecord> get allRecords =>
      List<VariableRecord>.unmodifiable(_records);

  /// Records for a single variable (hot memory only).
  List<VariableRecord> recordsForVariable(String name) {
    final indices = _index[name] ?? [];
    return [
      for (final i in indices)
        if (_absoluteToLocal(i) case final local when local >= 0)
          _records[local]
    ];
  }

  /// Returns the absolute step index of the first change, or `null`.
  int? firstChangeOf(String name) => _index[name]?.firstOrNull;

  /// Returns the absolute step index of the last change, or `null`.
  int? lastChangeOf(String name) => _index[name]?.lastOrNull;

  /// Returns all absolute step indices where [name] was mutated.
  List<int> allChangesOf(String name) =>
      List<int>.unmodifiable(_index[name] ?? []);

  /// Returns the [VariableRecord] at absolute index [i], or `null` if
  /// it has been evicted.
  VariableRecord? recordAt(int absoluteIndex) {
    final local = _absoluteToLocal(absoluteIndex);
    if (local < 0 || local >= _records.length) return null;
    return _records[local];
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  /// Number of records currently in hot memory.
  int get recordCount => _records.length;

  /// Total number of records ever added (hot + evicted).
  int get totalRecordsEver => _evictedCount + _records.length;

  /// Names of all tracked variables (ever seen, not just in hot memory).
  Set<String> get trackedVariableNames => _index.keys.toSet();

  /// Statistics for a single variable.
  VariableStats? statsForVariable(String name) {
    final steps = _index[name];
    if (steps == null || steps.isEmpty) return null;
    return VariableStats(
      changeCount: steps.length,
      firstChangeStep: steps.first,
      lastChangeStep: steps.last,
      mutationSteps: List.unmodifiable(steps),
    );
  }

  /// Rough estimate of heap bytes consumed by hot records.
  int estimatedMemoryBytes() {
    const overhead = 128; // bytes per VariableRecord object
    return _records.length * overhead +
        _index.values.fold<int>(
          0,
          (sum, list) => sum + list.length * 8,
        );
  }

  /// Average recording latency in microseconds (rolling window).
  double get averageLatencyMicros {
    if (_latencySamples.isEmpty) return 0;
    return _latencySamples.fold<int>(0, (a, b) => a + b) /
        _latencySamples.length;
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Returns all records whose [VariableRecord.description] contains [query]
  /// (case-insensitive).
  List<VariableRecord> searchByDescription(String query) {
    final q = query.toLowerCase();
    return _records
        .where((r) => r.description?.toLowerCase().contains(q) ?? false)
        .toList();
  }

  /// Returns all records tagged with [tag].
  List<VariableRecord> searchByTag(String tag) =>
      _records.where((r) => r.tags.contains(tag)).toList();

  /// Returns all records in the absolute index range [from, to] (inclusive).
  List<VariableRecord> rangeQuery(int from, int to) {
    return _records.where((r) {
      return r.recordIndex >= from && r.recordIndex <= to;
    }).toList();
  }

  // ── Maintenance ───────────────────────────────────────────────────────────

  /// Clears all hot-memory records and resets the eviction counter.
  void clear() {
    _records.clear();
    _index.clear();
    _evictedCount = 0;
    _latencySamples.clear();
  }

  void dispose() => clear();

  // ── Private helpers ───────────────────────────────────────────────────────

  int _absoluteToLocal(int absolute) => absolute - _evictedCount;

  void _trackLatency(int micros) {
    _latencySamples.addLast(micros);
    if (_latencySamples.length > _latencyWindowSize) {
      _latencySamples.removeFirst();
    }
  }
}
