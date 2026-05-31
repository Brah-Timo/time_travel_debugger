import 'package:test/test.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';
import '../fixtures/mock_data.dart';

void main() {
  group('MemoryRecorder', () {
    late MemoryRecorder recorder;

    setUp(() {
      recorder = MemoryRecorder(maxRecords: 10);
    });

    tearDown(() => recorder.dispose());

    test('starts empty', () {
      expect(recorder.recordCount, equals(0));
      expect(recorder.trackedVariableNames, isEmpty);
    });

    test('addRecord increases count', () {
      recorder.addRecord(MockData.intRecord(name: 'x', index: 0));
      expect(recorder.recordCount, equals(1));
    });

    test('tracks variable name in index', () {
      recorder.addRecord(MockData.intRecord(name: 'x', index: 0));
      expect(recorder.trackedVariableNames, contains('x'));
    });

    test('firstChangeOf returns correct step', () {
      recorder.addRecord(MockData.intRecord(name: 'x', index: 0));
      recorder.addRecord(MockData.intRecord(name: 'x', index: 1));
      expect(recorder.firstChangeOf('x'), equals(0));
    });

    test('lastChangeOf returns correct step', () {
      recorder.addRecord(MockData.intRecord(name: 'x', index: 0));
      recorder.addRecord(MockData.intRecord(name: 'x', index: 1));
      expect(recorder.lastChangeOf('x'), equals(1));
    });

    test('allChangesOf returns all steps', () {
      for (var i = 0; i < 5; i++) {
        recorder.addRecord(MockData.intRecord(name: 'x', index: i));
      }
      expect(recorder.allChangesOf('x').length, equals(5));
    });

    test('recordsForVariable filters correctly', () {
      recorder.addRecord(MockData.intRecord(name: 'x', index: 0));
      recorder.addRecord(MockData.intRecord(name: 'y', index: 1));
      recorder.addRecord(MockData.intRecord(name: 'x', index: 2));
      expect(recorder.recordsForVariable('x').length, equals(2));
      expect(recorder.recordsForVariable('y').length, equals(1));
    });

    test('evicts oldest records when maxRecords exceeded', () {
      // maxRecords = 10, add 15 records
      for (var i = 0; i < 15; i++) {
        recorder.addRecord(MockData.intRecord(name: 'x', index: i));
      }
      expect(recorder.recordCount, equals(10));
    });

    test('onEvict callback is called on eviction', () {
      final evicted = <VariableRecord>[];
      final r = MemoryRecorder(
          maxRecords: 3, onEvict: evicted.add);
      for (var i = 0; i < 5; i++) {
        r.addRecord(MockData.intRecord(name: 'x', index: i));
      }
      expect(evicted.length, equals(2));
      r.dispose();
    });

    test('clear resets everything', () {
      recorder.addRecord(MockData.intRecord(name: 'x'));
      recorder.clear();
      expect(recorder.recordCount, equals(0));
      expect(recorder.trackedVariableNames, isEmpty);
    });

    test('estimatedMemoryBytes returns positive value', () {
      recorder.addRecord(MockData.intRecord(name: 'x'));
      expect(recorder.estimatedMemoryBytes(), greaterThan(0));
    });

    test('searchByDescription finds matching records', () {
      recorder.addRecord(VariableRecord(
        variableName: 'x',
        oldValue: 0,
        newValue: 1,
        timestamp: DateTime.now(),
        sourceFile: 'test.dart',
        lineNumber: 1,
        dataType: 'int',
        description: 'button pressed',
      ));
      recorder.addRecord(VariableRecord(
        variableName: 'y',
        oldValue: 0,
        newValue: 1,
        timestamp: DateTime.now(),
        sourceFile: 'test.dart',
        lineNumber: 2,
        dataType: 'int',
        description: 'scroll event',
      ));
      final found = recorder.searchByDescription('button');
      expect(found.length, equals(1));
      expect(found.first.variableName, equals('x'));
    });
  });
}
