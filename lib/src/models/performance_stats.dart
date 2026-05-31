import 'package:meta/meta.dart';

/// A snapshot of the engine's runtime performance metrics.
@immutable
class PerformanceStats {
  /// Total number of timeline events recorded so far.
  final int totalEvents;

  /// Total number of snapshots currently held in memory.
  final int snapshotsInMemory;

  /// Total number of snapshots offloaded to the cold cache / disk.
  final int snapshotsOnDisk;

  /// Estimated hot-cache memory usage in bytes.
  final int hotCacheBytes;

  /// Estimated cold-cache / disk usage in bytes.
  final int coldCacheBytes;

  /// Number of distinct variables ever seen.
  final int trackedVariables;

  /// Wall-clock duration since [TimeTravelEngine.startRecording] was called.
  final Duration sessionDuration;

  /// Number of active conditional breakpoints.
  final int activeBreakpoints;

  /// Number of breakpoints that have fired during this session.
  final int breakpointHits;

  /// Average microseconds per [TimeTravelEngine.record] call
  /// (rolling average over the last 1 000 calls).
  final double avgRecordingLatencyMicros;

  const PerformanceStats({
    required this.totalEvents,
    required this.snapshotsInMemory,
    required this.snapshotsOnDisk,
    required this.hotCacheBytes,
    required this.coldCacheBytes,
    required this.trackedVariables,
    required this.sessionDuration,
    required this.activeBreakpoints,
    required this.breakpointHits,
    required this.avgRecordingLatencyMicros,
  });

  /// Total estimated memory / disk footprint in bytes.
  int get totalFootprintBytes => hotCacheBytes + coldCacheBytes;

  /// Human-readable summary.
  @override
  String toString() {
    return 'PerformanceStats(\n'
        '  totalEvents          : $totalEvents\n'
        '  snapshotsInMemory    : $snapshotsInMemory\n'
        '  snapshotsOnDisk      : $snapshotsOnDisk\n'
        '  hotCacheBytes        : $hotCacheBytes\n'
        '  coldCacheBytes       : $coldCacheBytes\n'
        '  trackedVariables     : $trackedVariables\n'
        '  sessionDuration      : $sessionDuration\n'
        '  activeBreakpoints    : $activeBreakpoints\n'
        '  breakpointHits       : $breakpointHits\n'
        '  avgLatency (µs)      : '
        '${avgRecordingLatencyMicros.toStringAsFixed(2)}\n'
        ')';
  }

  Map<String, dynamic> toJson() => {
        'totalEvents': totalEvents,
        'snapshotsInMemory': snapshotsInMemory,
        'snapshotsOnDisk': snapshotsOnDisk,
        'hotCacheBytes': hotCacheBytes,
        'coldCacheBytes': coldCacheBytes,
        'trackedVariables': trackedVariables,
        'sessionDurationMs': sessionDuration.inMilliseconds,
        'activeBreakpoints': activeBreakpoints,
        'breakpointHits': breakpointHits,
        'avgRecordingLatencyMicros': avgRecordingLatencyMicros,
      };
}
