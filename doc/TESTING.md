# Testing Guide — `time_travel_debugger`

## Running the tests

```bash
# All tests (requires Flutter SDK for flutter test)
flutter test

# Dart-VM-only tests (no Flutter SDK required)
dart test test/unit/
dart test test/integration/
```

---

## Test structure

```
test/
├── fixtures/
│   └── mock_data.dart        — Shared helpers: MockData.snapshot(), MockData.record(), etc.
├── unit/
│   ├── variable_record_test.dart
│   ├── state_snapshot_test.dart
│   ├── memory_recorder_test.dart
│   └── time_travel_engine_test.dart
└── integration/
    └── full_recording_test.dart  — End-to-end session, breakpoints, reports, compression
```

---

## Writing unit tests for your own code

### Testing recorded values

```dart
import 'package:test/test.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';

void main() {
  late TimeTravelEngine engine;

  setUp(() {
    engine = TimeTravelEngine(
      config: const TimeTravelConfig(
        appName: 'UnitTest',
        appVersion: '0.0.0',
        autoCompressInterval: null, // keep tests deterministic
        maxHotRecords: 1000,
        maxTimelineSnapshots: 1000,
      ),
    );
    engine.startRecording();
  });

  tearDown(() => engine.dispose());

  test('counter increments correctly', () {
    int counter = 0;
    for (var i = 0; i < 5; i++) {
      final old = counter;
      counter++;
      engine.record(name: 'counter', oldValue: old, newValue: counter,
          file: 'my_bloc.dart', line: 10);
    }

    final latest = engine.latestSnapshot();
    expect(latest.variable('counter'), equals(5));

    // Rewind two steps: counter should be 3
    final rewound = engine.rewind(2);
    expect(rewound.variable('counter'), equals(3));
  });
}
```

### Testing breakpoints

```dart
test('breakpoint fires when threshold exceeded', () {
  engine.startRecording();

  final bp = BreakpointManager();
  final events = <BreakpointEvent>[];
  bp.onBreakpointFired = events.add;

  bp.addVariableBreakpoint(
    variableName: 'temperature',
    condition: (nv, _) => (nv as double) > 100.0,
    description: 'overheating',
    action: BreakpointAction.log,
  );

  for (double t = 90.0; t <= 110.0; t += 2.0) {
    engine.record(name: 'temperature', oldValue: t - 2.0, newValue: t,
        file: 'sensor.dart', line: 5);
    final rec = engine.historyOf('temperature').last;
    bp.evaluateRecord(rec, engine.currentPosition);
  }

  expect(events, isNotEmpty);
  expect((events.first.trigger.newValue as double), greaterThan(100.0));
});
```

### Testing reports

```dart
test('json report contains variable summary', () {
  engine.startRecording();
  engine.record(name: 'x', oldValue: 0, newValue: 42,
      file: 'f.dart', line: 1);
  engine.stopRecording();

  final gen = ReportGenerator(
    metadata: SessionMetadata(
      sessionId: 'test',
      appName: 'Test',
      appVersion: '1.0',
      dartVersion: '3.x',
      platform: 'test',
      startTime: DateTime.now(),
      packageVersion: '1.0.0',
    ),
    snapshots: [],
    records: engine.historyOf('x'),
    stats: engine.stats(),
  );

  final json = gen.generate(format: ReportFormat.json);
  expect(json, contains('"reportType"'));
  expect(json, contains('"x"'));
});
```

---

## Using `MockData`

The `test/fixtures/mock_data.dart` helper provides ready-made objects:

```dart
import '../fixtures/mock_data.dart';

final record   = MockData.record();         // VariableRecord with defaults
final snapshot = MockData.snapshot();       // StateSnapshot with defaults
final engine   = MockData.engineWithData(); // pre-loaded engine (20 records)
```

---

## Integration test tips

1. **Use a temp directory** — `Directory.systemTemp.createTempSync('ttd_test_')` so tests are isolated and cleaned up in `tearDownAll`.
2. **Disable auto-compression** — pass `autoCompressInterval: null` for deterministic event counts.
3. **Set small caps** — `maxHotRecords: 5000` is plenty for integration tests and avoids OOM on CI.
4. **Dispose after each test** — call `engine.dispose()` in `tearDown` to release timers and caches.
5. **Parallel safety** — each `group` gets its own `engine` instance; never share across groups without synchronisation.

---

## Coverage

Run with coverage:

```bash
# Flutter
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Dart only
dart test --coverage=coverage
dart pub run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json --report-on=lib
```
