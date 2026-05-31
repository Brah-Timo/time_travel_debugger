import 'package:test/test.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';
import '../fixtures/mock_data.dart';

void main() {
  group('StateSnapshot', () {
    late StateSnapshot snap;

    setUp(() {
      snap = MockData.snapshot(
        step: 5,
        variables: {'x': 42, 'label': 'hello', 'active': true},
        description: 'test snapshot',
      );
    });

    test('variable() returns correct value', () {
      expect(snap.variable('x'), equals(42));
      expect(snap.variable('label'), equals('hello'));
    });

    test('variable() returns null for unknown key', () {
      expect(snap.variable('missing'), isNull);
    });

    test('hasVariable() works correctly', () {
      expect(snap.hasVariable('x'), isTrue);
      expect(snap.hasVariable('unknown'), isFalse);
    });

    test('variableNames returns sorted list', () {
      final names = snap.variableNames;
      expect(names, equals(['active', 'label', 'x']));
    });

    test('filterVariables works with string pattern', () {
      // Only 'label' contains 'la'
      final filtered = snap.filterVariables('la');
      expect(filtered.keys, contains('label'));
      expect(filtered.keys, isNot(contains('x')));
    });

    test('currentFunction returns null when stack is empty', () {
      expect(snap.currentFunction, isNull);
    });

    test('diff detects modifications', () {
      final snap2 = MockData.snapshot(
        step: 6,
        variables: {'x': 99, 'label': 'hello', 'active': true},
      );
      final diffs = snap2.diff(snap);
      expect(diffs.containsKey('x'), isTrue);
      expect(diffs['x']?['before'], equals(42));
      expect(diffs['x']?['after'], equals(99));
    });

    test('diff detects added variable', () {
      final snap2 = MockData.snapshot(
        step: 6,
        variables: {'x': 42, 'label': 'hello', 'active': true, 'newVar': 1},
      );
      final diffs = snap2.diff(snap);
      expect(diffs.containsKey('newVar'), isTrue);
    });

    test('diff detects removed variable', () {
      final snap2 = MockData.snapshot(
        step: 6,
        variables: {'x': 42, 'label': 'hello'},
      );
      final diffs = snap2.diff(snap);
      expect(diffs.containsKey('active'), isTrue);
    });

    test('round-trips through JSON', () {
      final json = snap.toJson();
      final restored = StateSnapshot.fromJson(json);
      expect(restored.stepNumber, equals(snap.stepNumber));
      expect(restored.variables['x'], equals(42));
      expect(restored.description, equals('test snapshot'));
    });

    test('withBookmark adds bookmark label', () {
      final bookmarked = snap.withBookmark('my-bookmark');
      expect(bookmarked.bookmarkLabel, equals('my-bookmark'));
      expect(bookmarked.stepNumber, equals(snap.stepNumber));
    });
  });
}
