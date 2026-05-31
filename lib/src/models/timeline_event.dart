import 'package:meta/meta.dart';
import 'variable_record.dart';

/// The kind of event that was recorded on the timeline.
enum TimelineEventKind {
  /// A variable was created or mutated.
  variableMutation,

  /// A function was entered.
  functionEntry,

  /// A function returned.
  functionReturn,

  /// An exception was thrown (and optionally caught).
  exceptionThrown,

  /// A custom user annotation / bookmark.
  annotation,

  /// A snapshot was explicitly requested by the developer.
  manualSnapshot,
}

/// A single entry on the execution timeline.
///
/// Wraps a [VariableRecord] for mutation events, and carries lightweight
/// metadata for all other event types.
@immutable
class TimelineEvent {
  /// Sequential index across all events (timeline position).
  final int index;

  /// Kind of event.
  final TimelineEventKind kind;

  /// Wall-clock timestamp.
  final DateTime timestamp;

  /// The variable record for [TimelineEventKind.variableMutation];
  /// `null` for all other kinds.
  final VariableRecord? variableRecord;

  /// Function name for entry / return events.
  final String? functionName;

  /// User-supplied label (for annotations and manual snapshots).
  final String? label;

  /// Thread / isolate name (for multi-isolate apps).
  final String isolateName;

  const TimelineEvent({
    required this.index,
    required this.kind,
    required this.timestamp,
    this.variableRecord,
    this.functionName,
    this.label,
    this.isolateName = 'main',
  });

  // ── Factory constructors ─────────────────────────────────────────────────

  factory TimelineEvent.mutation({
    required int index,
    required VariableRecord record,
    String isolateName = 'main',
  }) =>
      TimelineEvent(
        index: index,
        kind: TimelineEventKind.variableMutation,
        timestamp: record.timestamp,
        variableRecord: record,
        isolateName: isolateName,
      );

  factory TimelineEvent.functionEntry({
    required int index,
    required String functionName,
    required DateTime timestamp,
    String isolateName = 'main',
  }) =>
      TimelineEvent(
        index: index,
        kind: TimelineEventKind.functionEntry,
        timestamp: timestamp,
        functionName: functionName,
        isolateName: isolateName,
      );

  factory TimelineEvent.functionReturn({
    required int index,
    required String functionName,
    required DateTime timestamp,
    String isolateName = 'main',
  }) =>
      TimelineEvent(
        index: index,
        kind: TimelineEventKind.functionReturn,
        timestamp: timestamp,
        functionName: functionName,
        isolateName: isolateName,
      );

  factory TimelineEvent.annotation({
    required int index,
    required String label,
    required DateTime timestamp,
    String isolateName = 'main',
  }) =>
      TimelineEvent(
        index: index,
        kind: TimelineEventKind.annotation,
        timestamp: timestamp,
        label: label,
        isolateName: isolateName,
      );

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'index': index,
        'kind': kind.name,
        'timestamp': timestamp.toIso8601String(),
        'variableRecord': variableRecord?.toJson(),
        'functionName': functionName,
        'label': label,
        'isolateName': isolateName,
      };

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        index: json['index'] as int,
        kind: TimelineEventKind.values
            .firstWhere((e) => e.name == json['kind']),
        timestamp: DateTime.parse(json['timestamp'] as String),
        variableRecord: json['variableRecord'] != null
            ? VariableRecord.fromJson(
                Map<String, dynamic>.from(json['variableRecord'] as Map))
            : null,
        functionName: json['functionName'] as String?,
        label: json['label'] as String?,
        isolateName: json['isolateName'] as String? ?? 'main',
      );

  @override
  String toString() =>
      'TimelineEvent[$index](${kind.name} @ ${timestamp.toIso8601String()})';
}
