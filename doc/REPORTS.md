# Reports Guide — `time_travel_debugger`

## Overview

`ReportGenerator` produces human-readable debug reports from a recorded
session. Four output formats are supported: **HTML**, **JSON**, **Markdown**,
and **plain text**.

---

## Quick start

```dart
final gen = ReportGenerator(
  metadata: SessionMetadata(
    sessionId: engine.sessionId,
    appName: 'MyApp',
    appVersion: '1.0.0',
    dartVersion: '3.x',
    platform: Platform.operatingSystem,
    startTime: DateTime.now(),
    packageVersion: '1.0.0',
  ),
  snapshots: [],          // Pass engine.allSnapshots for full diff sections
  records: engine.historyOf('counter'), // or all records
  stats: engine.stats(),
);

// Generate in memory
final html = gen.generate(format: ReportFormat.html);

// Save to disk
await gen.saveReport('debug_reports/report.html', format: ReportFormat.html);
```

---

## HTML Report

The HTML report uses a dark theme and is fully self-contained (no external
dependencies). It includes:

- **Performance overview** — total events, snapshots, tracked variables,
  average record latency, session duration, hot-cache size.
- **Variable mutation summary table** — variable name, type, mutation count,
  first value, last value.
- **Top 50 recent mutations table** — step number, variable, before/after
  values, source file & line, timestamp.

```dart
final html = gen.generate(format: ReportFormat.html);
// Open in browser or embed in a Flutter WebView
```

---

## JSON Report

Machine-readable format suitable for CI artefacts, custom tooling, or
external dashboards.

```dart
final json = gen.generate(format: ReportFormat.json);
```

Structure:

```json
{
  "reportType": "time_travel_debugger",
  "generatedAt": "2024-01-15T10:35:00.000Z",
  "metadata": { "sessionId": "...", "appName": "MyApp", ... },
  "stats": {
    "totalEvents": 1000,
    "trackedVariables": 5,
    "avgRecordingLatencyMicros": 1.8,
    "sessionDuration": "00:00:30.000000",
    ...
  },
  "variableSummary": {
    "counter": {
      "mutations": 999,
      "typeName": "int",
      "firstValue": 0,
      "lastValue": 1000
    }
  },
  "recentRecords": [
    {
      "variableName": "counter",
      "oldValue": 999,
      "newValue": 1000,
      "timestamp": "...",
      "sourceFile": "main.dart",
      "lineNumber": 42,
      "recordIndex": 999
    }
  ]
}
```

---

## Markdown Report

Generates a GitHub-flavoured Markdown document suitable for issue trackers,
pull request descriptions, or Notion/Confluence pages.

```dart
final md = gen.generate(format: ReportFormat.markdown);
File('REPORT.md').writeAsStringSync(md);
```

---

## Plain Text Report

The most compact format, useful for console output, log files, or email
attachments.

```dart
final text = gen.generate(format: ReportFormat.plainText);
print(text);
```

Sample output:

```
========================================
 Time Travel Debug Report
========================================
Session  : 550e8400-e29b-41d4-a716-446655440000
App      : MyApp 1.0.0
Platform : android
Duration : 30s
Events   : 1000
Variables: 5

--- Variable Mutations ---
  counter                        × 999
  userId                         × 3
  ...

--- Last 20 Records ---
  counter              999             → 1000            @ main.dart:42
  ...
```

---

## `SessionMetadata` fields

| Field | Type | Description |
|-------|------|-------------|
| `sessionId` | `String` | UUID, e.g. `engine.sessionId`. |
| `appName` | `String` | Human name shown in report headers. |
| `appVersion` | `String` | Semantic version. |
| `dartVersion` | `String` | e.g. `Platform.version`. |
| `platform` | `String` | e.g. `Platform.operatingSystem`. |
| `startTime` | `DateTime` | When recording started. |
| `packageVersion` | `String` | `time_travel_debugger` package version. |

---

## `PerformanceStats` fields

Returned by `engine.stats()`:

| Field | Type | Description |
|-------|------|-------------|
| `totalEvents` | `int` | Total `record()` calls. |
| `snapshotsInMemory` | `int` | Live snapshots in `ExecutionTimeline`. |
| `trackedVariables` | `int` | Distinct variable names recorded. |
| `avgRecordingLatencyMicros` | `double` | Mean latency of `record()` in µs. |
| `sessionDuration` | `Duration` | Wall time since `startRecording()`. |
| `hotCacheBytes` | `int` | Estimated bytes in the hot MemoryRecorder. |

---

## Saving multiple formats at once

```dart
for (final format in ReportFormat.values) {
  final ext = format.name; // html, json, plainText, markdown
  await gen.saveReport('reports/report.$ext', format: format);
}
```

---

## CI integration example

```yaml
# .github/workflows/debug_report.yml
- name: Run integration tests with report
  run: |
    flutter test test/integration/
    # The test suite saves a report to /tmp/report.html
- name: Upload debug report
  uses: actions/upload-artifact@v3
  with:
    name: ttd-report
    path: /tmp/report.html
```
