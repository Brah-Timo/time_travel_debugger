import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/variable_record.dart';
import '../models/call_stack_frame.dart';
import '../models/session_metadata.dart';
import '../models/timeline_event.dart';
import 'state_snapshot.dart';

/// The execution timeline is the central ordered log of all [TimelineEvent]s.
///
/// It maintains:
/// - A flat list of [TimelineEvent]s for replay.
/// - A parallel list of [StateSnapshot]s for instant O(1) random access.
/// - A cursor ([currentPosition]) for the time-travel API.
/// - A live variable map and call-stack reconstructed incrementally.
///
/// ### Snapshot strategy
/// A new snapshot is materialised on **every event**. This is the most
/// memory-intensive strategy but gives the richest rewind granularity.
/// Call [compress] periodically to deduplicate consecutive identical snapshots
/// and free memory.
class ExecutionTimeline {
  /// Maximum number of snapshots to hold in memory simultaneously.
  final int maxSnapshots;

  // ── Internal state ────────────────────────────────────────────────────────
  final List<TimelineEvent> _events = [];
  final List<StateSnapshot> _snapshots = [];

  /// Live variable map, kept up-to-date as events arrive.
  final Map<String, dynamic> _liveVars = {};

  /// Live call stack.
  final List<CallStackFrame> _callStack = [];

  /// Current cursor (for rewind/fast-forward).
  int _cursor = 0;

  /// When the timeline was first created in this session.
  late final DateTime _createdAt = DateTime.now();

  // ── Constructor ───────────────────────────────────────────────────────────
  ExecutionTimeline({this.maxSnapshots = 20000}) {
    _materializeSnapshot(
      description: 'Timeline initialised',
      changes: [],
    );
  }

  // ── Event ingestion ───────────────────────────────────────────────────────

  /// Appends a variable-mutation event and materialises a snapshot.
  void addMutationEvent(VariableRecord record, int absoluteIndex) {
    _liveVars[record.variableName] = record.newValue;

    final event = TimelineEvent.mutation(
      index: _events.length,
      record: record,
    );
    _events.add(event);

    _materializeSnapshot(
      description: '${record.variableName} changed',
      changes: [record],
    );
  }

  /// Appends a function-entry event.
  void addFunctionEntry({
    required String functionName,
    required List<String> parameters,
    String file = '',
    int line = 0,
  }) {
    _callStack.add(CallStackFrame(
      functionName: functionName,
      filePath: file,
      lineNumber: line,
      parameters: parameters,
    ));

    final event = TimelineEvent.functionEntry(
      index: _events.length,
      functionName: functionName,
      timestamp: DateTime.now(),
    );
    _events.add(event);

    _materializeSnapshot(description: 'Entered: $functionName');
  }

  /// Appends a function-return event.
  void addFunctionReturn({
    required String functionName,
    dynamic returnValue,
  }) {
    if (_callStack.isNotEmpty) _callStack.removeLast();

    final event = TimelineEvent.functionReturn(
      index: _events.length,
      functionName: functionName,
      timestamp: DateTime.now(),
    );
    _events.add(event);

    _materializeSnapshot(description: 'Returned: $functionName');
  }

  /// Appends a user annotation.
  void addAnnotation(String label) {
    final event = TimelineEvent.annotation(
      index: _events.length,
      label: label,
      timestamp: DateTime.now(),
    );
    _events.add(event);

    _materializeSnapshot(description: 'Annotation: $label');
    // Also mark the snapshot as a bookmark.
    if (_snapshots.isNotEmpty) {
      final last = _snapshots.removeLast();
      _snapshots.add(last.withBookmark(label));
    }
  }

  // ── Random-access API ─────────────────────────────────────────────────────

  /// Returns the [StateSnapshot] at [step] and updates the cursor.
  StateSnapshot snapshotAt(int step) {
    _validateStep(step);
    _cursor = step;
    return _snapshots[step];
  }

  /// All snapshots that carry a bookmark label.
  List<StateSnapshot> bookmarkedSnapshots() =>
      _snapshots.where((s) => s.bookmarkLabel != null).toList();

