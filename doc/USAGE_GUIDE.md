# Usage Guide — `time_travel_debugger`

## 1. Basic setup (Dart-only)

```dart
import 'package:time_travel_debugger/time_travel_debugger.dart';

final engine = TimeTravelEngine(
  config: const TimeTravelConfig(
    appName: 'MyApp',
    appVersion: '1.0.0',
  ),
);
engine.startRecording();
```

## 2. Recording mutations

### Explicit `record()`

```dart
final old = counter;
counter++;
engine.record(
  name: 'counter',
  oldValue: old,
  newValue: counter,
  file: 'counter_bloc.dart',
  line: 42,
  description: 'Incremented by button press',
  tags: ['ui', 'counter'],
);
```

### Inline `track()` shorthand

```dart
// Returns newValue so the assignment is unmodified.
counter = engine.track('counter', counter, counter + 1, 'bloc.dart', 42);
```

### Recording function calls

```dart
engine.enterFunction(name: 'fetchUser', file: 'api.dart', line: 10);
final user = await apiClient.getUser(id);
engine.record(name: 'user', oldValue: null, newValue: user.toJson(),
    file: 'api.dart', line: 13);
engine.exitFunction(name: 'fetchUser', returnValue: user);
```

## 3. Time-travel

```dart
// Move back 50 steps
final snap = engine.rewind(50);
print(snap.variable('counter'));

// Jump to exact step
final step0 = engine.jumpTo(0);

// Navigate forward
engine.fastForward(10);

// Back to the present
engine.latestSnapshot();
```

## 4. Annotating key moments

```dart
engine.annotate('User login complete');
// Later:
final loginSnap = engine.bookmarks()
    .firstWhere((s) => s.bookmarkLabel!.contains('login'));
```

## 5. Conditional breakpoints

```dart
final bp = BreakpointManager();
bp.addVariableBreakpoint(
  variableName: 'errorCount',
  condition: (nv, ov) => (nv as int) > 5,
  action: BreakpointAction.log,
);

// After every engine.record() for 'errorCount':
final rec = engine.historyOf('errorCount').last;
bp.evaluateRecord(rec, engine.currentPosition);
```

## 6. Watchpoints (non-blocking observers)

```dart
final wm = WatchpointManager();
wm.add(
  variableName: 'price',
  callback: (r) => analyticsService.log('price', r.newValue),
  filter: (nv, ov) => nv != ov,
);
// After recording:
wm.notify(engine.historyOf('price').last);
```

## 7. Diffing snapshots

```dart
const diff = DiffEngine();
final a = engine.jumpTo(100);
final b = engine.latestSnapshot();
final result = diff.diff(b, a);
for (final e in result.modified) {
  print(e.summary);
}
```

## 8. Saving and reloading sessions

```dart
// Save
await engine.saveSession('/path/to/session.ttd');

// Reload in a new process
final newEngine = TimeTravelEngine();
await newEngine.loadSession('/path/to/session.ttd');
print(newEngine.totalSteps);
```

## 9. Generating reports

```dart
final gen = ReportGenerator(
  metadata: SessionMetadata(
    sessionId: engine.sessionId,
    appName: 'MyApp',
    appVersion: '1.0.0',
    dartVersion: '3.x',
    platform: 'android',
    startTime: DateTime.now(),
    packageVersion: '1.0.0',
  ),
  snapshots: [],
  records: engine.historyOf('counter'),
  stats: engine.stats(),
);
await gen.saveReport('debug_report.html');
```

## 10. Flutter overlay

```dart
// In main():
runApp(
  TimeTravelWidget(
    engine: engine,
    child: const MyApp(),
  ),
);

// Full variable history (navigate from any screen):
Navigator.push(context, MaterialPageRoute(
  builder: (_) => VariableInspector(
    engine: engine,
    variableName: 'selectedItem',
  ),
));
```

## 11. Custom logger sinks

```dart
TtdLogger.instance.level = TtdLogLevel.debug;
TtdLogger.instance.addSink((msg) => FirebaseAnalytics.log(msg));
```

## 12. Memory management tips

- Set `maxHotRecords` to a value your device can handle comfortably
  (`50 000` ≈ 6 MB at default overhead estimates).
- Use `autoCompressInterval` to free duplicate snapshots every minute.
- Hook `MemoryRecorder.onEvict` → `DiskPersistence.saveSnapshot` to create
  an unlimited cold history on disk.
- Call `engine.clearHistory()` between logical test runs without rebuilding
  the engine.
