import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/variable_record.dart';
import '../models/performance_stats.dart';
import '../models/session_metadata.dart';
import 'state_snapshot.dart';
import 'memory_recorder.dart';
import 'execution_timeline.dart';

/// Exception thrown when an engine operation is called in an invalid state.
class TimeTravelException implements Exception {
  final String message;
  const TimeTravelException(this.message);
  @override
  String toString() => 'TimeTravelException: $message';
}

/// Configuration bag for [TimeTravelEngine].
class TimeTravelConfig {
  /// Maximum number of records to keep in hot memory.
  final int maxHotRecords;

  /// Maximum number of snapshots to keep in the timeline.
  final int maxTimelineSnapshots;

  /// Auto-compress the timeline every [autoCompressInterval].
  /// Set to `null` to disable auto-compression.
  final Duration? autoCompressInterval;

  /// Auto-save the session to [defaultSessionPath] every [autoSaveInterval].
  /// Set to `null` to disable auto-save.
  final Duration? autoSaveInterval;

  /// Default path for auto-save and manual [saveSession].
  final String? defaultSessionPath;

  /// App name embedded in [SessionMetadata].
  final String appName;

  /// App version embedded in [SessionMetadata].
  final String appVersion;

  const TimeTravelConfig({
    this.maxHotRecords = 50000,
    this.maxTimelineSnapshots = 20000,
    this.autoCompressInterval = const Duration(seconds: 60),
    this.autoSaveInterval,
    this.defaultSessionPath,
    this.appName = 'unknown',
    this.appVersion = '0.0.0',
  });
}

/// # TimeTravelEngine
///
/// The main public API for the `time_travel_debugger` package.
///
/// ## Lifecycle
/// ```
/// TimeTravelEngine engine = TimeTravelEngine();
/// engine.startRecording();
/// ...record mutations...
/// StateSnapshot snap = engine.rewind(50);
/// engine.stopRecording();
/// engine.dispose();
/// ```
///
/// ## Thread safety
/// All public methods are synchronous and **not** thread-safe.
/// If you use multiple isolates, create one engine per isolate and
/// merge sessions after the fact.
class TimeTravelEngine {
  // ── Configuration ────────────────────────────────────────────────────────
  final TimeTravelConfig config;

  // ── Identity ─────────────────────────────────────────────────────────────
  /// Unique session ID (UUID v4), regenerated on each [startRecording] call.
  late String sessionId;

  // ── Internal components ──────────────────────────────────────────────────
  late MemoryRecorder _recorder;
  late ExecutionTimeline _timeline;
  late DateTime _recordingStartTime;

  // ── State ────────────────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isDisposed = false;

  // ── Timers ───────────────────────────────────────────────────────────────
  Timer? _autoCompressTimer;
  Timer? _autoSaveTimer;

  // ── Callbacks ────────────────────────────────────────────────────────────
  /// Called whenever a [BreakpointInfo]-style condition fires.
  /// Signature: `(variableName, newValue, stepNumber)`
  void Function(String variable, dynamic newValue, int step)?
      onBreakpointFired;

  /// Called after every auto-save completes (receives the path).
  void Function(String path)? onAutoSaved;

