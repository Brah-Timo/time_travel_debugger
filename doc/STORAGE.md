# Storage & Persistence Guide — `time_travel_debugger`

## Overview

`time_travel_debugger` uses a layered storage system:

```
Hot MemoryRecorder (flat list + inverted index)
       │  evict (FIFO) ↓
HistoryStorage (FIFO / LRU / LFU warm cache)
       │  evict ↓
MemoryCache (two-tier LRU: hot + cold keys)
       │  cold-miss → decompress ↓
DiskPersistence (.ttd JSON files)
```

Each layer is independently configurable and the layers can be used
standalone if needed.

---

## `MemoryRecorder` — hot record list

The innermost layer. Holds up to `maxRecords` `VariableRecord` objects in
a `List<VariableRecord>`. An inverted index
(`Map<String, List<int>>`) maps each variable name to its absolute record
indices for O(1) lookup.

```dart
final recorder = MemoryRecorder(maxRecords: 50000);
recorder.addRecord(VariableRecord(
  variableName: 'x',
  oldValue: 0,
  newValue: 42,
  timestamp: DateTime.now(),
  sourceFile: 'main.dart',
  lineNumber: 10,
  recordIndex: 0,
));

// Retrieve all records for 'x'
final xRecords = recorder.recordsFor('x');

// Statistics
print(recorder.totalRecords);
print(recorder.trackedVariables);
```

---

## `HistoryStorage` — warm cache with eviction policy

Wraps any `Map`-like store with configurable eviction:

```dart
final storage = HistoryStorage<int, StateSnapshot>(
  capacity: 2000,
  evictionPolicy: EvictionPolicy.lru,
);

storage.put(42, mySnapshot);
final snap = storage.get(42);   // null if evicted
```

Eviction policies:
- `EvictionPolicy.fifo` — First-in, first-out. Predictable for timeline data.
- `EvictionPolicy.lru` — Least-recently used. Good for interactive debugging.
- `EvictionPolicy.lfu` — Least-frequently used. Good for long sessions where
  some steps are never revisited.

---

## `MemoryCache` — two-tier snapshot cache

The hot tier is an LRU `LinkedHashMap<K, V>` capped at `hotCapacity`.
When a hot entry is evicted, its key moves to the cold `LinkedHashSet<K>`.
On a cold-hit, the async `decompress(key)` callback reloads the value
from disk and promotes it back to hot.

```dart
final cache = MemoryCache<String, StateSnapshot>(
  hotCapacity: 500,
  coldCapacity: 2000,
  decompress: (id) async {
    final json = await File('/sessions/$id.json').readAsString();
    return StateSnapshot.fromJson(jsonDecode(json));
  },
);

// Write
cache.put('snap_42', snapshot);

// Read (hot or cold-promote)
final snap = await cache.getOrLoad('snap_42');
```

---

## `DiskPersistence` — `.ttd` file format

Sessions are saved as `.ttd` files (JSON under the hood).

### Saving a session

```dart
final disk = DiskPersistence(sessionDir: '/data/debug');

// High-level (via engine)
await engine.saveSession('/data/debug/my_session.ttd');

// Low-level
await disk.saveSession(
  sessionId: engine.sessionId,
  metadata: engine.metadata,
  snapshots: timeline.allSnapshots,
  events: timeline.allEvents,
);
```

### Loading a session

```dart
// Via engine
final engine = TimeTravelEngine();
await engine.loadSession('/data/debug/my_session.ttd');

// Low-level
final loaded = await disk.loadSession('/data/debug/my_session.ttd');
print(loaded.snapshots.length);
```

### File format

```json
{
  "ttdVersion": "1.0",
  "metadata": {
    "sessionId": "550e8400-...",
    "appName": "MyApp",
    "appVersion": "1.2.3",
    "dartVersion": "3.3.0",
    "platform": "android",
    "startTime": "2024-01-15T10:30:00.000Z",
    "packageVersion": "1.0.0"
  },
  "snapshots": [
    {
      "snapshotId": "abc123",
      "stepNumber": 0,
      "timestamp": "2024-01-15T10:30:00.001Z",
      "variables": { "counter": 0 },
      "callStack": [],
      "description": null,
      "changes": [],
      "bookmarkLabel": null
    }
  ],
  "events": [
    {
      "index": 0,
      "kind": "variableMutation",
      "variableName": "counter",
      "oldValue": null,
      "newValue": 0,
      "sourceFile": "main.dart",
      "lineNumber": 5,
      "timestamp": "2024-01-15T10:30:00.001Z"
    }
  ]
}
```

### Streaming mode

For sessions with more than `streamingThreshold` events (default: 10 000),
`DiskPersistence` switches to streaming line-delimited JSON to avoid loading
the entire file into memory at once:

```
{"ttdVersion":"1.0","metadata":{...}}
{"kind":"snapshot","data":{...}}
{"kind":"event","data":{...}}
...
```

---

## Unlimited history with `onEvict`

Combine `MemoryRecorder.onEvict` with `DiskPersistence` for a theoretically
unlimited recording buffer:

```dart
final disk = DiskPersistence(sessionDir: tempDir);

final recorder = MemoryRecorder(
  maxRecords: 10000,
  onEvict: (records) async {
    await disk.appendRecords(
      sessionId: engine.sessionId,
      records: records,
    );
  },
);
```

This pattern keeps RAM bounded while allowing post-session analysis of the
complete history from disk.

---

## Cross-isolate sessions

Each Dart isolate must have its own `TimeTravelEngine`. After the run,
merge session files:

```dart
// In the main isolate, after sub-isolates finish:
final merged = await DiskPersistence.mergeSessions([
  '/tmp/isolate_1.ttd',
  '/tmp/isolate_2.ttd',
], output: '/tmp/merged.ttd');
```

> **Note:** `mergeSessions` sorts events by timestamp so the merged timeline
> is chronologically consistent.
