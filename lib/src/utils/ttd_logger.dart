import 'dart:io';

/// Log level for [TtdLogger].
enum TtdLogLevel { verbose, debug, info, warning, error, silent }

/// Internal logger for the `time_travel_debugger` package.
///
/// Logs are prefixed with `[TTD]` and can be piped to a custom sink.
///
/// ```dart
/// TtdLogger.instance.level = TtdLogLevel.debug;
/// TtdLogger.instance.addSink((msg) => myLogService.log(msg));
/// ```
class TtdLogger {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final TtdLogger instance = TtdLogger._();
  TtdLogger._();

  // ── Config ────────────────────────────────────────────────────────────────
  TtdLogLevel level = TtdLogLevel.info;

  /// When `true`, [verbose] and [debug] messages include microsecond timestamps.
  bool includeTimestamps = false;

  // ── Custom sinks ──────────────────────────────────────────────────────────
  final List<void Function(String message)> _sinks = [];

  void addSink(void Function(String message) sink) => _sinks.add(sink);
  void removeSink(void Function(String message) sink) =>
      _sinks.remove(sink);

  // ── Logging API ───────────────────────────────────────────────────────────

  void verbose(String msg) => _emit(TtdLogLevel.verbose, 'VERBOSE', msg);
  void debug(String msg) => _emit(TtdLogLevel.debug, 'DEBUG', msg);
  void info(String msg) => _emit(TtdLogLevel.info, 'INFO', msg);
  void warning(String msg) => _emit(TtdLogLevel.warning, 'WARN', msg);
  void error(String msg, [Object? error, StackTrace? stack]) {
    _emit(TtdLogLevel.error, 'ERROR', msg);
    if (error != null) _emit(TtdLogLevel.error, 'ERROR', '  ↳ $error');
    if (stack != null) {
      for (final line in stack.toString().split('\n').take(8)) {
        _emit(TtdLogLevel.error, 'ERROR', '    $line');
      }
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _emit(TtdLogLevel msgLevel, String label, String message) {
    if (msgLevel.index < level.index) return;

    final ts = includeTimestamps
        ? '[${DateTime.now().toIso8601String()}] '
        : '';
    final formatted = '[TTD] $ts[$label] $message';

    // Write to stderr to avoid polluting stdout.
    try {
      stderr.writeln(formatted);
    } catch (_) {
      // May fail in certain environments (web); ignore.
    }

    for (final sink in _sinks) {
      try {
        sink(formatted);
      } catch (_) {
        // Never let a sink crash the recording path.
      }
    }
  }
}

/// Shorthand global accessor.
TtdLogger get log => TtdLogger.instance;
