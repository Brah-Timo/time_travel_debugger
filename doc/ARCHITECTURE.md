# Architecture — `time_travel_debugger`

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Your Application                         │
│                                                                 │
│  engine.record(...)   engine.track(...)   engine.annotate(...) │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                ┌───────────▼───────────┐
                │   TimeTravelEngine    │  ← Public API surface
                └──┬──────────┬─────────┘
                   │          │
     ┌─────────────▼──┐  ┌────▼──────────────┐
     │  MemoryRecorder│  │ ExecutionTimeline  │
     │  (flat list +  │  │ (events + snapshots│
     │   inv. index)  │  │  + cursor)         │
     └─────────────┬──┘  └────┬──────────────┘
                   │          │
          ┌────────▼──────────▼────────┐
          │       HistoryStorage       │  warm cache (FIFO/LFU/LRU)
          └────────────┬───────────────┘
                       │
          ┌────────────▼───────────────┐
          │       MemoryCache          │  two-tier LRU (hot + cold)
          └────────────┬───────────────┘
                       │
          ┌────────────▼───────────────┐
          │      DiskPersistence       │  .ttd JSON files
          └────────────────────────────┘
```

## Data Flow

1. **Developer** calls `engine.record(name, old, new, file, line)`.
2. `TimeTravelEngine` wraps the call into a `VariableRecord`.
3. `MemoryRecorder.addRecord()` appends to the hot list and updates the
   inverted index (`variableName → [absoluteIndices]`).
4. `ExecutionTimeline.addMutationEvent()` updates the live variable map
   and materialises a new `StateSnapshot`.
5. When the cursor is moved (`rewind` / `jumpTo`), `ExecutionTimeline`
   returns the pre-computed snapshot at that index — no replay needed.

## Key Design Decisions

### Why materialise a snapshot per event?

Instant O(1) random access without replay. The memory cost is offset by
the auto-compression pass that deduplicates consecutive identical snapshots.

### Inverted index in MemoryRecorder

Enables O(1) `firstChangeOf` / `lastChangeOf` and O(k) `allChangesOf`
where k = number of mutations for that variable.

### Immutable snapshots (StateSnapshot)

Snapshot objects are `@immutable`; all "copy with change" operations return
new instances. This prevents subtle bugs when a snapshot is stored in a
cache and mutated externally.

### Conditional exports for Flutter UI

All `src/ui/` files are conditionally exported — non-Flutter Dart projects
get stub classes instead of compile errors from missing `flutter/material.dart`.

### Two-tier MemoryCache

The hot tier (LinkedHashMap for O(1) LRU) holds up to `hotCapacity` snapshots.
Evicted snapshots move to the cold tier (a set of keys). On cold-hit, the
`decompress` callback (typically DiskPersistence.loadSnapshot) is invoked
and the snapshot is promoted back to hot.

## Threading Model

All engine methods are **synchronous** and **single-threaded**. If you use
multiple isolates, create one engine per isolate and merge session files
after the fact using `DiskPersistence`.

## File Format (.ttd)

```json
{
  "ttdVersion": "1.0",
  "metadata": { "sessionId": "...", "appName": "...", ... },
  "snapshots": [ { "snapshotId": "...", "stepNumber": 0, ... }, ... ],
  "events":    [ { "index": 0, "kind": "variableMutation", ... }, ... ]
}
```

Streaming mode writes line-delimited JSON to avoid peak memory spikes for
sessions with > 100 000 events.
