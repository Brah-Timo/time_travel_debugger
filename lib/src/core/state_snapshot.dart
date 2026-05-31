import 'package:meta/meta.dart';
import '../models/variable_record.dart';
import '../models/call_stack_frame.dart';

/// An immutable snapshot of the entire application state at a single point
/// in the execution timeline.
///
/// Each snapshot captures:
/// - The full variable map at that step.
/// - The call stack.
/// - The delta (list of [VariableRecord]s) that caused this snapshot.
/// - Rich metadata for display in the UI overlay.
@immutable
class StateSnapshot {
  /// Globally unique identifier (UUID v4).
  final String snapshotId;

  /// 0-based index on the execution timeline.
  final int stepNumber;

  /// Wall-clock timestamp when the snapshot was captured.
  final DateTime timestamp;

  /// All tracked variables and their current values at this step.
  final Map<String, dynamic> variables;

  /// Current call stack (outermost frame last).
  final List<CallStackFrame> callStack;

  /// Human-readable description of this step
  /// (e.g. `"x changed"`, `"Entered: fetchData"`).
  final String? description;

  /// The mutations that **caused** this snapshot to be created.
  /// Contains exactly the [VariableRecord]s processed in this step.
  final List<VariableRecord> changes;

  /// Optional user-supplied bookmark label (set via
  /// [TimeTravelEngine.annotate]).
  final String? bookmarkLabel;

  const StateSnapshot({
    required this.snapshotId,
    required this.stepNumber,
    required this.timestamp,
    required this.variables,
    required this.callStack,
    this.description,
    this.changes = const [],
    this.bookmarkLabel,
  });

  // ── Variable accessors ───────────────────────────────────────────────────

  /// Returns the value of [name] at this step, or `null` if not tracked.
  dynamic variable(String name) => variables[name];

  /// Returns `true` if [name] is tracked at this step.
  bool hasVariable(String name) => variables.containsKey(name);

  /// Sorted list of all tracked variable names.
  List<String> get variableNames => variables.keys.toList()..sort();

  /// Returns all variables whose name matches [pattern].
  Map<String, dynamic> filterVariables(Pattern pattern) =>
      Map.fromEntries(variables.entries
          .where((e) => e.key.contains(pattern)));

  // ── Call-stack helpers ───────────────────────────────────────────────────

  /// Current function being executed (innermost frame), or `null`.
  String? get currentFunction =>
      callStack.isNotEmpty ? callStack.last.qualifiedName : null;

  /// Pretty-printed call stack (each frame on its own line).
  String get callStackString =>
      callStack.reversed.map((f) => '  ${f.shortDescription}').join('\n');

  // ── Diff helpers ─────────────────────────────────────────────────────────

  /// Returns a map of variables whose values changed compared to [other].
  ///
  /// Keys are variable names; values are `{before, after}` pairs.
  Map<String, Map<String, dynamic>> diff(StateSnapshot other) {
    final result = <String, Map<String, dynamic>>{};
    final allKeys = {...variables.keys, ...other.variables.keys};
    for (final key in allKeys) {
      final before = other.variables[key];
      final after = variables[key];
      if (before != after) {
        result[key] = {'before': before, 'after': after};
      }
    }
    return result;
  }

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'snapshotId': snapshotId,
        'stepNumber': stepNumber,
        'timestamp': timestamp.toIso8601String(),
        'variables': variables.map(
          (k, v) => MapEntry(k, _encodeValue(v)),
        ),
        'callStack': callStack.map((f) => f.toJson()).toList(),
        'description': description,
        'changes': changes.map((r) => r.toJson()).toList(),
        'bookmarkLabel': bookmarkLabel,
      };

  factory StateSnapshot.fromJson(Map<String, dynamic> json) => StateSnapshot(
        snapshotId: json['snapshotId'] as String,
        stepNumber: json['stepNumber'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        variables:
            Map<String, dynamic>.from(json['variables'] as Map? ?? {}),
        callStack: (json['callStack'] as List? ?? [])
            .map((e) => CallStackFrame.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        description: json['description'] as String?,
        changes: (json['changes'] as List? ?? [])
            .map((e) => VariableRecord.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        bookmarkLabel: json['bookmarkLabel'] as String?,
      );

  StateSnapshot withBookmark(String label) => StateSnapshot(
        snapshotId: snapshotId,
        stepNumber: stepNumber,
        timestamp: timestamp,
        variables: variables,
        callStack: callStack,
        description: description,
        changes: changes,
        bookmarkLabel: label,
      );

  static dynamic _encodeValue(dynamic v) {
    if (v == null || v is bool || v is num || v is String) return v;
    if (v is List) return v.map(_encodeValue).toList();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _encodeValue(val)));
    }
    return v.toString();
  }

  @override
  String toString() =>
      'StateSnapshot(step=$stepNumber, vars=${variables.length}, '
      'desc=$description)';
}
