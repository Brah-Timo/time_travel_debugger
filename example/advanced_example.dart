/// Advanced usage example for `time_travel_debugger`.
///
/// Demonstrates:
/// - Conditional breakpoints
/// - Watchpoints
/// - DiffEngine
/// - Compression utilities
/// - Serialization helpers
/// - Session reload
///
/// Run with:
/// ```bash
/// dart run example/advanced_example.dart
/// ```

import 'dart:io';
import 'package:time_travel_debugger/time_travel_debugger.dart';

void main() async {
  final tmp = Directory.systemTemp
      .createTempSync('ttd_advanced_')
      .path;

  // ── Engine setup ──────────────────────────────────────────────────────────
  final engine = TimeTravelEngine(
    config: TimeTravelConfig(
      appName: 'AdvancedExample',
      appVersion: '2.0.0',
      maxHotRecords: 10000,
      maxTimelineSnapshots: 10000,
      autoCompressInterval: null,
      defaultSessionPath: '$tmp/session.ttd',
    ),
  );
  engine.startRecording();

  // ── Breakpoints ───────────────────────────────────────────────────────────
  final bpManager = BreakpointManager();
  final firedBreakpoints = <BreakpointEvent>[];
  bpManager.onBreakpointFired = firedBreakpoints.add;

  bpManager.addVariableBreakpoint(
    variableName: 'health',
    condition: (nv, ov) => (nv as int) < 25,
    description: 'Health critical (< 25)',
    action: BreakpointAction.log,
    maxHitCount: 3,
  );

  bpManager.addVariableBreakpoint(
    variableName: 'score',
    condition: (nv, ov) => (nv as int) >= 1000,
    description: 'Score milestone: 1000',
    action: BreakpointAction.log,
    maxHitCount: 1,
  );

  // ── Watchpoints ───────────────────────────────────────────────────────────
  final wpManager = WatchpointManager();
  wpManager.add(
    variableName: 'health',
    callback: (r) {
      // Only log when health drops
      if ((r.newValue as int) < (r.oldValue as int? ?? 100)) {
        log.info('⚠️  Health dropped: ${r.oldValue} → ${r.newValue}');
      }
    },
    filter: (nv, ov) =>
        ov != null && (nv as int) < (ov as int),
  );

  // ── Simulate game loop ────────────────────────────────────────────────────
  int health = 100;
  int score = 0;
  int level = 1;

  print('🎮 Simulating game session...');

  for (int round = 0; round < 200; round++) {
    // Health decreases
    final oldHealth = health;
    health = (health - (round % 7 == 0 ? 10 : 1)).clamp(0, 100);
    engine.record(name: 'health', oldValue: oldHealth, newValue: health,
        file: 'game.dart', line: 40,
        tags: ['game', 'health']);
    final hRec = engine.historyOf('health').last;
    bpManager.evaluateRecord(hRec, engine.currentPosition);
    wpManager.notify(hRec);

    // Score increases
    final oldScore = score;
    score += round * 5 + level;
    engine.record(name: 'score', oldValue: oldScore, newValue: score,
        file: 'game.dart', line: 50,
        tags: ['game', 'score']);
    final sRec = engine.historyOf('score').last;
    bpManager.evaluateRecord(sRec, engine.currentPosition);

    // Level up every 50 rounds
    if (round > 0 && round % 50 == 0) {
      final oldLevel = level;
      level++;
      engine.record(name: 'level', oldValue: oldLevel, newValue: level,
          file: 'game.dart', line: 60, tags: ['game', 'level']);
      engine.annotate('Level up → $level');
    }

    if (health == 0) break;
  }

  engine.stopRecording();
  print('🏁 Game session ended.');

  // ── Query results ─────────────────────────────────────────────────────────
  print('\n=== Final state ===');
  final latest = engine.latestSnapshot();
  print('health = ${latest.variable('health')}');
  print('score  = ${latest.variable('score')}');
  print('level  = ${latest.variable('level')}');

  print('\n=== Breakpoint report ===');
  print('Total fired: ${firedBreakpoints.length}');
  for (final ev in firedBreakpoints.take(5)) {
    print('  ${ev.breakpoint.description} @ step ${ev.step}'
        ' — ${ev.trigger.variableName}=${ev.trigger.newValue}');
  }

  // ── DiffEngine ────────────────────────────────────────────────────────────
  print('\n=== DiffEngine ===');
  const diffEngine = DiffEngine();
  final step0 = engine.jumpTo(0);
  final diff = diffEngine.diff(latest, step0);
  print(diff.toText());

  // ── Compression delta demo ────────────────────────────────────────────────
  print('\n=== Compression demo ===');
  final mapA = {'x': 1, 'y': 2, 'z': 3};
  final mapB = {'x': 1, 'y': 99, 'w': 4};
  final delta = Compression.computeDelta(mapA, mapB);
  final restored = Compression.applyDelta(mapA, delta);
  print('Original: $mapA');
  print('Target  : $mapB');
  print('Delta   : $delta');
  print('Restored: $restored');
  print('Match   : ${restored.toString() == mapB.toString()}');

  // ── Serialization helpers ─────────────────────────────────────────────────
  print('\n=== Serialization ===');
  final snap = engine.jumpTo(engine.totalSteps ~/ 2);
  final json = Serialization.snapshotToJson(snap, pretty: false);
  final restored2 = Serialization.snapshotFromJson(json);
  print('Snapshot round-trip OK: '
      '${restored2.stepNumber == snap.stepNumber}');

  // ── Session persistence ───────────────────────────────────────────────────
  await engine.saveSession();
  print('\n✅ Session saved to $tmp/session.ttd');
  print('   File size: '
      '${File('$tmp/session.ttd').statSync().size} bytes');

  // Reload into a fresh engine.
  final engine2 = TimeTravelEngine();
  await engine2.loadSession('$tmp/session.ttd');
  print('   Reloaded steps: ${engine2.totalSteps}');
  engine2.dispose();

  // ── Full HTML report ──────────────────────────────────────────────────────
  final gen = ReportGenerator(
    metadata: SessionMetadata(
      sessionId: engine.sessionId,
      appName: 'AdvancedExample',
      appVersion: '2.0.0',
      dartVersion: '3.x',
      platform: 'dart',
      startTime: DateTime.now().subtract(const Duration(seconds: 10)),
      packageVersion: '1.0.0',
    ),
    snapshots: [],
    records: [
      ...engine.historyOf('health'),
      ...engine.historyOf('score'),
      ...engine.historyOf('level'),
    ],
    stats: engine.stats(),
  );
  await gen.saveReport('$tmp/advanced_report.html',
      format: ReportFormat.html);
  print('📄 HTML report: $tmp/advanced_report.html');

  // ── Bookmarks ─────────────────────────────────────────────────────────────
  engine.startRecording(); // must be recording to read bookmarks via annotate
  final bms = engine.bookmarks();
  engine.stopRecording();
  print('\n🔖 Bookmarks (${bms.length}):');
  for (final bm in bms) {
    print('   ${bm.bookmarkLabel} @ step ${bm.stepNumber}');
  }

  // ── TypeInspector ─────────────────────────────────────────────────────────
  print('\n=== TypeInspector ===');
  for (final v in [42, 3.14, 'hello', true, null, [1, 2], {'a': 1}]) {
    print('  ${TypeInspector.typeName(v).padRight(20)} '
        '${TypeInspector.displayValue(v)}');
  }

  engine.dispose();

  // Cleanup
  Directory(tmp).deleteSync(recursive: true);
  print('\n🗑  Temp files cleaned up. Done!');
}
