import 'package:test/test.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';
import '../fixtures/mock_data.dart';

void main() {
  group('TimeTravelEngine', () {
    late TimeTravelEngine engine;

    setUp(() {
      engine = TimeTravelEngine(
        config: const TimeTravelConfig(
          maxHotRecords: 1000,
          maxTimelineSnapshots: 1000,
          autoCompressInterval: null,
        ),
      );
    });

    tearDown(() => engine.dispose());

    // ── Lifecycle ────────────────────────────────────────────────────────────

    test('starts in non-recording state', () {
      expect(engine.isRecording, isFalse);
    });

    test('startRecording sets isRecording to true', () {
      engine.startRecording();
      expect(engine.isRecording, isTrue);
    });

    test('stopRecording sets isRecording to false', () {
      engine.startRecording();
      engine.stopRecording();
      expect(engine.isRecording, isFalse);
    });

    test('startRecording throws if already recording', () {
      engine.startRecording();
      expect(() => engine.startRecording(), throwsA(isA<TimeTravelException>()));
    });

    test('dispose prevents further recording', () {
      engine.startRecording();
      engine.dispose();
      // After dispose, engine should be unusable
      expect(() => engine.record(
            name: 'x', oldValue: 0, newValue: 1,
            file: 'test.dart', line: 1),
          returnsNormally); // silently ignored
    });

    // ── Recording ────────────────────────────────────────────────────────────

    test('record increments totalSteps', () {
      engine.startRecording();
      final before = engine.totalSteps;
      engine.record(
          name: 'x', oldValue: 0, newValue: 1,
          file: 'test.dart', line: 1);
      expect(engine.totalSteps, greaterThan(before));
    });

    test('record does nothing when not recording', () {
      final before = engine.totalSteps;
      engine.record(
          name: 'x', oldValue: 0, newValue: 1,
          file: 'test.dart', line: 1);
      expect(engine.totalSteps, equals(before));
    });

    test('pauseRecording stops events from being recorded', () {
      engine.startRecording();
      engine.pauseRecording();
      final before = engine.totalSteps;
      engine.record(
          name: 'x', oldValue: 0, newValue: 1,
          file: 'test.dart', line: 1);
      expect(engine.totalSteps, equals(before));
    });

    test('resumeRecording allows recording again', () {
      engine.startRecording();
      engine.pauseRecording();
      engine.resumeRecording();
      final before = engine.totalSteps;
      engine.record(
          name: 'x', oldValue: 0, newValue: 1,
          file: 'test.dart', line: 1);
      expect(engine.totalSteps, greaterThan(before));
    });

    // ── track() helper ────────────────────────────────────────────────────────

    test('track() returns newValue', () {
      engine.startRecording();
      final result = engine.track('x', 0, 42, 'test.dart', 1);
      expect(result, equals(42));
    });

    // ── Time-travel ────────────────────────────────────────────────────────────

    test('rewind returns snapshot at correct position', () {
      final e = MockData.warmEngine(eventCount: 50);
      final snap = e.rewind(10);
      expect(snap.stepNumber, lessThan(e.currentPosition + 11));
      e.dispose();
    });

    test('rewind with steps=0 throws ArgumentError', () {
      engine.startRecording();
      expect(() => engine.rewind(0), throwsArgumentError);
    });

    test('fastForward moves cursor forward', () {
      final e = MockData.warmEngine(eventCount: 50);
      e.rewind(20); // go back
      final before = e.currentPosition;
      e.fastForward(5);
      expect(e.currentPosition, greaterThan(before));
      e.dispose();
    });

    test('jumpTo returns correct snapshot', () {
      final e = MockData.warmEngine(eventCount: 30);
      final snap = e.jumpTo(0);
      expect(snap.stepNumber, equals(0));
      e.dispose();
    });

    test('currentSnapshot returns snapshot at cursor', () {
      final e = MockData.warmEngine(eventCount: 10);
      final snap = e.currentSnapshot();
      expect(snap, isNotNull);
      e.dispose();
    });

    // ── Search ────────────────────────────────────────────────────────────────

    test('firstChangeOf returns non-null after recording', () {
      final e = MockData.warmEngine(eventCount: 10);
      expect(e.firstChangeOf('counter'), isNotNull);
      e.dispose();
    });

    test('lastChangeOf returns non-null after recording', () {
      final e = MockData.warmEngine(eventCount: 10);
      expect(e.lastChangeOf('counter'), isNotNull);
      e.dispose();
    });

    test('allChangesOf returns all mutation steps', () {
      final e = MockData.warmEngine(eventCount: 20);
      final changes = e.allChangesOf('counter');
      expect(changes.length, equals(20));
      e.dispose();
    });

    test('historyOf returns records for variable', () {
      final e = MockData.warmEngine(eventCount: 5);
      expect(e.historyOf('counter').length, equals(5));
      e.dispose();
    });

    // ── Stats ──────────────────────────────────────────────────────────────

    test('stats() returns non-null PerformanceStats', () {
      engine.startRecording();
      final s = engine.stats();
      expect(s, isA<PerformanceStats>());
    });

    test('stats().trackedVariables increases with new variables', () {
      engine.startRecording();
      engine.record(name: 'a', oldValue: null, newValue: 1,
          file: 'f.dart', line: 1);
      engine.record(name: 'b', oldValue: null, newValue: 2,
          file: 'f.dart', line: 2);
      expect(engine.stats().trackedVariables, equals(2));
    });

    // ── Maintenance ────────────────────────────────────────────────────────

    test('clearHistory resets to minimal state', () {
      final e = MockData.warmEngine(eventCount: 50);
      e.clearHistory();
      expect(e.totalSteps, equals(1)); // only initial snapshot
      e.dispose();
    });

    // ── Annotation ────────────────────────────────────────────────────────

    test('annotate creates a bookmark', () {
      engine.startRecording();
      engine.annotate('my-bookmark');
      expect(engine.bookmarks(), isNotEmpty);
    });
  });
}
