# 🕰 time_travel_debugger

> **Ultra-Pro time-travel debugging for Dart & Flutter.**  
> Record every state change, then rewind step-by-step to inspect variable
> values at any point in your execution history.

[![Dart SDK](https://img.shields.io/badge/Dart-≥3.0.0-0175C2?logo=dart)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-≥3.10.0-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

<img width="1000" height="568" alt="image" src="https://github.com/user-attachments/assets/0dcf09f0-97d5-40fc-856b-a13eadb3e352" />




## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔴 **Live recording** | Capture every variable mutation with sub-ms overhead |
| ⏪ **Time-travel** | `rewind(n)`, `fastForward(n)`, `jumpTo(step)` |
| 🔖 **Bookmarks** | Annotate key moments for instant navigation |
| 🔴 **Conditional breakpoints** | Fire on any predicate — log, pause, throw, or rewind |
| 👁 **Watchpoints** | Pure observers for live analytics without stopping execution |
| 🔍 **DiffEngine** | Visual diff between any two snapshots |
| 💾 **Session persistence** | Save / reload `.ttd` session files |
| 📊 **Reports** | HTML, JSON, Markdown, Plain Text output |
| 🗜 **Delta compression** | Deduplicate consecutive snapshots automatically |
| 🌡 **Two-tier cache** | Hot LRU cache + cold tier + optional disk overflow |
| 🎨 **Flutter overlay** | Draggable debug panel with timeline scrubber & variable inspector |

---

## 📦 Installation

```yaml
dependencies:
  time_travel_debugger: ^1.0.0
```

```bash
dart pub get
```

---

## 🚀 Quick Start

```dart
import 'package:time_travel_debugger/time_travel_debugger.dart';

void main() async {
  final engine = TimeTravelEngine();
  engine.startRecording();

  // Option A – explicit record()
  int x = 0;
  engine.record(name: 'x', oldValue: null, newValue: x,
                file: 'main.dart', line: 8);

  for (int i = 0; i < 100; i++) {
    x = engine.track('x', x, x + i, 'main.dart', 12);
  }

  // Time-travel ─────────────────────────────────────
  final snap = engine.rewind(10);         // 10 steps back
  print(snap.variable('x'));              // value 10 steps ago

  final step0 = engine.jumpTo(0);         // absolute step
  print(step0.variableNames);             // all vars at that moment

  // Query ────────────────────────────────────────────
  print(engine.firstChangeOf('x'));       // step index
  print(engine.allChangesOf('x').length); // total mutations

  // Save ─────────────────────────────────────────────
  await engine.saveSession('/tmp/debug.ttd');

  engine.dispose();
}
```

---

## 🎯 Core API

### TimeTravelEngine

| Method | Description |
|--------|-------------|
| `startRecording()` | Begin capturing mutations |
| `stopRecording()` | Stop (keeps history intact) |
| `pauseRecording()` / `resumeRecording()` | Temporarily suspend |
| `record({name, oldValue, newValue, file, line, ...})` | Record a mutation |
| `track<T>(name, old, new, file, line)` | Record + return `new` (inline use) |
| `enterFunction({name, ...})` / `exitFunction(...)` | Record function calls |
| `annotate(label)` | Insert a named bookmark |
| `rewind(n)` | Move cursor back n steps → returns snapshot |
| `fastForward(n)` | Move cursor forward n steps |
| `jumpTo(step)` | Absolute jump |
| `currentSnapshot()` | Snapshot at cursor |
| `latestSnapshot()` | Most recent snapshot |
| `variablesAt(step)` | `Map<String, dynamic>` at step |
| `firstChangeOf(name)` / `lastChangeOf(name)` | Search step indices |
| `allChangesOf(name)` | All step indices for a variable |
| `historyOf(name)` | `List<VariableRecord>` in hot memory |
| `bookmarks()` | All annotated snapshots |
| `searchRecords(query)` | Full-text search in descriptions |
| `stats()` | `PerformanceStats` object |
| `saveSession([path])` / `loadSession(path)` | Persist to disk |
| `clearHistory()` | Reset without stopping |
| `dispose()` | Release all resources |

### StateSnapshot

```dart
snap.variable('x')          // get value
snap.hasVariable('x')       // bool
snap.variableNames          // sorted List<String>
snap.filterVariables('pa')  // filter by pattern
snap.diff(otherSnap)        // Map<name, {before, after}>
snap.callStack              // List<CallStackFrame>
snap.currentFunction        // String? (innermost frame)
snap.withBookmark('label')  // copies with bookmark
```

---

## 🔴 Breakpoints

```dart
final bp = BreakpointManager();

bp.addVariableBreakpoint(
  variableName: 'health',
  condition: (newVal, oldVal) => (newVal as int) < 20,
  description: 'health critical',
  action: BreakpointAction.log,      // or .pause / .throwException / .rewindAndReport
  maxHitCount: 5,
);

bp.onBreakpointFired = (event) {
  print('Breakpoint fired @ step ${event.step}: '
        '${event.trigger.variableName} = ${event.trigger.newValue}');
};

// In your recording loop:
final rec = engine.historyOf('health').last;
bp.evaluateRecord(rec, engine.currentPosition);
```

---

## 👁 Watchpoints

```dart
final wm = WatchpointManager();

wm.add(
  variableName: 'score',
  callback: (r) => analyticsService.track(r.newValue),
  filter: (nv, ov) => (nv as int) > (ov as int? ?? 0),
);

// After every record():
wm.notify(engine.historyOf('score').last);
```

---

## 🔍 DiffEngine

```dart
const diff = DiffEngine();

final before = engine.jumpTo(0);
final after  = engine.latestSnapshot();

final result = diff.diff(after, before);
print(result.modified);   // List<DiffEntry>
print(result.added);
print(result.toText());   // pretty multi-line string
```

---

## 📊 Reports

```dart
final gen = ReportGenerator(
  metadata: engine.sessionMetadata,
  snapshots: [],
  records: engine.historyOf('counter'),
  stats: engine.stats(),
);

// HTML (dark-mode, table-based)
await gen.saveReport('report.html', format: ReportFormat.html);

// Markdown
await gen.saveReport('report.md', format: ReportFormat.markdown);

// JSON
final json = gen.generate(format: ReportFormat.json);

// Plain text
print(gen.generate(format: ReportFormat.plainText));
```

---

## 🎨 Flutter Overlay

```dart
void main() {
  final engine = TimeTravelEngine();
  engine.startRecording();

  runApp(
    TimeTravelWidget(
      engine: engine,
      child: MyApp(),
    ),
  );
}
```

The overlay adds a **draggable panel** with:
- **Timeline scrubber** (slider + nav buttons + quick-jump field)
- **Bookmark strip** for instant navigation
- **Variables tab** (searchable, type-annotated, click-to-copy)
- **Call stack tab**
- **Changes tab** (mutations that produced this snapshot)

Open the full variable history with:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => VariableInspector(
    engine: engine,
    variableName: 'counter',
  ),
));
```

---

## ⚙️ Configuration

```dart
TimeTravelEngine(
  config: TimeTravelConfig(
    maxHotRecords: 50000,          // records in RAM
    maxTimelineSnapshots: 20000,   // snapshots in RAM
    autoCompressInterval: Duration(seconds: 60), // null = disabled
    autoSaveInterval: Duration(minutes: 5),
    defaultSessionPath: '/tmp/app.ttd',
    appName: 'MyApp',
    appVersion: '2.0.0',
  ),
)
```

---

## 📁 Package Structure

```
lib/
├── time_travel_debugger.dart   # Public API (single import)
└── src/
    ├── core/
    │   ├── time_travel_engine.dart    ← Main public class
    │   ├── state_snapshot.dart        ← Immutable state capture
    │   ├── memory_recorder.dart       ← Hot record store + index
    │   └── execution_timeline.dart    ← Ordered event + snapshot log
    ├── models/
    │   ├── variable_record.dart       ← Single mutation event
    │   ├── call_stack_frame.dart      ← Call-stack frame
    │   ├── breakpoint_info.dart       ← Breakpoint descriptor
    │   ├── timeline_event.dart        ← Typed timeline entry
    │   ├── performance_stats.dart     ← Runtime metrics
    │   └── session_metadata.dart      ← Session header
    ├── storage/
    │   ├── history_storage.dart       ← Multi-strategy warm cache
    │   ├── memory_cache.dart          ← Two-tier LRU cache
    │   └── disk_persistence.dart      ← .ttd file I/O
    ├── debugger/
    │   ├── breakpoint_manager.dart    ← Conditional breakpoints
    │   ├── watchpoint_manager.dart    ← Pure-observer watchpoints
    │   ├── diff_engine.dart           ← Snapshot diffs
    │   └── report_generator.dart      ← HTML/JSON/MD/text reports
    ├── ui/                            ← Flutter widgets
    │   ├── time_travel_widget.dart    ← Root overlay wrapper
    │   ├── snapshot_viewer.dart       ← Variables/Stack/Changes tabs
    │   ├── timeline_ui.dart           ← Scrubber + bookmarks
    │   └── variable_inspector.dart    ← Full variable history page
    └── utils/
        ├── serialization.dart         ← JSON helpers
        ├── compression.dart           ← Delta + gzip + RLE
        ├── ttd_logger.dart            ← Internal logger
        └── type_inspector.dart        ← Runtime type display
```

---

## 🔒 Performance Notes

- **Recording path**: `record()` does ≈1–3 µs average (rolling 1 000-call window).
- **Eviction**: When `maxHotRecords` is reached, oldest records are evicted via
  the `onEvict` hook — plug in your [DiskPersistence] there.
- **Compression**: Call `engine.timeline.compress()` or rely on the
  `autoCompressInterval` to deduplicate consecutive identical snapshots.
- **Flutter overlay**: rendered only in debug builds unless `showInRelease: true`.

---

## 📜 License

[MIT](LICENSE) © 2026 TIMSoftDZ
