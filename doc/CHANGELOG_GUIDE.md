# Changelog & Migration Guide — `time_travel_debugger`

## v1.0.0 — Initial Release

### New Features

- **`TimeTravelEngine`** — Central orchestrator for recording, rewinding, and
  fast-forwarding through execution history.
- **`MemoryRecorder`** — High-throughput hot cache with inverted index for O(1)
  `firstChangeOf` / `lastChangeOf` lookups.
- **`ExecutionTimeline`** — Materialised snapshot store; O(1) random access to
  any step without replay.
- **`StateSnapshot`** — Immutable snapshot of all tracked variables at a given
  step, with call-stack and bookmark support.
- **`VariableRecord`** — Lightweight mutation record: `oldValue`, `newValue`,
  `timestamp`, `sourceFile`, `lineNumber`, tags.
- **`DiffEngine`** — Snapshot-level and record-level diffing; timeline diff
  producing only changed steps.
- **`BreakpointManager`** — Variable and function breakpoints with conditions,
  hit counts, and pluggable actions (`log`, `pause`, `callback`).
- **`WatchpointManager`** — Non-blocking observers with filter predicates;
  decoupled from the recording path.
- **`ReportGenerator`** — Four output formats: `html`, `json`, `markdown`,
  `plainText`. Async `saveReport()` to disk.
- **`Compression`** — Delta encoding, run-length encoding, and gzip wrappers
  for snapshot payloads.
- **`HistoryStorage`** — FIFO / LFU / LRU eviction strategies; configurable
  warm cache on top of `MemoryCache`.
- **`MemoryCache`** — Two-tier LRU (hot + cold) with lazy cold-to-hot
  promotion via a user-supplied `decompress` callback.
- **`DiskPersistence`** — `.ttd` JSON file format; streaming write mode for
  sessions > 100 000 events; `saveSession` / `loadSession` APIs.
- **Flutter UI overlay** — `TimeTravelWidget`, `SnapshotViewer`,
  `VariableInspector`, `TimelineUI`; conditionally exported (stub on web /
  pure-Dart environments).
- **`TtdLogger`** — Pluggable structured logger with level filtering and
  multiple sinks.
- **`TypeInspector`** — Runtime type classification, pretty-printed
  `displayValue`, `typeName`, and `diffString` helpers.

---

## Migration Guide

### From pre-release to v1.0.0

The API is considered stable as of v1.0.0. No breaking changes are expected
in the v1.x line. If you were using an internal / pre-release build, check
the following renamed symbols:

| Old name | New name |
|----------|----------|
| `Debugger` | `TimeTravelEngine` |
| `Snapshot` | `StateSnapshot` |
| `Record` | `VariableRecord` |
| `BreakManager` | `BreakpointManager` |

### pubspec.yaml

```yaml
dependencies:
  time_travel_debugger: ^1.0.0
```

Minimum SDK: `>=3.0.0 <4.0.0`  
Minimum Flutter: `>=3.10.0` (optional; only needed for UI overlay)
