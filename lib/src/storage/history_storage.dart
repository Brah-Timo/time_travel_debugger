import '../models/variable_record.dart';
import '../core/state_snapshot.dart';

/// Strategy used by [HistoryStorage] when the record limit is reached.
enum EvictionPolicy {
  /// Drop the oldest records (FIFO).
  fifo,

  /// Drop records from the variable with the most mutations.
  leastFrequentlyUsed,

  /// Drop records that have not been read recently.
  leastRecentlyUsed,
}

/// A unified in-memory store for [VariableRecord]s and [StateSnapshot]s
/// that supports multiple eviction strategies and optional listeners.
///
/// [HistoryStorage] sits between the raw [MemoryRecorder] / [ExecutionTimeline]
/// and the persistence layer ([DiskPersistence]). It acts as the "warm" cache.
class HistoryStorage {
  // ── Configuration ─────────────────────────────────────────────────────────
  final int maxRecords;
  final int maxSnapshots;
  final EvictionPolicy recordPolicy;
  final EvictionPolicy snapshotPolicy;

  // ── Storage ───────────────────────────────────────────────────────────────
  final List<VariableRecord> _records = [];
  final List<StateSnapshot> _snapshots = [];

  /// Access-time tracker for LRU eviction on snapshots.
  final Map<int, DateTime> _snapshotLastAccess = {};

  /// Mutation-frequency tracker for LFU eviction on records.
  final Map<String, int> _variableHits = {};

  // ── Listeners ─────────────────────────────────────────────────────────────
  final List<void Function(VariableRecord)> _recordListeners = [];
  final List<void Function(StateSnapshot)> _snapshotListeners = [];
  final List<void Function(VariableRecord)> _evictionListeners = [];

  HistoryStorage({
    this.maxRecords = 30000,
    this.maxSnapshots = 15000,
    this.recordPolicy = EvictionPolicy.fifo,
    this.snapshotPolicy = EvictionPolicy.leastRecentlyUsed,
  });

  // ── Record API ────────────────────────────────────────────────────────────

  /// Adds a [VariableRecord]; evicts if over capacity.
  void addRecord(VariableRecord record) {
    if (_records.length >= maxRecords) _evictRecord();
    _records.add(record);
    _variableHits[record.variableName] =
        (_variableHits[record.variableName] ?? 0) + 1;
    for (final cb in _recordListeners) {
      cb(record);
    }
  }

  /// All records (read-only view).
  List<VariableRecord> get records => List.unmodifiable(_records);

  /// Records for a specific variable.
  List<VariableRecord> recordsFor(String name) =>
      _records.where((r) => r.variableName == name).toList();

  // ── Snapshot API ──────────────────────────────────────────────────────────

  /// Adds a [StateSnapshot]; evicts if over capacity.
  void addSnapshot(StateSnapshot snapshot) {
    if (_snapshots.length >= maxSnapshots) _evictSnapshot();
    _snapshots.add(snapshot);
    _snapshotLastAccess[snapshot.stepNumber] = DateTime.now();
    for (final cb in _snapshotListeners) {
      cb(snapshot);
    }
  }

  /// Returns the snapshot at [step], updating its LRU timestamp.
  StateSnapshot? snapshotAt(int step) {
    final s = _snapshots.firstWhere(
      (s) => s.stepNumber == step,
      orElse: () => throw RangeError('Snapshot $step not in storage.'),
    );
    _snapshotLastAccess[step] = DateTime.now();
    return s;
  }

  /// All snapshots (read-only view).
  List<StateSnapshot> get snapshots => List.unmodifiable(_snapshots);

  // ── Listener management ───────────────────────────────────────────────────

  void addRecordListener(void Function(VariableRecord) cb) =>
      _recordListeners.add(cb);

  void addSnapshotListener(void Function(StateSnapshot) cb) =>
      _snapshotListeners.add(cb);

  void addEvictionListener(void Function(VariableRecord) cb) =>
      _evictionListeners.add(cb);

  void removeRecordListener(void Function(VariableRecord) cb) =>
      _recordListeners.remove(cb);

  // ── Statistics ────────────────────────────────────────────────────────────

  int get recordCount => _records.length;
  int get snapshotCount => _snapshots.length;

  /// Variable with the most recorded mutations.
  String? get hottestVariable {
    if (_variableHits.isEmpty) return null;
    return _variableHits.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  void clear() {
    _records.clear();
    _snapshots.clear();
    _snapshotLastAccess.clear();
    _variableHits.clear();
  }

  // ── Private eviction ──────────────────────────────────────────────────────

  void _evictRecord() {
    if (_records.isEmpty) return;
    VariableRecord victim;

    switch (recordPolicy) {
      case EvictionPolicy.fifo:
        victim = _records.removeAt(0);
      case EvictionPolicy.leastFrequentlyUsed:
        // Find variable with fewest total mutations and evict its oldest record.
        final minVar = _variableHits.entries
            .reduce((a, b) => a.value < b.value ? a : b)
            .key;
        final idx = _records.indexWhere((r) => r.variableName == minVar);
        victim = _records.removeAt(idx < 0 ? 0 : idx);
      case EvictionPolicy.leastRecentlyUsed:
        // Records don't have individual access tracking → fall back to FIFO.
        victim = _records.removeAt(0);
    }

    for (final cb in _evictionListeners) {
      cb(victim);
    }
  }

  void _evictSnapshot() {
    if (_snapshots.isEmpty) return;

    switch (snapshotPolicy) {
      case EvictionPolicy.fifo:
        _snapshots.removeAt(0);
      case EvictionPolicy.leastRecentlyUsed:
        // Find snapshot with the oldest last-access time.
        DateTime? oldest;
        int? oldestStep;
        for (final entry in _snapshotLastAccess.entries) {
          if (oldest == null || entry.value.isBefore(oldest)) {
            oldest = entry.value;
            oldestStep = entry.key;
          }
        }
        if (oldestStep != null) {
          _snapshots.removeWhere((s) => s.stepNumber == oldestStep);
          _snapshotLastAccess.remove(oldestStep);
        } else {
          _snapshots.removeAt(0);
        }
      case EvictionPolicy.leastFrequentlyUsed:
        _snapshots.removeAt(0);
    }
  }
}
