import 'package:meta/meta.dart';

/// Represents a single variable mutation event captured during recording.
///
/// Every time you call [TimeTravelEngine.record], a [VariableRecord] is
/// created and appended to the execution timeline.
@immutable
class VariableRecord {
  /// Name of the variable that changed.
  final String variableName;

  /// Value **before** the mutation (may be `null` for initialisation).
  final dynamic oldValue;

  /// Value **after** the mutation.
  final dynamic newValue;

  /// Wall-clock timestamp of the mutation.
  final DateTime timestamp;

  /// Source file where the mutation happened (relative or absolute path).
  final String sourceFile;

  /// Line number inside [sourceFile].
  final int lineNumber;

  /// Optional human-readable note about why the change happened.
  final String? description;

  /// Runtime type name of [newValue] (e.g. `"int"`, `"List<String>"`).
  final String dataType;

  /// Index of this record inside the flat record list.
  /// Set by [MemoryRecorder] after insertion.
  final int recordIndex;

  /// Optional exception/error message that was active when the
  /// mutation was recorded (for post-mortem debugging).
  final String? exceptionMessage;

  /// Tags for grouping / filtering records (e.g. `['ui', 'counter']`).
  final List<String> tags;

  const VariableRecord({
    required this.variableName,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.sourceFile,
    required this.lineNumber,
    this.description,
    required this.dataType,
    this.recordIndex = 0,
    this.exceptionMessage,
    this.tags = const [],
  });

  // ── Derived helpers ─────────────────────────────────────────────────────

  /// Human-readable change description: `"x: 0 → 42"`.
  String get changeDescription => '$variableName: $oldValue → $newValue';

  /// For numeric types, returns the delta as a [String]; otherwise `null`.
  String? get numericDelta {
    if (oldValue is num && newValue is num) {
      final delta = (newValue as num) - (oldValue as num);
      return (delta >= 0 ? '+' : '') + delta.toString();
    }
    return null;
  }

  /// Returns `true` when old and new values are deeply equal.
  bool get isNoOp => oldValue == newValue;

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'variableName': variableName,
        'oldValue': _encodeValue(oldValue),
        'newValue': _encodeValue(newValue),
        'timestamp': timestamp.toIso8601String(),
        'sourceFile': sourceFile,
        'lineNumber': lineNumber,
        'description': description,
        'dataType': dataType,
        'recordIndex': recordIndex,
        'exceptionMessage': exceptionMessage,
        'tags': tags,
      };

  factory VariableRecord.fromJson(Map<String, dynamic> json) => VariableRecord(
        variableName: json['variableName'] as String,
        oldValue: json['oldValue'],
        newValue: json['newValue'],
        timestamp: DateTime.parse(json['timestamp'] as String),
        sourceFile: json['sourceFile'] as String,
        lineNumber: json['lineNumber'] as int,
        description: json['description'] as String?,
        dataType: json['dataType'] as String? ?? 'dynamic',
        recordIndex: json['recordIndex'] as int? ?? 0,
        exceptionMessage: json['exceptionMessage'] as String?,
        tags: List<String>.from(json['tags'] as List? ?? []),
      );

  /// Creates a copy with updated [recordIndex].
  VariableRecord withIndex(int index) => VariableRecord(
        variableName: variableName,
        oldValue: oldValue,
        newValue: newValue,
        timestamp: timestamp,
        sourceFile: sourceFile,
        lineNumber: lineNumber,
        description: description,
        dataType: dataType,
        recordIndex: index,
        exceptionMessage: exceptionMessage,
        tags: tags,
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
      'VariableRecord(${changeDescription} @ $sourceFile:$lineNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariableRecord &&
          runtimeType == other.runtimeType &&
          variableName == other.variableName &&
          recordIndex == other.recordIndex &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      variableName.hashCode ^ recordIndex.hashCode ^ timestamp.hashCode;
}
