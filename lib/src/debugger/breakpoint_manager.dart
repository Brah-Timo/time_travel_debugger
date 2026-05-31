import 'package:uuid/uuid.dart';
import '../models/breakpoint_info.dart';
import '../models/variable_record.dart';
import '../utils/ttd_logger.dart';

/// Fired when a breakpoint's condition is met.
class BreakpointEvent {
  final BreakpointInfo breakpoint;
  final VariableRecord trigger;
  final int step;
  final DateTime firedAt;

  const BreakpointEvent({
    required this.breakpoint,
    required this.trigger,
    required this.step,
    required this.firedAt,
  });

  @override
  String toString() =>
      'BreakpointEvent(id=${breakpoint.id}, '
      'var=${trigger.variableName}, '
      'step=$step, '
      'action=${breakpoint.action.name})';
}

/// Manages the complete lifecycle of conditional breakpoints.
///
/// ## Usage
/// ```dart
/// final bp = manager.addVariableBreakpoint(
///   variableName: 'counter',
///   condition: (newVal, oldVal) => newVal > 100,
///   description: 'counter exceeded 100',
///   action: BreakpointAction.log,
/// );
///
/// // In your recording loop:
/// manager.evaluateRecord(record, currentStep);
/// ```
class BreakpointManager {
  final Map<String, BreakpointInfo> _breakpoints = {};
  final List<BreakpointEvent> _eventHistory = [];

  /// Maximum events to keep in [eventHistory].
  final int maxEventHistory;

  /// Fired synchronously when a breakpoint triggers.
  void Function(BreakpointEvent event)? onBreakpointFired;

  /// Optional pause callback invoked for [BreakpointAction.pause].
  void Function(BreakpointEvent event)? onPause;

  BreakpointManager({this.maxEventHistory = 500});

  // ── Add breakpoints ───────────────────────────────────────────────────────

  /// Adds a breakpoint on a **variable** mutation.
  BreakpointInfo addVariableBreakpoint({
    String? id,
    required String variableName,
    bool Function(dynamic newValue, dynamic oldValue)? condition,
    String? description,
    BreakpointAction action = BreakpointAction.log,
    int? maxHitCount,
    String? sourceFileFilter,
  }) {
    final bp = BreakpointInfo(
      id: id ?? const Uuid().v4(),
      variableName: variableName,
      condition: condition,
      description: description ?? 'Break on $variableName change',
      action: action,
      maxHitCount: maxHitCount,
      sourceFileFilter: sourceFileFilter,
    );
    _breakpoints[bp.id] = bp;
    log.debug('Breakpoint added: ${bp.id} on "$variableName"');
    return bp;
  }

  /// Adds a breakpoint on a **function** entry.
  BreakpointInfo addFunctionBreakpoint({
    String? id,
    required String functionName,
    bool Function(dynamic newValue, dynamic oldValue)? condition,
    String? description,
    BreakpointAction action = BreakpointAction.log,
  }) {
    final bp = BreakpointInfo(
      id: id ?? const Uuid().v4(),
      functionName: functionName,
      condition: condition,
      description: description ?? 'Break on $functionName entry',
      action: action,
    );
    _breakpoints[bp.id] = bp;
    return bp;
  }

  // ── Remove / toggle ───────────────────────────────────────────────────────

  void remove(String id) {
    _breakpoints.remove(id);
    log.debug('Breakpoint removed: $id');
  }

  void removeAll() => _breakpoints.clear();

  void disable(String id) {
    final bp = _breakpoints[id];
    if (bp != null) _breakpoints[id] = bp.disable();
  }

  void enable(String id) {
    final bp = _breakpoints[id];
    if (bp != null) {
      _breakpoints[id] = BreakpointInfo(
        id: bp.id,
        variableName: bp.variableName,
        functionName: bp.functionName,
        sourceFileFilter: bp.sourceFileFilter,
        condition: bp.condition,
        description: bp.description,
        action: bp.action,
        maxHitCount: bp.maxHitCount,
        enabled: true,
        hitCount: bp.hitCount,
      );
    }
  }

  // ── Evaluation ────────────────────────────────────────────────────────────

  /// Evaluates all active breakpoints against [record] at [step].
  ///
  /// Returns a list of events that fired (may be empty).
  List<BreakpointEvent> evaluateRecord(VariableRecord record, int step) {
    final fired = <BreakpointEvent>[];

    for (final entry in _breakpoints.entries) {
      final bp = entry.value;
      if (!bp.isActive) continue;
      if (bp.variableName != null &&
          bp.variableName != record.variableName) continue;
      if (bp.sourceFileFilter != null &&
          !record.sourceFile.contains(bp.sourceFileFilter!)) continue;

      final conditionMet = bp.condition == null ||
          bp.condition!(record.newValue, record.oldValue);
      if (!conditionMet) continue;

      // Fire!
      final updatedBp = bp.incrementHitCount();
      _breakpoints[entry.key] = updatedBp;

      final event = BreakpointEvent(
        breakpoint: updatedBp,
        trigger: record,
        step: step,
        firedAt: DateTime.now(),
      );
      fired.add(event);
      _recordEvent(event);
      _dispatch(event);
    }

    return fired;
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  List<BreakpointInfo> get all => _breakpoints.values.toList();
  List<BreakpointInfo> get active =>
      _breakpoints.values.where((b) => b.isActive).toList();
  List<BreakpointEvent> get eventHistory =>
      List.unmodifiable(_eventHistory);

  BreakpointInfo? find(String id) => _breakpoints[id];

  // ── Private ───────────────────────────────────────────────────────────────

  void _recordEvent(BreakpointEvent event) {
    if (_eventHistory.length >= maxEventHistory) {
      _eventHistory.removeAt(0);
    }
    _eventHistory.add(event);
  }

  void _dispatch(BreakpointEvent event) {
    switch (event.breakpoint.action) {
      case BreakpointAction.log:
        log.info('🔴 BREAKPOINT: ${event.breakpoint.description} '
            '| var=${event.trigger.variableName} '
            '| newVal=${event.trigger.newValue} '
            '| step=${event.step}');
      case BreakpointAction.pause:
        onPause?.call(event);
      case BreakpointAction.rewindAndReport:
        log.warning('⏪ BREAKPOINT (rewind+report): '
            '${event.breakpoint.description} @ step ${event.step}');
      case BreakpointAction.throwException:
        throw Exception(
            'Breakpoint triggered: ${event.breakpoint.description} '
            'at step ${event.step}, '
            '${event.trigger.variableName} = ${event.trigger.newValue}');
    }
    onBreakpointFired?.call(event);
  }
}
