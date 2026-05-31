# Performance Guide — `time_travel_debugger`

## Benchmarks (reference device: MacBook Pro M2, Dart 3.3)

| Operation | Avg latency |
|-----------|-------------|
| `engine.record()` | **1–3 µs** |
| `engine.rewind(1)` | < 1 µs (O(1) array lookup) |
| `engine.jumpTo(N)` | < 1 µs |
| `engine.firstChangeOf(name)` | < 1 µs |
| `Compression.computeDelta(100 vars)` | ≈ 4 µs |
| `StateSnapshot.fromJson()` (100 vars) | ≈ 80 µs |
| `compress()` pass (10 000 snaps) | ≈ 40 ms |

## Memory Footprint

Each `VariableRecord` ≈ 128–256 bytes (object overhead + strings).

| Hot records | Approx. RAM |
|-------------|-------------|
| 10 000 | ≈ 2.5 MB |
| 50 000 | ≈ 12 MB |
| 200 000 | ≈ 50 MB |

## Tuning Checklist

1. **Set `maxHotRecords` explicitly** — default is 50 000 (≈12 MB).
   Lower it for constrained devices; raise it for desktop tools.

2. **Enable `autoCompressInterval`** (default 60 s) — the compression
   pass removes duplicate snapshots and can halve memory for apps with
   low mutation density.

3. **Use `onEvict` for unlimited history** —
   ```dart
   MemoryRecorder(
     maxRecords: 10000,
     onEvict: (r) => diskPersistence.saveSnapshot(
       sessionId: engine.sessionId,
       snapshot: engine.latestSnapshot(),
     ),
   )
   ```

4. **Skip no-op records** — check `record.isNoOp` before calling
   `engine.record()` if your loop may assign the same value repeatedly.

5. **Use tags for targeted queries** — tagging records lets you build
   filtered reports without scanning the full history.

6. **Disable overlay in release** — `TimeTravelWidget` skips rendering in
   production by default (`showInRelease: false`). For CI/profiling builds
   pass `showInRelease: true`.

7. **Use `pauseRecording()` during known-hot paths** — heavy animations,
   physics loops — then `resumeRecording()` afterward.

8. **`track()` over `record()`** — the inline form avoids a temporary
   variable and is slightly more readable; same cost.

## Profiling with `stats()`

```dart
final s = engine.stats();
print('Avg record latency : ${s.avgRecordingLatencyMicros.toStringAsFixed(1)} µs');
print('Hot cache          : ${(s.hotCacheBytes / 1024).toStringAsFixed(0)} KB');
print('Tracked variables  : ${s.trackedVariables}');
```
