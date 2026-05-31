# Breakpoints & Watchpoints — `time_travel_debugger`

## Breakpoints (`BreakpointManager`)

Breakpoints pause the logical execution trace when a condition is met.
They are evaluated **manually** after every relevant `engine.record()` call;
there is no background thread involved.

### Variable breakpoints

```dart
final bp = BreakpointManager();

// Fire when 'score' exceeds 100
bp.addVariableBreakpoint(
  variableName: 'score',
  condition: (newValue, oldValue) => (newValue as int) > 100,
  description: 'Score exceeds 100',
  action: BreakpointAction.log,
);

// After recording:
final rec = engine.historyOf('score').last;
final events = bp.evaluateRecord(rec, engine.currentPosition);
```

### Function breakpoints

```dart
bp.addFunctionBreakpoint(
  functionName: 'processPayment',
  condition: (record, step) => record.newValue == null, // returned null
  description: 'Payment returned null',
  action: BreakpointAction.callback,
);
```

### Breakpoint actions

| Action | Behaviour |
|--------|-----------|
| `BreakpointAction.log` | Writes a structured log entry via `TtdLogger`. |
| `BreakpointAction.pause` | Sets `engine.isPaused = true` (recording stops). |
| `BreakpointAction.callback` | Calls `BreakpointManager.onBreakpointFired`. |
| `BreakpointAction.ignore` | Counts the hit but takes no other action. |

### Hit counts & max-hit limits

```dart
bp.addVariableBreakpoint(
  variableName: 'retryCount',
  condition: (nv, _) => (nv as int) >= 3,
  description: 'Third retry reached',
  action: BreakpointAction.log,
  maxHitCount: 1, // Fire only once
);
```

Once `maxHitCount` hits are recorded, the breakpoint auto-disables.

### Source-file filter

```dart
bp.addVariableBreakpoint(
  variableName: 'userId',
  condition: (nv, ov) => nv != ov,
  description: 'User ID changed',
  action: BreakpointAction.log,
  sourceFileFilter: 'auth_service.dart', // Only from this file
);
```

### Managing breakpoints

```dart
// List all / active
print(bp.all.length);
print(bp.active.length);

// Disable / enable by ID
bp.disable('my-bp-id');
bp.enable('my-bp-id');

// Remove
bp.remove('my-bp-id');

// Clear all
bp.clear();

// Event history
for (final event in bp.eventHistory) {
  print('${event.stepNumber}: ${event.breakpoint.description}');
}
```

### Plugging into the Flutter overlay

```dart
bp.onBreakpointFired = (event) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('BP: ${event.breakpoint.description}'),
      duration: const Duration(seconds: 3),
    ),
  );
};
```

---

## Watchpoints (`WatchpointManager`)

Watchpoints are **non-blocking observers** — they never pause recording and are
ideal for side-effects like analytics, logging, or UI updates.

### Adding a watchpoint

```dart
final wm = WatchpointManager();

wm.add(
  variableName: 'cartTotal',
  callback: (record) {
    analytics.track('cart_total_changed', {
      'from': record.oldValue,
      'to': record.newValue,
    });
  },
  filter: (newValue, oldValue) =>
      (newValue as double) != (oldValue as double),
);
```

### Notifying watchpoints

Call `wm.notify(record)` after every relevant `engine.record()`:

```dart
engine.record(name: 'cartTotal', oldValue: 0.0, newValue: 49.99,
    file: 'cart.dart', line: 20);
wm.notify(engine.historyOf('cartTotal').last);
```

### Removing watchpoints

```dart
final id = wm.add(variableName: 'x', callback: (_) {});
wm.remove(id);

// Remove all for a variable
wm.removeAll('x');
```

### Watchpoints vs Breakpoints

| Feature | Watchpoint | Breakpoint |
|---------|-----------|------------|
| Pauses recording | No | Optional (`pause` action) |
| Returns events | No | Yes (`List<BreakpointEvent>`) |
| Condition / filter | Optional | Optional |
| Max-hit limit | No | Yes |
| Source-file filter | No | Yes |
| Typical use | Analytics, logging | Debugging, bug reproduction |

---

## `BreakpointEvent`

Returned by `bp.evaluateRecord()` and passed to `onBreakpointFired`:

```dart
class BreakpointEvent {
  final BreakpointInfo breakpoint; // The breakpoint that fired
  final VariableRecord trigger;    // The record that triggered it
  final int stepNumber;            // Engine cursor at the time
  final DateTime firedAt;          // Wall-clock time
}
```

---

## `BreakpointInfo`

```dart
class BreakpointInfo {
  final String id;
  final String? variableName;
  final String? functionName;
  final bool Function(dynamic newValue, dynamic oldValue)? condition;
  final String description;
  final BreakpointAction action;
  final int? maxHitCount;
  final String? sourceFileFilter;

  bool get isActive;
  int get hitCount;
}
```