  /// All events within the half-open range [from, to).
  List<TimelineEvent> eventsInRange(int from, int to) {
    if (from < 0 || to > _events.length || from >= to) return [];
    return _events.sublist(from, to);
  }

  // ── Cursor ────────────────────────────────────────────────────────────────

  int get currentPosition => _cursor;
  int get lastIndex => _snapshots.length - 1;
  int get totalSteps => _snapshots.length;
  DateTime get startTime => _createdAt;

  // ── Compression ──────────────────────────────────────────────────────────

  /// Removes consecutive duplicate snapshots (same variable map).
  ///
  /// After compression, step indices are renumbered. The cursor is adjusted
  /// to point to the nearest surviving snapshot.
  void compress() {
    if (_snapshots.length < 2) return;

    final kept = <StateSnapshot>[];
    Map<String, dynamic>? lastVars;

    for (final snap in _snapshots) {
      final isDuplicate = lastVars != null &&
          _mapsEqual(snap.variables, lastVars);
      if (!isDuplicate || snap.bookmarkLabel != null) {
        kept.add(snap);
        lastVars = snap.variables;
      }
    }

    _snapshots
      ..clear()
      ..addAll(kept);

    // Renumber step indices in place.
    for (var i = 0; i < _snapshots.length; i++) {
      final s = _snapshots[i];
      if (s.stepNumber != i) {
        _snapshots[i] = StateSnapshot(
          snapshotId: s.snapshotId,
          stepNumber: i,
          timestamp: s.timestamp,
          variables: s.variables,
          callStack: s.callStack,
          description: s.description,
          changes: s.changes,
          bookmarkLabel: s.bookmarkLabel,
        );
      }
    }

    // Clamp cursor to new bounds.
    _cursor = _cursor.clamp(0, lastIndex);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Serialises the timeline to a `.ttd` JSON file at [path].
  Future<void> saveToDisk(String path, SessionMetadata metadata) async {
    final file = File(path);
    await file.parent.create(recursive: true);

    final data = {
      'metadata': metadata.toJson(),
      'snapshots': _snapshots.map((s) => s.toJson()).toList(),
      'events': _events.map((e) => e.toJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      encoding: utf8,
    );
  }

  /// Loads a timeline from a `.ttd` JSON file at [path].
  Future<void> loadFromDisk(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ArgumentError('Session file not found: $path');
    }

    final raw = await file.readAsString(encoding: utf8);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    _snapshots.clear();
    _events.clear();
    _liveVars.clear();
    _callStack.clear();

    final snapshotList = data['snapshots'] as List;
    for (final s in snapshotList) {
      _snapshots.add(
          StateSnapshot.fromJson(Map<String, dynamic>.from(s as Map)));
    }

    final eventList = data['events'] as List;
    for (final e in eventList) {
      _events
          .add(TimelineEvent.fromJson(Map<String, dynamic>.from(e as Map)));
    }

    _cursor = lastIndex;
  }

  // ── Reset & dispose ───────────────────────────────────────────────────────

  /// Clears all data and returns the timeline to its initial state.
  void reset() {
    _events.clear();
    _snapshots.clear();
    _liveVars.clear();
    _callStack.clear();
    _cursor = 0;
    _materializeSnapshot(description: 'Timeline reset');
  }

  void dispose() {
    _events.clear();
    _snapshots.clear();
    _liveVars.clear();
    _callStack.clear();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _materializeSnapshot({
    String? description,
    List<VariableRecord> changes = const [],
  }) {
    if (_snapshots.length >= maxSnapshots) {
      _snapshots.removeAt(0);
      // Keep cursor valid.
      if (_cursor > 0) _cursor--;
    }

    final snap = StateSnapshot(
      snapshotId: const Uuid().v4(),
      stepNumber: _snapshots.length,
      timestamp: DateTime.now(),
      variables: Map<String, dynamic>.from(_liveVars),
      callStack: List<CallStackFrame>.from(_callStack),
      description: description,
      changes: List<VariableRecord>.from(changes),
    );
    _snapshots.add(snap);
    _cursor = _snapshots.length - 1;
  }

  void _validateStep(int step) {
    if (step < 0 || step > lastIndex) {
      throw ArgumentError(
          'Step $step is out of range [0, $lastIndex].');
    }
  }

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
