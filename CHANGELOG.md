# Changelog

All notable changes to `time_travel_debugger` are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-05-31

### Added
- **TimeTravelEngine** — core recording, rewind, fast-forward, jump-to.
- **StateSnapshot** — immutable state capture with diff support.
- **MemoryRecorder** — O(1) first/last lookup via inverted index; rolling
  latency tracking; configurable eviction with `onEvict` hook.
- **ExecutionTimeline** — ordered event + snapshot log with gzip-backed
  `.ttd` persistence and delta-compression pass.
- **VariableRecord** — full mutation event (value, location, tags, delta).
- **CallStackFrame** — call-stack frame with `tryParseLine` parser.
- **BreakpointInfo** — immutable breakpoint descriptor with hit-count tracking.
- **TimelineEvent** — typed wrapper for mutation / function-entry / annotation
  events.
- **PerformanceStats** — runtime metrics snapshot.
- **SessionMetadata** — session header stored in `.ttd` files.
- **HistoryStorage** — FIFO / LFU / LRU eviction strategies.
- **MemoryCache** — two-tier hot + cold LRU cache with promotion on access.
- **DiskPersistence** — save/load `.ttd` session files; bulk and streaming
  modes; single-snapshot `.snap` files.
- **BreakpointManager** — add/remove/enable/disable conditional breakpoints;
  `log`, `pause`, `throwException`, `rewindAndReport` actions.
- **WatchpointManager** — pure-observer watchpoints with predicate filters.
- **DiffEngine** — full snapshot diff (added/removed/modified/unchanged);
  record-level diff; timeline-range diff.
- **ReportGenerator** — HTML (dark-mode), JSON, Markdown, and plain-text
  report formats with `saveReport()`.
- **Serialization** — pure JSON helpers for all types; session-file builder.
- **Compression** — delta encoding/decoding; gzip wrappers; RLE helpers.
- **TtdLogger** — internal structured logger with custom sinks.
- **TypeInspector** — runtime type names and display strings.
- **TimeTravelWidget** (Flutter) — draggable overlay panel.
- **SnapshotViewer** (Flutter) — Variables / Call Stack / Changes tab view.
- **TimelineUI** (Flutter) — slider scrubber, nav buttons, bookmark strip.
- **VariableInspector** (Flutter) — full variable history page.
- Unit tests for all core classes.
- Integration test covering recording, breakpoints, diff, compression,
  serialization, persistence, and report generation.
- `basic_example.dart` and `advanced_example.dart`.
- Flutter counter-app example (`example/flutter_app_example/`).

---

## [Unreleased]

### Planned
- Web / WebAssembly support (conditional I/O stubs).
- Multi-isolate session merging.
- VS Code extension with protocol adapter.
- Binary `.ttdb` format for 10× smaller sessions.
- Heatmap view in Flutter overlay (most-mutated variables).
- `TimeTravelNotifier` for BLoC / Riverpod integration.
