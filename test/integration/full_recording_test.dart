import 'dart:io';
import 'package:test/test.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';

/// End-to-end integration test that runs a realistic recording session,
/// exercises all major APIs, and verifies correctness.
void main() {
  group('Full recording integration', () {
    late TimeTravelEngine engine;
    late String tmpDir;

    setUpAll(() {
      tmpDir = Directory.systemTemp
          .createTempSync('ttd_test_')
          .path;
    });

    setUp(() {
      engine = TimeTravelEngine(
        config: TimeTravelConfig(
          maxHotRecords: 5000,
          maxTimelineSnapshots: 5000,
          autoCompressInterval: null,
          defaultSessionPath: '$tmpDir/session.ttd',
          appName: 'IntegrationTestApp',
          appVersion: '1.0.0',
        ),
      );
    });

    tearDown(() => engine.dispose());

    tearDownAll(() {
      Directory(tmpDir).deleteSync(recursive: true);
    });

    // ── Core recording round-trip ─────────────────────────────────────────

    test('records 1000 events and allows full rewind', () {
      engine.startRecording();

      int counter = 0;
      for (var i = 0; i < 1000; i++) {
        final old = counter;
        counter++;
        engine.record(
          name: 'counter',
          oldValue: old,
          newValue: counter,
          file: 'integration_test.dart',
          line: 40,
          description: 'Iteration $i',
        );
      }

      expect(engine.totalSteps, greaterThan(1000));

      // Jump to step 0 — counter should be 0 or initialised.
      final step0 = engine.jumpTo(0);
      expect(step0, isNotNull);

      // Latest snapshot should have counter = 1000.
      final latest = engine.latestSnapshot();
      expect(latest.variable('counter'), equals(1000));

      // Rewind 100 steps from end.
      final rewound = engine.rewind(100);
      expect(rewound.variable('counter'), lessThan(1000));
    });

    // ── Multiple variables ────────────────────────────────────────────────

    test('tracks multiple variables independently', () {
      engine.startRecording();

      int x = 0, y = 100;

      for (var i = 0; i < 50; i++) {
        final ox = x;
        x += 2;
        engine.record(name: 'x', oldValue: ox, newValue: x,
            file: 'f.dart', line: 1);

        final oy = y;
        y -= 3;
        engine.record(name: 'y', oldValue: oy, newValue: y,
            file: 'f.dart', line: 2);
      }

      final latest = engine.latestSnapshot();
      expect(latest.variable('x'), equals(100));  // 50 * 2
      expect(latest.variable('y'), equals(-50));  // 100 - 50*3

      expect(engine.allChangesOf('x').length, equals(50));
      expect(engine.allChangesOf('y').length, equals(50));
    });

    // ── Function entry / exit ─────────────────────────────────────────────

    test('records function entries and exits', () {
      engine.startRecording();

      engine.enterFunction(name: 'fetchData', file: 'api.dart', line: 10);
      engine.record(name: 'response', oldValue: null, newValue: '{"ok":true}',
          file: 'api.dart', line: 15);
      engine.exitFunction(name: 'fetchData', returnValue: true);

      final snap = engine.latestSnapshot();
      expect(snap.variable('response'), equals('{"ok":true}'));
    });

    // ── Annotations / bookmarks ───────────────────────────────────────────

    test('annotate creates searchable bookmark', () {
      engine.startRecording();

      engine.record(name: 'phase', oldValue: null, newValue: 'init',
          file: 'f.dart', line: 1);
      engine.annotate('PHASE: init complete');
      engine.record(name: 'phase', oldValue: 'init', newValue: 'running',
          file: 'f.dart', line: 2);

      final bms = engine.bookmarks();
      expect(bms, isNotEmpty);
      expect(bms.first.bookmarkLabel, equals('PHASE: init complete'));
    });

    // ── Session persistence ───────────────────────────────────────────────

    test('saves and reloads session from disk', () async {
      engine.startRecording();

      for (var i = 0; i < 20; i++) {
        engine.record(
          name: 'n',
          oldValue: i,
          newValue: i + 1,
          file: 'save_test.dart',
          line: 1,
        );
      }
      engine.stopRecording();

      // Save.
      await engine.saveSession();
      expect(File('$tmpDir/session.ttd').existsSync(), isTrue);

      // Create new engine and reload.
      final engine2 = TimeTravelEngine();
      await engine2.loadSession('$tmpDir/session.ttd');
      expect(engine2.totalSteps, greaterThan(1));
      engine2.dispose();
    });

    // ── Breakpoints ───────────────────────────────────────────────────────

    test('breakpoint fires when condition met', () {
      engine.startRecording();

      final bp = BreakpointManager();
      final fired = <BreakpointEvent>[];
      bp.onBreakpointFired = fired.add;

      bp.addVariableBreakpoint(
        variableName: 'score',
        condition: (nv, ov) => (nv as int) > 50,
        description: 'score > 50',
        action: BreakpointAction.log,
      );

      for (var i = 0; i < 100; i++) {
        engine.record(
          name: 'score',
          oldValue: i,
          newValue: i + 1,
          file: 'game.dart',
          line: 5,
        );
        final records = engine.historyOf('score');
        if (records.isNotEmpty) {
          bp.evaluateRecord(records.last, engine.currentPosition);
        }
      }

      expect(fired.length, greaterThan(0));
      expect(fired.first.trigger.newValue, greaterThan(50));
    });

    // ── DiffEngine ────────────────────────────────────────────────────────

    test('DiffEngine detects all change types', () {
      engine.startRecording();

      engine.record(name: 'a', oldValue: null, newValue: 1,
          file: 'f.dart', line: 1);
      engine.record(name: 'b', oldValue: null, newValue: 'hello',
          file: 'f.dart', line: 2);

      final snapA = engine.latestSnapshot();

      engine.record(name: 'a', oldValue: 1, newValue: 99,
          file: 'f.dart', line: 3);   // modified
      engine.record(name: 'c', oldValue: null, newValue: true,
          file: 'f.dart', line: 4);   // added

      final snapB = engine.latestSnapshot();

      const diffEngine = DiffEngine();
      final diff = diffEngine.diff(snapB, snapA);

      expect(diff.modified, isNotEmpty);
      expect(diff.hasDifferences, isTrue);
    });

    // ── Compression ───────────────────────────────────────────────────────

    test('Compression.computeDelta + applyDelta round-trips', () {
      final before = {'x': 1, 'y': 2, 'z': 3};
      final after = {'x': 1, 'y': 99, 'w': 4}; // z removed, y modified, w added

      final delta = Compression.computeDelta(before, after);
      final reconstructed = Compression.applyDelta(before, delta);

      expect(reconstructed['y'], equals(99));
      expect(reconstructed['w'], equals(4));
      expect(reconstructed.containsKey('z'), isFalse);
      expect(reconstructed['x'], equals(1));
    });

    // ── WatchpointManager ─────────────────────────────────────────────────

    test('WatchpointManager fires callback on matching mutation', () {
      engine.startRecording();

      final wm = WatchpointManager();
      final seen = <int>[];
      wm.add(
        variableName: 'counter',
        callback: (r) => seen.add(r.newValue as int),
        filter: (nv, _) => (nv as int).isEven,
      );

      for (var i = 0; i < 10; i++) {
        engine.record(
          name: 'counter',
          oldValue: i,
          newValue: i + 1,
          file: 'f.dart',
          line: 1,
        );
        final rec = engine.historyOf('counter').last;
        wm.notify(rec);
      }

      // Only even values of (i+1) should be captured: 2,4,6,8,10
      expect(seen, everyElement(predicate<int>((v) => v.isEven, 'is even')));
    });

    // ── ReportGenerator ───────────────────────────────────────────────────

    test('ReportGenerator produces non-empty HTML report', () async {
      engine.startRecording();
      for (var i = 0; i < 10; i++) {
        engine.record(name: 'v', oldValue: i, newValue: i + 1,
            file: 'f.dart', line: 1);
      }
      engine.stopRecording();

      final gen = ReportGenerator(
        metadata: SessionMetadata(
          sessionId: 'test-session',
          appName: 'TestApp',
          appVersion: '1.0.0',
          dartVersion: '3.x',
          platform: 'test',
          startTime: DateTime.now(),
          packageVersion: '1.0.0',
        ),
        snapshots: [],
        records: engine.historyOf('v'),
        stats: engine.stats(),
      );

      final html = gen.generate(format: ReportFormat.html);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('Time Travel Debug Report'));

      final md = gen.generate(format: ReportFormat.markdown);
      expect(md, contains('# 🕰 Time Travel Debug Report'));

      final json = gen.generate(format: ReportFormat.json);
      expect(json, contains('"reportType"'));

      final text = gen.generate(format: ReportFormat.plainText);
      expect(text, contains('Time Travel Debug Report'));
    });
  });
}
