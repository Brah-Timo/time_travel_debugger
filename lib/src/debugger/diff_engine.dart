import '../core/state_snapshot.dart';
import '../models/variable_record.dart';
import '../utils/type_inspector.dart';

/// The kind of change detected by [DiffEngine].
enum DiffKind { added, removed, modified, unchanged }

/// A single entry in a snapshot diff.
class DiffEntry {
  final String variableName;
  final DiffKind kind;
  final dynamic valueBefore;
  final dynamic valueAfter;
  final String typeNameBefore;
  final String typeNameAfter;

  const DiffEntry({
    required this.variableName,
    required this.kind,
    required this.valueBefore,
    required this.valueAfter,
    required this.typeNameBefore,
    required this.typeNameAfter,
  });

  /// Human-readable summary: `"x: 0 → 42 (int)"`.
  String get summary {
    switch (kind) {
      case DiffKind.added:
        return '+ $variableName: ${TypeInspector.displayValue(valueAfter)}'
            ' ($typeNameAfter)';
      case DiffKind.removed:
        return '- $variableName: ${TypeInspector.displayValue(valueBefore)}'
            ' ($typeNameBefore)';
      case DiffKind.modified:
        return '~ $variableName: '
            '${TypeInspector.displayValue(valueBefore)} → '
            '${TypeInspector.displayValue(valueAfter)} '
            '($typeNameAfter)';
      case DiffKind.unchanged:
        return '  $variableName: ${TypeInspector.displayValue(valueAfter)}';
    }
  }

  @override
  String toString() => summary;
}

/// Full result of a diff between two [StateSnapshot]s.
class SnapshotDiff {
  final StateSnapshot before;
  final StateSnapshot after;
  final List<DiffEntry> entries;

  const SnapshotDiff({
    required this.before,
    required this.after,
    required this.entries,
  });

  List<DiffEntry> get added =>
      entries.where((e) => e.kind == DiffKind.added).toList();
  List<DiffEntry> get removed =>
      entries.where((e) => e.kind == DiffKind.removed).toList();
  List<DiffEntry> get modified =>
      entries.where((e) => e.kind == DiffKind.modified).toList();
  List<DiffEntry> get unchanged =>
      entries.where((e) => e.kind == DiffKind.unchanged).toList();

  bool get hasDifferences =>
      added.isNotEmpty || removed.isNotEmpty || modified.isNotEmpty;

  int get stepDelta => after.stepNumber - before.stepNumber;
  Duration get timeDelta =>
      after.timestamp.difference(before.timestamp);

  /// Compact multi-line textual representation.
  String toText({bool includeUnchanged = false}) {
    final lines = <String>[];
    lines.add('=== Diff: step ${before.stepNumber} → ${after.stepNumber} '
        '(Δ${stepDelta} steps, Δ${timeDelta.inMilliseconds}ms) ===');
    for (final e in entries) {
      if (!includeUnchanged && e.kind == DiffKind.unchanged) continue;
      lines.add(e.summary);
    }
    if (!hasDifferences) lines.add('(no differences)');
    return lines.join('\n');
  }
}

/// Computes diffs between [StateSnapshot]s.
class DiffEngine {
  const DiffEngine();

  // ── Snapshot diff ─────────────────────────────────────────────────────────

  /// Returns the full diff between [before] and [after].
  SnapshotDiff diff(StateSnapshot before, StateSnapshot after) {
    final allKeys = {
      ...before.variables.keys,
      ...after.variables.keys,
    };
    final entries = <DiffEntry>[];

    for (final key in allKeys.toList()..sort()) {
      final hasBefore = before.variables.containsKey(key);
      final hasAfter = after.variables.containsKey(key);
      final vBefore = before.variables[key];
      final vAfter = after.variables[key];

      DiffKind kind;
      if (!hasBefore && hasAfter) {
        kind = DiffKind.added;
      } else if (hasBefore && !hasAfter) {
        kind = DiffKind.removed;
      } else if (vBefore != vAfter) {
        kind = DiffKind.modified;
      } else {
        kind = DiffKind.unchanged;
      }

      entries.add(DiffEntry(
        variableName: key,
        kind: kind,
        valueBefore: vBefore,
        valueAfter: vAfter,
        typeNameBefore: TypeInspector.typeName(vBefore),
        typeNameAfter: TypeInspector.typeName(vAfter),
      ));
    }

    return SnapshotDiff(before: before, after: after, entries: entries);
  }

  // ── Record-level diff ─────────────────────────────────────────────────────

  /// Returns a quick diff between two [VariableRecord]s for the same variable.
  ///
  /// Throws [ArgumentError] if the variable names differ.
  Map<String, dynamic> diffRecords(VariableRecord a, VariableRecord b) {
    if (a.variableName != b.variableName) {
      throw ArgumentError(
          'Cannot diff records for different variables: '
          '"${a.variableName}" vs "${b.variableName}".');
    }
    return {
      'variable': a.variableName,
      'from': {
        'value': a.newValue,
        'step': a.recordIndex,
        'time': a.timestamp.toIso8601String(),
      },
      'to': {
        'value': b.newValue,
        'step': b.recordIndex,
        'time': b.timestamp.toIso8601String(),
      },
      'delta': a.newValue is num && b.newValue is num
          ? (b.newValue as num) - (a.newValue as num)
          : null,
    };
  }

  // ── Timeline range diff ───────────────────────────────────────────────────

  /// Returns a list of diffs for consecutive snapshot pairs in [snapshots].
  ///
  /// Useful for building the timeline view showing changes step by step.
  List<SnapshotDiff> diffTimeline(List<StateSnapshot> snapshots) {
    if (snapshots.length < 2) return [];
    final result = <SnapshotDiff>[];
    for (var i = 0; i < snapshots.length - 1; i++) {
      final d = diff(snapshots[i], snapshots[i + 1]);
      if (d.hasDifferences) result.add(d);
    }
    return result;
  }
}
