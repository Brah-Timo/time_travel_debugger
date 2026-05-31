# Configuration Reference — `time_travel_debugger`

## `TimeTravelConfig`

Pass a `TimeTravelConfig` instance to `TimeTravelEngine` to customise behaviour.
All fields have sensible defaults so you can start with zero configuration.

```dart
final engine = TimeTravelEngine(
  config: const TimeTravelConfig(
    appName: 'MyApp',
    appVersion: '1.0.0',
    maxHotRecords: 50000,
    maxTimelineSnapshots: 50000,
    autoCompressInterval: Duration(seconds: 60),
    defaultSessionPath: 'debug/session.ttd',
    captureCallStack: false,
  ),
);
```

### Field reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `appName` | `String` | `'UnknownApp'` | Embedded in session metadata and reports. |
| `appVersion` | `String` | `'0.0.0'` | Semantic version string. |
| `maxHotRecords` | `int` | `50000` | Maximum `VariableRecord` objects held in the hot `MemoryRecorder` cache before FIFO eviction. |
| `maxTimelineSnapshots` | `int` | `50000` | Maximum materialised `StateSnapshot` objects in `ExecutionTimeline`. Older snapshots are evicted to cold storage. |
| `autoCompressInterval` | `Duration?` | `Duration(seconds: 60)` | How often to run the deduplication compression pass. `null` disables auto-compression. |
| `defaultSessionPath` | `String?` | `null` | Path used by `engine.saveSession()` when no path argument is supplied. |
| `captureCallStack` | `bool` | `false` | When `true`, every `record()` call captures the current Dart call stack (≈5–15 µs overhead). Useful for deep debugging; disable in production. |

---

## `MemoryRecorder` options

`MemoryRecorder` can be constructed directly if you need lower-level control:

```dart
final recorder = MemoryRecorder(
  maxRecords: 10000,
  onEvict: (evicted) {
    // Persist evicted records before they are discarded
    DiskPersistence.saveRecords(sessionId: sid, records: evicted);
  },
);
```

| Parameter | Description |
|-----------|-------------|
| `maxRecords` | Hard cap on in-memory records. Default: `50000`. |
| `onEvict` | Callback fired with the list of records about to be discarded. |

---

## `MemoryCache` options

```dart
final cache = MemoryCache<String, StateSnapshot>(
  hotCapacity: 1000,
  coldCapacity: 5000,
  decompress: (key) async {
    return await DiskPersistence.loadSnapshot(key);
  },
);
```

| Parameter | Description |
|-----------|-------------|
| `hotCapacity` | Max items in the hot (LRU) tier. |
| `coldCapacity` | Max keys tracked in the cold set (no data held). |
| `decompress` | Async factory used to reload cold items on demand. |

---

## `HistoryStorage` eviction policies

```dart
// FIFO (default)
final storage = HistoryStorage<int, StateSnapshot>(
  capacity: 2000,
  evictionPolicy: EvictionPolicy.fifo,
);

// LRU
final storage = HistoryStorage<int, StateSnapshot>(
  capacity: 2000,
  evictionPolicy: EvictionPolicy.lru,
);

// LFU
final storage = HistoryStorage<int, StateSnapshot>(
  capacity: 2000,
  evictionPolicy: EvictionPolicy.lfu,
);
```

---

## `DiskPersistence` options

```dart
final disk = DiskPersistence(
  sessionDir: '/data/ttd_sessions',
  prettyPrint: false,       // compact JSON for production
  streamingThreshold: 5000, // switch to streaming mode above N events
);
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `sessionDir` | system temp | Directory where `.ttd` files are written. |
| `prettyPrint` | `false` | Indented JSON (debugging) vs compact (production). |
| `streamingThreshold` | `10000` | Event count above which streaming (line-delimited JSON) is used to avoid peak memory. |

---

## `TtdLogger` configuration

```dart
// Set minimum log level
TtdLogger.instance.level = TtdLogLevel.warning; // debug | info | warning | error

// Add a custom sink
TtdLogger.instance.addSink((message) {
  myRemoteLogger.send(message);
});

// Remove all sinks (silence the logger)
TtdLogger.instance.clearSinks();
```

---

## Environment-specific presets

### Development (verbose)

```dart
const TimeTravelConfig(
  appName: 'MyApp',
  appVersion: '1.0.0',
  maxHotRecords: 100000,
  maxTimelineSnapshots: 100000,
  captureCallStack: true,
  autoCompressInterval: Duration(seconds: 30),
)
```

### CI / integration tests

```dart
const TimeTravelConfig(
  appName: 'TestApp',
  appVersion: 'test',
  maxHotRecords: 5000,
  maxTimelineSnapshots: 5000,
  autoCompressInterval: null, // deterministic — no background work
  defaultSessionPath: '/tmp/test_session.ttd',
)
```

### Production / embedded (minimal overhead)

```dart
// Only enable in kDebugMode — see Flutter integration guide.
// If you must enable in production, use conservative limits:
const TimeTravelConfig(
  appName: 'MyApp',
  appVersion: '2.1.0',
  maxHotRecords: 5000,
  maxTimelineSnapshots: 1000,
  captureCallStack: false,
  autoCompressInterval: Duration(minutes: 5),
)
```
