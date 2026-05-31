# API Reference — `time_travel_debugger`

> Auto-generated summary. For full dartdoc comments run:
> ```bash
> dart doc .
> ```

---

## TimeTravelEngine

**Constructor**
```dart
TimeTravelEngine({TimeTravelConfig? config})
```

**Recording**

| Signature | Returns | Description |
|-----------|---------|-------------|
| `startRecording()` | `void` | Begin capturing. |
| `stopRecording()` | `void` | Stop. History preserved. |
| `pauseRecording()` | `void` | Temporarily suspend. |
| `resumeRecording()` | `void` | Continue after pause. |
| `record({name, oldValue, newValue, file, line, description?, tags?, exceptionMessage?, captureCallStack?})` | `void` | Record a mutation. |
| `track<T>(name, oldValue, newValue, file, line, {description?, tags?})` | `T` | Record + return newValue. |
| `enterFunction({name, params?, file?, line?})` | `void` | Record function entry. |
| `exitFunction({name, returnValue?})` | `void` | Record function exit. |
| `annotate(label)` | `void` | Insert a named bookmark. |

**Time-travel**

| Signature | Returns | Description |
|-----------|---------|-------------|
| `rewind(int steps)` | `StateSnapshot` | Go back n steps. |
| `fastForward(int steps)` | `StateSnapshot` | Go forward n steps. |
| `jumpTo(int step)` | `StateSnapshot` | Absolute position. |
| `currentSnapshot()` | `StateSnapshot` | Snapshot at cursor. |
| `latestSnapshot()` | `StateSnapshot` | End of timeline. |
| `variablesAt(int step)` | `Map<String, dynamic>` | Variables without moving cursor. |

**Search**

| Signature | Returns | Description |
|-----------|---------|-------------|
| `firstChangeOf(String name)` | `int?` | First mutation step. |
| `lastChangeOf(String name)` | `int?` | Last mutation step. |
| `allChangesOf(String name)` | `List<int>` | All mutation steps. |
| `historyOf(String name)` | `List<VariableRecord>` | Records in hot memory. |
| `bookmarks()` | `List<StateSnapshot>` | Annotated snapshots. |
| `searchRecords(String query)` | `List<VariableRecord>` | Full-text in descriptions. |

**Introspection**

| Getter | Type | Description |
|--------|------|-------------|
| `isRecording` | `bool` | — |
| `isPaused` | `bool` | — |
| `totalSteps` | `int` | Timeline length. |
| `currentPosition` | `int` | Cursor position. |
| `sessionId` | `String` | UUID of current session. |

**Maintenance**

| Signature | Returns | Description |
|-----------|---------|-------------|
| `stats()` | `PerformanceStats` | Runtime metrics. |
| `clearHistory()` | `void` | Reset without stopping. |
| `saveSession([String? path])` | `Future<void>` | Persist to disk. |
| `loadSession(String path)` | `Future<void>` | Reload from disk. |
| `dispose()` | `void` | Release resources. |

---

## StateSnapshot

```dart
StateSnapshot({
  required String snapshotId,
  required int stepNumber,
  required DateTime timestamp,
  required Map<String, dynamic> variables,
  required List<CallStackFrame> callStack,
  String? description,
  List<VariableRecord> changes,
  String? bookmarkLabel,
})
```

| Member | Type | Description |
|--------|------|-------------|
| `variable(name)` | `dynamic` | Value at this step. |
| `hasVariable(name)` | `bool` | Existence check. |
| `variableNames` | `List<String>` | Sorted names. |
| `filterVariables(pattern)` | `Map<String, dynamic>` | Filtered subset. |
| `diff(other)` | `Map<String, Map<String, dynamic>>` | Changed variables. |
| `currentFunction` | `String?` | Innermost call-stack frame. |
| `callStackString` | `String` | Pretty-printed stack. |
| `withBookmark(label)` | `StateSnapshot` | Copy with bookmark. |

---

## VariableRecord

| Member | Type | Description |
|--------|------|-------------|
| `variableName` | `String` | — |
| `oldValue` | `dynamic` | Before mutation. |
| `newValue` | `dynamic` | After mutation. |
| `timestamp` | `DateTime` | Wall-clock time. |
| `sourceFile` | `String` | File path. |
| `lineNumber` | `int` | — |
| `description` | `String?` | Human note. |
| `dataType` | `String` | Runtime type name. |
| `recordIndex` | `int` | Absolute index. |
| `tags` | `List<String>` | User-defined tags. |
| `changeDescription` | `String` | `"x: 0 → 42"` |
| `numericDelta` | `String?` | `"+42"` or `null`. |
| `isNoOp` | `bool` | `old == new`. |

---

## BreakpointManager

| Method | Description |
|--------|-------------|
| `addVariableBreakpoint({id?, variableName, condition?, description?, action, maxHitCount?, sourceFileFilter?})` | Add variable breakpoint. |
| `addFunctionBreakpoint({id?, functionName, condition?, description?, action})` | Add function breakpoint. |
| `remove(id)` | Remove by ID. |
| `disable(id)` / `enable(id)` | Toggle. |
| `evaluateRecord(record, step)` | Check all breakpoints → `List<BreakpointEvent>`. |
| `all` | All breakpoints. |
| `active` | Active only. |
| `eventHistory` | Past fire events. |

---

## DiffEngine

| Method | Description |
|--------|-------------|
| `diff(after, before)` | `SnapshotDiff` with added/removed/modified/unchanged entries. |
| `diffRecords(a, b)` | Map with from/to/delta for same-variable records. |
| `diffTimeline(snapshots)` | List of step-by-step diffs. |

---

## ReportGenerator

```dart
ReportGenerator({
  required SessionMetadata metadata,
  required List<StateSnapshot> snapshots,
  required List<VariableRecord> records,
  required PerformanceStats stats,
})
```

| Method | Description |
|--------|-------------|
| `generate({format})` | Returns report `String`. |
| `saveReport(path, {format})` | Writes to file. |

**Formats:** `html`, `json`, `markdown`, `plainText`

---

## Compression

| Static method | Description |
|---------------|-------------|
| `gzipEncode(text)` | `Uint8List` |
| `gzipDecode(bytes)` | `String` |
| `computeDelta(before, after)` | Changed-only map. |
| `applyDelta(base, delta)` | Reconstructed map. |
| `rleEncode(list)` / `rleDecode(encoded)` | RLE for int lists. |
| `deltaRatio(before, after)` | `0.0`–`1.0` similarity score. |
