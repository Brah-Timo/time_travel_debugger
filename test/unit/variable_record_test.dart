import 'package:test/test.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';
import '../fixtures/mock_data.dart';

void main() {
  group('VariableRecord', () {
    test('creates correctly from constructor', () {
      final r = MockData.intRecord(name: 'x', oldValue: 0, newValue: 42);
      expect(r.variableName, equals('x'));
      expect(r.oldValue, equals(0));
      expect(r.newValue, equals(42));
      expect(r.dataType, equals('int'));
    });

    test('changeDescription formats correctly', () {
      final r = MockData.intRecord(name: 'count', oldValue: 10, newValue: 20);
      expect(r.changeDescription, equals('count: 10 → 20'));
    });

    test('numericDelta returns correct positive delta', () {
      final r = MockData.intRecord(oldValue: 10, newValue: 30);
      expect(r.numericDelta, equals('+20'));
    });

    test('numericDelta returns correct negative delta', () {
      final r = MockData.intRecord(oldValue: 50, newValue: 30);
      expect(r.numericDelta, equals('-20'));
    });

    test('numericDelta returns null for non-numeric', () {
      final r = MockData.stringRecord();
      expect(r.numericDelta, isNull);
    });

    test('isNoOp returns true when values are equal', () {
      final r = MockData.intRecord(oldValue: 5, newValue: 5);
      expect(r.isNoOp, isTrue);
    });

    test('isNoOp returns false when values differ', () {
      final r = MockData.intRecord(oldValue: 5, newValue: 6);
      expect(r.isNoOp, isFalse);
    });

    test('round-trips through JSON', () {
      final original = MockData.intRecord(
        name: 'score',
        oldValue: 100,
        newValue: 200,
        index: 7,
      );
      final json = original.toJson();
      final restored = VariableRecord.fromJson(json);

      expect(restored.variableName, equals(original.variableName));
      expect(restored.oldValue, equals(original.oldValue));
      expect(restored.newValue, equals(original.newValue));
      expect(restored.recordIndex, equals(original.recordIndex));
    });

    test('withIndex returns a copy with updated index', () {
      final r = MockData.intRecord(index: 0);
      final updated = r.withIndex(99);
      expect(updated.recordIndex, equals(99));
      expect(updated.variableName, equals(r.variableName));
    });

    test('equality is based on name, index, timestamp', () {
      final a = MockData.intRecord(name: 'x', index: 1);
      final b = MockData.intRecord(name: 'x', index: 1);
      // Same timestamp (same millisecond) → equal
      expect(a, equals(b));
    });
  });
}
