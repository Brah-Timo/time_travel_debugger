import 'package:time_travel_debugger/time_travel_debugger.dart';

/// Pre-built test fixtures used by unit and integration tests.
class MockData {
  MockData._();

  // ── VariableRecord factories ───────────────────────────────────────────────

  static VariableRecord intRecord({
    String name = 'x',
    dynamic oldValue = 0,
    dynamic newValue = 1,
    String file = 'test.dart',
    int line = 10,
    int index = 0,
  }) =>
      VariableRecord(
        variableName: name,
        oldValue: oldValue,
        newValue: newValue,
        timestamp: DateTime(2024, 1, 1, 0, 0, 0, index * 10),
        sourceFile: file,
        lineNumber: line,
        dataType: 'int',
        recordIndex: index,
      );

  static VariableRecord stringRecord({
    String name = 'label',
    dynamic oldValue = 'hello',
    dynamic newValue = 'world',
    int index = 0,
  }) =>
      VariableRecord(
        variableName: name,
        oldValue: oldValue,
        newValue: newValue,
        timestamp: DateTime(2024, 1, 1, 0, 0, 0, index * 10),
        sourceFile: 'test.dart',
        lineNumber: 20,
        dataType: 'String',
        recordIndex: index,
      );

  static VariableRecord listRecord({int index = 0}) => VariableRecord(
        variableName: 'items',
        oldValue: <int>[],
        newValue: <int>[1, 2, 3],
        timestamp: DateTime(2024, 1, 1, 0, 0, 0, index * 10),
        sourceFile: 'test.dart',
        lineNumber: 30,
        dataType: 'List<int>',
        recordIndex: index,
      );

  // ── StateSnapshot factories ───────────────────────────────────────────────

  static StateSnapshot snapshot({
    int step = 0,
    Map<String, dynamic>? variables,
    String? description,
  }) =>
      StateSnapshot(
        snapshotId: 'snap-$step',
        stepNumber: step,
        timestamp: DateTime(2024, 1, 1, 0, 0, step),
        variables: variables ?? {'x': step, 'label': 'step$step'},
        callStack: [],
        description: description ?? 'Step $step',
      );

  /// Builds a list of [count] snapshots with incrementing `x` values.
  static List<StateSnapshot> snapshotSeries(int count) => List.generate(
        count,
        (i) => snapshot(step: i, variables: {'x': i, 'y': i * 2}),
      );

  // ── Engine factory ────────────────────────────────────────────────────────

  /// Creates and starts a pre-warmed [TimeTravelEngine] with [eventCount]
  /// pre-recorded integer mutations on variable `"counter"`.
  static TimeTravelEngine warmEngine({int eventCount = 100}) {
    final engine = TimeTravelEngine(
      config: const TimeTravelConfig(
        maxHotRecords: 5000,
        maxTimelineSnapshots: 5000,
        autoCompressInterval: null,
      ),
    );
    engine.startRecording();
    for (var i = 0; i < eventCount; i++) {
      engine.record(
        name: 'counter',
        oldValue: i,
        newValue: i + 1,
        file: 'mock.dart',
        line: 1,
        description: 'Iteration $i',
      );
    }
    return engine;
  }
}
