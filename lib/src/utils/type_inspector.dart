/// Utilities for inspecting Dart runtime types and producing
/// human-readable type descriptions used by the UI overlay and reports.
class TypeInspector {
  const TypeInspector._();

  // ── Type classification ───────────────────────────────────────────────────

  static bool isNumeric(dynamic value) => value is num;
  static bool isString(dynamic value) => value is String;
  static bool isBool(dynamic value) => value is bool;
  static bool isList(dynamic value) => value is List;
  static bool isMap(dynamic value) => value is Map;
  static bool isSet(dynamic value) => value is Set;
  static bool isNull(dynamic value) => value == null;

  static bool isPrimitive(dynamic value) =>
      value == null ||
      value is bool ||
      value is num ||
      value is String;

  // ── Type name helpers ─────────────────────────────────────────────────────

  /// Returns a clean type name string for [value].
  ///
  /// Examples: `"int"`, `"String"`, `"List<int>"`, `"Map<String, dynamic>"`.
  static String typeName(dynamic value) {
    if (value == null) return 'Null';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is String) return 'String';
    if (value is List) return 'List<${_innerType(value)}>';
    if (value is Map) return 'Map<String, ${_innerType(value.values)}>';
    if (value is Set) return 'Set<${_innerType(value)}>';
    if (value is DateTime) return 'DateTime';
    if (value is Duration) return 'Duration';
    return value.runtimeType.toString();
  }

  /// Returns a short display string for [value] (truncated to [maxLength]).
  static String displayValue(dynamic value, {int maxLength = 80}) {
    if (value == null) return 'null';
    if (value is String) {
      final escaped = value.replaceAll('\n', '\\n');
      return '"${_truncate(escaped, maxLength - 2)}"';
    }
    if (value is List) {
      return '[${_truncate(value.map(displayValue).join(', '), maxLength - 2)}]';
    }
    if (value is Map) {
      final entries = value.entries
          .map((e) => '${e.key}: ${displayValue(e.value)}')
          .join(', ');
      return '{${_truncate(entries, maxLength - 2)}}';
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Duration) return value.toString();
    return _truncate(value.toString(), maxLength);
  }

  /// Returns a diff-friendly string showing `oldValue → newValue`.
  static String diffString(dynamic oldValue, dynamic newValue) =>
      '${displayValue(oldValue)} → ${displayValue(newValue)}';

  // ── Private ───────────────────────────────────────────────────────────────

  static String _innerType(Iterable? iterable) {
    if (iterable == null || iterable.isEmpty) return 'dynamic';
    final types = iterable.map((e) => typeName(e)).toSet();
    if (types.length == 1) return types.first;
    return 'dynamic';
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';
}
