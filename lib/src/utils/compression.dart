import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Lightweight compression utilities for snapshot / record payloads.
///
/// Strategy used: **delta encoding** for consecutive snapshots that share
/// most of their variable map, combined with optional **gzip** for wire
/// transport or disk storage.
///
/// All methods are synchronous and allocation-minimal to meet the
/// sub-millisecond recording-path budget.
class Compression {
  const Compression._();

  // ── Gzip wrappers ─────────────────────────────────────────────────────────

  /// Gzip-compresses [text] (UTF-8 encoded) and returns raw bytes.
  static Uint8List gzipEncode(String text) {
    final bytes = utf8.encode(text);
    final compressed = GZipCodec(level: 6).encode(bytes);
    return Uint8List.fromList(compressed);
  }

  /// Decompresses gzip [bytes] back to a UTF-8 string.
  static String gzipDecode(Uint8List bytes) {
    final decompressed = GZipCodec().decode(bytes);
    return utf8.decode(decompressed);
  }

  // ── Delta encoding ────────────────────────────────────────────────────────

  /// Computes the **delta** between two variable maps.
  ///
  /// Returns a map containing only the keys whose values differ.
  /// Keys present in [before] but absent in [after] are recorded as
  /// `{'__deleted__': true}`.
  static Map<String, dynamic> computeDelta(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    final delta = <String, dynamic>{};
    final allKeys = {...before.keys, ...after.keys};

    for (final key in allKeys) {
      final bVal = before[key];
      final aVal = after[key];
      if (!after.containsKey(key)) {
        delta[key] = {'__deleted__': true};
      } else if (bVal != aVal) {
        delta[key] = aVal;
      }
    }
    return delta;
  }

  /// Applies a [delta] produced by [computeDelta] to [base], returning
  /// the reconstructed variable map.
  static Map<String, dynamic> applyDelta(
    Map<String, dynamic> base,
    Map<String, dynamic> delta,
  ) {
    final result = Map<String, dynamic>.from(base);
    for (final entry in delta.entries) {
      if (entry.value is Map &&
          (entry.value as Map).containsKey('__deleted__')) {
        result.remove(entry.key);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  // ── Run-length helpers ────────────────────────────────────────────────────

  /// Run-length encodes a list of integers (useful for step-index lists).
  ///
  /// Output format: `[value, count, value, count, ...]`
  static List<int> rleEncode(List<int> data) {
    if (data.isEmpty) return [];
    final result = <int>[];
    var current = data[0];
    var count = 1;
    for (var i = 1; i < data.length; i++) {
      if (data[i] == current) {
        count++;
      } else {
        result
          ..add(current)
          ..add(count);
        current = data[i];
        count = 1;
      }
    }
    result
      ..add(current)
      ..add(count);
    return result;
  }

  /// Decodes a run-length encoded list produced by [rleEncode].
  static List<int> rleDecode(List<int> encoded) {
    final result = <int>[];
    for (var i = 0; i + 1 < encoded.length; i += 2) {
      final value = encoded[i];
      final count = encoded[i + 1];
      for (var j = 0; j < count; j++) result.add(value);
    }
    return result;
  }

  // ── Ratio estimation ──────────────────────────────────────────────────────

  /// Estimates the compression ratio of delta-encoding two maps.
  ///
  /// Returns a value in `[0, 1]` where 0 means identical (nothing to store)
  /// and 1 means completely different.
  static double deltaRatio(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    if (before.isEmpty && after.isEmpty) return 0;
    final delta = computeDelta(before, after);
    final total = before.length + after.length;
    if (total == 0) return 0;
    return delta.length / ((before.length + after.length) / 2);
  }
}
