/// Basic usage example for `time_travel_debugger`.
///
/// Run with:
/// ```bash
/// dart run example/basic_example.dart
/// ```

import 'package:time_travel_debugger/time_travel_debugger.dart';

void main() async {
  // ── 1. Create engine ─────────────────────────────────────────────────────
  final engine = TimeTravelEngine(
    config: const TimeTravelConfig(
      appName: 'BasicExample',
      appVersion: '1.0.0',
      autoCompressInterval: null, // disable auto-compress for this demo
    ),
  );

  // ── 2. Start recording ────────────────────────────────────────────────────
  engine.startRecording();
  print('▶  Recording started. Session: ${engine.sessionId}');

  // ── 3. Simulate application logic ─────────────────────────────────────────
  int x = 0;
  engine.record(
    name: 'x',
    oldValue: null,
    newValue: x,
    file: 'basic_example.dart',
    line: 28,
    description: 'x initialised',
  );

  // Use the inline track() shorthand
  for (int i = 0; i < 100; i++) {
    x = engine.track('x', x, x + i, 'basic_example.dart', 35,
        description: 'loop iteration $i');
  }

  // Record a function call
  engine.enterFunction(
      name: 'processResult', file: 'basic_example.dart', line: 42);
  final result = _processResult(x);
  engine.record(
    name: 'result',
    oldValue: null,
    newValue: result,
    file: 'basic_example.dart',
    line: 46,
  );
  engine.exitFunction(name: 'processResult', returnValue: result);

  // Add a bookmark at a key moment
  engine.annotate('Processing complete');

  // ── 4. Inspect the timeline ────────────────────────────────────────────────
  print('\n=== Current state ===');
  print('x      = $x');
  print('result = $result');
  print('Steps  = ${engine.totalSteps}');

  // Rewind 10 steps
  final snap10 = engine.rewind(10);
  print('\n=== After rewind(10) ===');
  print('x     = ${snap10.variable('x')}');
  print('step  = ${snap10.stepNumber}');
  print('desc  = ${snap10.description}');

  // Jump to the very beginning
  final snap0 = engine.jumpTo(0);
  print('\n=== At step 0 ===');
  print('x     = ${snap0.variable('x')}');
  print('vars  = ${snap0.variableNames}');

  // Find changes
  print('\n=== Change queries ===');
  final first = engine.firstChangeOf('x');
  final last = engine.lastChangeOf('x');
  final all = engine.allChangesOf('x');
  print('First x change : step $first');
  print('Last  x change : step $last');
  print('Total x changes: ${all.length}');

  // Bookmarks
  final bookmarks = engine.bookmarks();
  print('\n=== Bookmarks ===');
  for (final bm in bookmarks) {
    print('  ${bm.bookmarkLabel} @ step ${bm.stepNumber}');
  }

  // ── 5. Performance stats ───────────────────────────────────────────────────
  print('\n=== Performance ===');
  print(engine.stats());

  // ── 6. Save session ───────────────────────────────────────────────────────
  await engine.saveSession('/tmp/basic_example_session.ttd');
  print('\n✅ Session saved to /tmp/basic_example_session.ttd');

  // ── 7. Generate a report ──────────────────────────────────────────────────
  engine.stopRecording();
  final gen = ReportGenerator(
    metadata: SessionMetadata(
      sessionId: engine.sessionId,
      appName: 'BasicExample',
      appVersion: '1.0.0',
      dartVersion: '3.x',
      platform: 'dart',
      startTime: DateTime.now().subtract(const Duration(seconds: 5)),
      packageVersion: '1.0.0',
    ),
    snapshots: [],
    records: engine.historyOf('x'),
    stats: engine.stats(),
  );

  await gen.saveReport('/tmp/basic_example_report.html',
      format: ReportFormat.html);
  print('📄 HTML report saved to /tmp/basic_example_report.html');

  await gen.saveReport('/tmp/basic_example_report.md',
      format: ReportFormat.markdown);
  print('📄 Markdown report saved to /tmp/basic_example_report.md');

  // ── 8. Cleanup ─────────────────────────────────────────────────────────────
  engine.dispose();
  print('\n🏁 Done.');
}

int _processResult(int value) => value * 2 + 42;
