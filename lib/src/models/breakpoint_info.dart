import 'package:meta/meta.dart';

/// The action to take when a breakpoint condition is satisfied.
enum BreakpointAction {
  /// Just print a message to the log.
  log,

  /// Pause execution (calls the registered pause callback).
  pause,

  /// Automatically rewind N steps and log a report.
  rewindAndReport,

  /// Throw an exception so the developer sees a clear stack trace.
  throwException,
}

/// Describes a single (conditional) breakpoint registered with
/// [BreakpointManager].
@immutable
class BreakpointInfo {
  /// Unique identifier assigned by the user or auto-generated.
  final String id;

  /// Variable name this breakpoint watches (or `null` for function-level).
  final String? variableName;

  /// Function name this breakpoint watches (or `null` for variable-level).
  final String? functionName;

  /// Optional source file filter — breakpoint only fires when mutations
  /// happen inside this file.
  final String? sourceFileFilter;

  /// The condition that must return `true` for the breakpoint to fire.
  /// Receives the new value of the watched variable.
  final bool Function(dynamic newValue, dynamic oldValue)? condition;

  /// Human-readable description (shown in logs and the UI overlay).
  final String? description;

  /// Action performed when this breakpoint fires.
  final BreakpointAction action;

  /// Maximum number of times this breakpoint may fire before being
  /// automatically disabled.  `null` = unlimited.
  final int? maxHitCount;

  /// Whether this breakpoint is currently enabled.
  final bool enabled;

  /// Number of times this breakpoint has fired (mutable via [withHitCount]).
  final int hitCount;

  const BreakpointInfo({
    required this.id,
    this.variableName,
    this.functionName,
    this.sourceFileFilter,
    this.condition,
    this.description,
    this.action = BreakpointAction.log,
    this.maxHitCount,
    this.enabled = true,
    this.hitCount = 0,
  }) : assert(variableName != null || functionName != null,
            'At least one of variableName or functionName must be set.');

  /// Returns `true` when the breakpoint is still active (not over its
  /// hit-count limit and currently enabled).
  bool get isActive =>
      enabled && (maxHitCount == null || hitCount < maxHitCount!);

  /// Increments the hit count and returns a new instance.
  BreakpointInfo incrementHitCount() => BreakpointInfo(
        id: id,
        variableName: variableName,
        functionName: functionName,
        sourceFileFilter: sourceFileFilter,
        condition: condition,
        description: description,
        action: action,
        maxHitCount: maxHitCount,
        enabled: enabled,
        hitCount: hitCount + 1,
      );

  /// Returns a copy with [enabled] set to false.
  BreakpointInfo disable() => BreakpointInfo(
        id: id,
        variableName: variableName,
        functionName: functionName,
        sourceFileFilter: sourceFileFilter,
        condition: condition,
        description: description,
        action: action,
        maxHitCount: maxHitCount,
        enabled: false,
        hitCount: hitCount,
      );

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'variableName': variableName,
        'functionName': functionName,
        'sourceFileFilter': sourceFileFilter,
        'description': description,
        'action': action.name,
        'maxHitCount': maxHitCount,
        'enabled': enabled,
        'hitCount': hitCount,
        // Note: the [condition] closure is not serialisable.
      };

  @override
  String toString() =>
      'Breakpoint[$id](${variableName ?? functionName}, '
      'action: ${action.name}, hits: $hitCount)';
}
