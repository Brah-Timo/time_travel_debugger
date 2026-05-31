/// # Time Travel Debugger
///
/// Ultra-Pro time-travel debugging package for Dart & Flutter.
///
/// ## Quick Start
/// ```dart
/// import 'package:time_travel_debugger/time_travel_debugger.dart';
///
/// void main() {
///   final engine = TimeTravelEngine();
///   engine.startRecording();
///
///   int x = 0;
///   engine.record(name: 'x', oldValue: null, newValue: x,
///                 file: 'main.dart', line: 6);
///
///   x = 42;
///   engine.record(name: 'x', oldValue: 0, newValue: x,
///                 file: 'main.dart', line: 9);
///
///   final snap = engine.rewind(1);
///   print(snap.variable('x')); // 0
///
///   engine.dispose();
/// }
/// ```
library time_travel_debugger;

// ── Core ──────────────────────────────────────────────────────────────────
export 'src/core/time_travel_engine.dart';
export 'src/core/state_snapshot.dart';
export 'src/core/memory_recorder.dart';
export 'src/core/execution_timeline.dart';

// ── Models ────────────────────────────────────────────────────────────────
export 'src/models/variable_record.dart';
export 'src/models/call_stack_frame.dart';
export 'src/models/breakpoint_info.dart';
export 'src/models/timeline_event.dart';
export 'src/models/performance_stats.dart';
export 'src/models/session_metadata.dart';

// ── Storage ───────────────────────────────────────────────────────────────
export 'src/storage/history_storage.dart';
export 'src/storage/memory_cache.dart';
export 'src/storage/disk_persistence.dart';

// ── Debugger Features ─────────────────────────────────────────────────────
export 'src/debugger/breakpoint_manager.dart';
export 'src/debugger/report_generator.dart';
export 'src/debugger/watchpoint_manager.dart';
export 'src/debugger/diff_engine.dart';

// ── Utils ─────────────────────────────────────────────────────────────────
export 'src/utils/serialization.dart';
export 'src/utils/compression.dart';
export 'src/utils/ttd_logger.dart';
export 'src/utils/type_inspector.dart';

// ── Flutter UI (conditional — stub on web / pure-Dart environments) ───────
export 'src/ui/time_travel_widget.dart'
    if (dart.library.html) 'src/ui/time_travel_widget_stub.dart';
export 'src/ui/snapshot_viewer.dart'
    if (dart.library.html) 'src/ui/snapshot_viewer_stub.dart';
export 'src/ui/timeline_ui.dart'
    if (dart.library.html) 'src/ui/timeline_ui_stub.dart';
export 'src/ui/variable_inspector.dart'
    if (dart.library.html) 'src/ui/variable_inspector_stub.dart';