  // ── Constructor ──────────────────────────────────────────────────────────
  TimeTravelEngine({TimeTravelConfig? config})
      : config = config ?? const TimeTravelConfig() {
    _initialise();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises (or re-initialises) the engine internals.
  void _initialise() {
    sessionId = const Uuid().v4();
    _recorder = MemoryRecorder(
      maxRecords: config.maxHotRecords,
      onEvict: _timeline_onEvict,
    );
    _timeline = ExecutionTimeline(
      maxSnapshots: config.maxTimelineSnapshots,
    );
  }

  /// Starts recording.
  ///
  /// Throws [TimeTravelException] if already recording.
  void startRecording() {
    _assertNotDisposed();
    if (_isRecording) {
      throw const TimeTravelException(
          'Recording is already in progress. Call stopRecording() first.');
    }
    _isRecording = true;
    _isPaused = false;
    _recordingStartTime = DateTime.now();
    sessionId = const Uuid().v4();
    _setupTimers();
  }

  /// Pauses recording without clearing state.
  void pauseRecording() {
    _assertRecording();
    _isPaused = true;
  }

  /// Resumes a paused recording.
  void resumeRecording() {
    _assertRecording();
    _isPaused = false;
  }

  /// Stops recording and cancels background timers.
  void stopRecording() {
    _isRecording = false;
    _isPaused = false;
    _cancelTimers();
  }

  // ── Core recording API ────────────────────────────────────────────────────

  /// Records a single variable mutation.
  ///
  /// **This is the primary API call you make in your business logic.**
  ///
  /// ```dart
  /// final old = counter;
  /// counter++;
  /// engine.record(
  ///   name: 'counter',
  ///   oldValue: old,
  ///   newValue: counter,
  ///   file: 'counter_bloc.dart',
  ///   line: 42,
  ///   description: 'Incremented by button press',
  ///   tags: ['ui', 'counter'],
  /// );
  /// ```
  void record({
    required String name,
    required dynamic oldValue,
    required dynamic newValue,
    required String file,
    required int line,
    String? description,
    List<String> tags = const [],
    String? exceptionMessage,
    bool captureCallStack = false,
  }) {
    if (!_shouldRecord()) return;

    final record = VariableRecord(
      variableName: name,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
      sourceFile: file,
      lineNumber: line,
      description: description,
      dataType: newValue?.runtimeType.toString() ?? 'Null',
      exceptionMessage: exceptionMessage,
      tags: tags,
    );

    final absIndex = _recorder.addRecord(record);
    _timeline.addMutationEvent(record, absIndex);
  }

  /// Convenience shorthand: records a mutation and returns [newValue].
  ///
  /// Lets you instrument assignments inline:
  /// ```dart
  /// x = engine.track('x', x, x + 1, 'main.dart', 10);
  /// ```
  T track<T>(
    String name,
    dynamic oldValue,
    T newValue,
    String file,
    int line, {
    String? description,
    List<String> tags = const [],
  }) {
    record(
      name: name,
      oldValue: oldValue,
      newValue: newValue,
      file: file,
      line: line,
      description: description,
      tags: tags,
    );
    return newValue;
  }

  /// Records the entry into a function.
  void enterFunction({
    required String name,
    List<dynamic> params = const [],
    String file = '',
    int line = 0,
  }) {
    if (!_shouldRecord()) return;
    _timeline.addFunctionEntry(
      functionName: name,
      parameters: params.map((p) => p.toString()).toList(),
      file: file,
      line: line,
    );
  }

  /// Records the return from a function.
  void exitFunction({
    required String name,
    dynamic returnValue,
  }) {
    if (!_shouldRecord()) return;
    _timeline.addFunctionReturn(
      functionName: name,
      returnValue: returnValue,
    );
  }

  /// Adds a user annotation / bookmark to the current timeline position.
  ///
  /// Bookmarks are searchable and visible in the UI overlay.
  void annotate(String label) {
    if (!_shouldRecord()) return;
    _timeline.addAnnotation(label);
  }

  // ── Time-travel API ───────────────────────────────────────────────────────

  /// Moves the timeline cursor **backwards** by [steps] and returns the
  /// [StateSnapshot] at the new position.
  ///
  /// Throws [ArgumentError] if [steps] ≤ 0.
  StateSnapshot rewind(int steps) {
    _assertNotDisposed();
    if (steps <= 0) throw ArgumentError('steps must be > 0, got $steps.');
    final target = (_timeline.currentPosition - steps).clamp(0, _timeline.lastIndex);
    return _timeline.snapshotAt(target);
  }

  /// Moves the timeline cursor **forwards** by [steps].
  StateSnapshot fastForward(int steps) {
    _assertNotDisposed();
    if (steps <= 0) throw ArgumentError('steps must be > 0, got $steps.');
    final target =
        (_timeline.currentPosition + steps).clamp(0, _timeline.lastIndex);
    return _timeline.snapshotAt(target);
  }

  /// Jumps directly to [stepNumber] (0-based).
  StateSnapshot jumpTo(int stepNumber) {
    _assertNotDisposed();
    return _timeline.snapshotAt(stepNumber);
  }

  /// Returns the snapshot at the **current** cursor position.
  StateSnapshot currentSnapshot() {
    _assertNotDisposed();
    return _timeline.snapshotAt(_timeline.currentPosition);
  }

  /// Returns the **latest** recorded snapshot (end of timeline).
  StateSnapshot latestSnapshot() {
    _assertNotDisposed();
    return _timeline.snapshotAt(_timeline.lastIndex);
  }

  /// Returns all variables at an exact step, without moving the cursor.
  Map<String, dynamic> variablesAt(int step) {
    _assertNotDisposed();
    return _timeline.snapshotAt(step).variables;
  }

  // ── Search / Query API ────────────────────────────────────────────────────

  /// Step index of the first mutation of [variableName], or `null`.
  int? firstChangeOf(String variableName) =>
      _recorder.firstChangeOf(variableName);

  /// Step index of the last mutation of [variableName], or `null`.
  int? lastChangeOf(String variableName) =>
      _recorder.lastChangeOf(variableName);

  /// All step indices where [variableName] was mutated.
  List<int> allChangesOf(String variableName) =>
      _recorder.allChangesOf(variableName);

  /// Returns every [VariableRecord] for [variableName] in hot memory.
  List<VariableRecord> historyOf(String variableName) =>
      _recorder.recordsForVariable(variableName);

  /// Returns all bookmarked snapshots.
  List<StateSnapshot> bookmarks() => _timeline.bookmarkedSnapshots();

  /// Full-text search across record descriptions.
  List<VariableRecord> searchRecords(String query) =>
      _recorder.searchByDescription(query);

  // ── Session persistence ───────────────────────────────────────────────────

  /// Saves the current session to [filePath] (or [config.defaultSessionPath]).
  Future<void> saveSession([String? filePath]) async {
    final path = filePath ?? config.defaultSessionPath;
    if (path == null) {
      throw const TimeTravelException(
          'No filePath provided and no defaultSessionPath in config.');
    }
    final metadata = _buildMetadata();
    await _timeline.saveToDisk(path, metadata);
  }

  /// Loads a previously saved session from [filePath].
  Future<void> loadSession(String filePath) async {
    _assertNotDisposed();
    await _timeline.loadFromDisk(filePath);
  }

  // ── Introspection ─────────────────────────────────────────────────────────

  /// Whether the engine is currently recording.
  bool get isRecording => _isRecording;

  /// Whether recording is paused.
  bool get isPaused => _isPaused;

  /// Total number of steps on the timeline.
  int get totalSteps => _timeline.totalSteps;

  /// Current cursor position on the timeline.
  int get currentPosition => _timeline.currentPosition;

  /// Returns current performance statistics.
  PerformanceStats stats() {
    return PerformanceStats(
      totalEvents: _timeline.totalSteps,
      snapshotsInMemory: _timeline.totalSteps,
      snapshotsOnDisk: 0,
      hotCacheBytes: _recorder.estimatedMemoryBytes(),
      coldCacheBytes: 0,
      trackedVariables: _recorder.trackedVariableNames.length,
      sessionDuration: _isRecording
          ? DateTime.now().difference(_recordingStartTime)
          : Duration.zero,
      activeBreakpoints: 0,
      breakpointHits: 0,
      avgRecordingLatencyMicros: _recorder.averageLatencyMicros,
    );
  }

  // ── Maintenance ───────────────────────────────────────────────────────────

  /// Clears all recorded data without stopping the engine.
  void clearHistory() {
    _recorder.clear();
    _timeline.reset();
  }

  /// Disposes of the engine and releases all resources.
  void dispose() {
    _isDisposed = true;
    stopRecording();
    _recorder.dispose();
    _timeline.dispose();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  bool _shouldRecord() =>
      !_isDisposed && _isRecording && !_isPaused;

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw const TimeTravelException(
          'Engine has been disposed. Create a new instance.');
    }
  }

