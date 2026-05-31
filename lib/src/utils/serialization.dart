import 'dart:convert';
import '../core/state_snapshot.dart';
import '../models/variable_record.dart';
import '../models/session_metadata.dart';

/// Serialisation helpers for the `time_travel_debugger` package.
///
/// All public methods are pure functions (no I/O side-effects) so they can
/// be unit-tested trivially.
class Serialization {
  const Serialization._();

  // ── Snapshot ──────────────────────────────────────────────────────────────

  static String snapshotToJson(StateSnapshot s, {bool pretty = false}) =>
      pretty
          ? const JsonEncoder.withIndent('  ').convert(s.toJson())
          : jsonEncode(s.toJson());

  static StateSnapshot snapshotFromJson(String json) =>
      StateSnapshot.fromJson(
          Map<String, dynamic>.from(jsonDecode(json) as Map));

  // ── VariableRecord ────────────────────────────────────────────────────────

  static String recordToJson(VariableRecord r, {bool pretty = false}) =>
      pretty
          ? const JsonEncoder.withIndent('  ').convert(r.toJson())
          : jsonEncode(r.toJson());

  static VariableRecord recordFromJson(String json) =>
      VariableRecord.fromJson(
          Map<String, dynamic>.from(jsonDecode(json) as Map));

  // ── Bulk helpers ──────────────────────────────────────────────────────────

  /// Serialises a list of snapshots to a JSON array string.
  static String snapshotsToJson(List<StateSnapshot> snapshots,
          {bool pretty = false}) =>
      pretty
          ? const JsonEncoder.withIndent('  ')
              .convert(snapshots.map((s) => s.toJson()).toList())
          : jsonEncode(snapshots.map((s) => s.toJson()).toList());

  static List<StateSnapshot> snapshotsFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((e) =>
            StateSnapshot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static String recordsToJson(List<VariableRecord> records,
          {bool pretty = false}) =>
      pretty
          ? const JsonEncoder.withIndent('  ')
              .convert(records.map((r) => r.toJson()).toList())
          : jsonEncode(records.map((r) => r.toJson()).toList());

  static List<VariableRecord> recordsFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((e) =>
            VariableRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Generic value encoding ────────────────────────────────────────────────

  /// Attempts to encode any Dart value to a JSON-safe representation.
  static dynamic encodeValue(dynamic value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Duration) return value.inMicroseconds;
    if (value is List) return value.map(encodeValue).toList();
    if (value is Map) {
      return value
          .map((k, v) => MapEntry(k.toString(), encodeValue(v)));
    }
    if (value is Set) return value.map(encodeValue).toList();
    try {
      // If the object has a toJson method, use it.
      // ignore: avoid_dynamic_calls
      return (value as dynamic).toJson();
    } catch (_) {
      return value.toString();
    }
  }

  /// Converts a raw JSON map to a typed [Map<String, dynamic>].
  static Map<String, dynamic> normaliseMap(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  // ── Session file ─────────────────────────────────────────────────────────

  static String buildSessionJson({
    required SessionMetadata metadata,
    required List<StateSnapshot> snapshots,
    required List<VariableRecord> records,
    bool pretty = true,
  }) {
    final data = {
      'ttdVersion': '1.0',
      'metadata': metadata.toJson(),
      'snapshots': snapshots.map((s) => s.toJson()).toList(),
      'records': records.map((r) => r.toJson()).toList(),
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }
}