  void _assertRecording() {
    _assertNotDisposed();
    if (!_isRecording) {
      throw const TimeTravelException(
          'Engine is not recording. Call startRecording() first.');
    }
  }

  void _setupTimers() {
    if (config.autoCompressInterval != null) {
      _autoCompressTimer = Timer.periodic(
        config.autoCompressInterval!,
        (_) => _timeline.compress(),
      );
    }
    if (config.autoSaveInterval != null &&
        config.defaultSessionPath != null) {
      _autoSaveTimer = Timer.periodic(
        config.autoSaveInterval!,
        (_) async {
          try {
            await saveSession();
            onAutoSaved?.call(config.defaultSessionPath!);
          } catch (_) {
            // Silently ignore auto-save failures.
          }
        },
      );
    }
  }

  void _cancelTimers() {
    _autoCompressTimer?.cancel();
    _autoSaveTimer?.cancel();
  }

  /// Hook called by [MemoryRecorder] when a record is evicted from hot memory.
  void _timeline_onEvict(VariableRecord record) {
    // Future: send to cold-cache / disk persistence layer.
  }

  SessionMetadata _buildMetadata() => SessionMetadata(
        sessionId: sessionId,
        appName: config.appName,
        appVersion: config.appVersion,
        dartVersion: '3.x',
        platform: 'dart',
        startTime: _recordingStartTime,
        endTime: _isRecording ? null : DateTime.now(),
        packageVersion: '1.0.0',
      );
}
