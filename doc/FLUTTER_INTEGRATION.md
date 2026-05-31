# Flutter Integration Guide — `time_travel_debugger`

## Prerequisites

- Flutter ≥ 3.10.0
- Dart SDK ≥ 3.0.0

Add to `pubspec.yaml`:

```yaml
dependencies:
  time_travel_debugger: ^1.0.0
```

---

## 1. Wrapping your app with `TimeTravelWidget`

`TimeTravelWidget` renders a draggable floating action button (FAB) on top of
your existing UI. Tapping the FAB opens the inline debugger panel with the
timeline slider, statistics, and navigation buttons.

```dart
import 'package:flutter/material.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';

final _engine = TimeTravelEngine(
  config: TimeTravelConfig(
    appName: 'MyFlutterApp',
    appVersion: '1.0.0',
    maxHotRecords: 20000,
  ),
);

void main() {
  _engine.startRecording();
  runApp(
    TimeTravelWidget(
      engine: _engine,
      // Show only in debug/profile builds (default: false for release)
      showInRelease: false,
      child: const MyApp(),
    ),
  );
}
```

The overlay is completely transparent to your widget tree — it intercepts no
events outside the FAB and draggable panel.

---

## 2. Recording state mutations

Record **every** meaningful state change so the timeline is accurate:

```dart
// Inside a Bloc, ChangeNotifier, Riverpod notifier, etc.
void increment() {
  final old = _counter;
  _counter++;
  _engine.record(
    name: 'counter',
    oldValue: old,
    newValue: _counter,
    file: 'counter_cubit.dart',
    line: 14,
    description: 'User pressed +',
    tags: ['ui', 'counter'],
  );
  notifyListeners();
}
```

Or use the inline `track()` helper to keep assignments concise:

```dart
_counter = _engine.track('counter', _counter, _counter + 1,
    'counter_cubit.dart', 14);
```

---

## 3. Annotating key moments

Use `annotate()` to mark logical phases — login, checkout, error — so you can
jump directly to them in the timeline:

```dart
_engine.annotate('checkout: payment initiated');
```

Access bookmarks from the `SnapshotViewer` panel or programmatically:

```dart
final checkoutSnap = _engine.bookmarks()
    .firstWhere((s) => s.bookmarkLabel?.contains('checkout') == true);
```

---

## 4. `VariableInspector` screen

Push `VariableInspector` as a full route to inspect the complete mutation
history of a single variable with copy-to-clipboard support:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => VariableInspector(
      engine: _engine,
      variableName: 'selectedProduct',
    ),
  ),
);
```

---

## 5. `SnapshotViewer` screen

Shows all variables at any step with three tabs — **Variables**, **Call Stack**,
and **Changes** — plus a search field:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SnapshotViewer(
      snapshot: _engine.currentSnapshot(),
      engine: _engine,
    ),
  ),
);
```

---

## 6. `TimelineUI` widget

Embed the slim timeline slider anywhere in your layout:

```dart
TimelineUI(
  engine: _engine,
  onStepChanged: (step) {
    setState(() {
      // Optionally drive your UI from the debugger cursor
    });
  },
)
```

---

## 7. Breakpoints with UI feedback

```dart
final bp = BreakpointManager();
bp.onBreakpointFired = (event) {
  // Show a snackbar, play a sound, etc.
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('BP hit: ${event.breakpoint.description}')),
  );
};

bp.addVariableBreakpoint(
  variableName: 'errorCode',
  condition: (nv, _) => nv != null,
  action: BreakpointAction.callback,
  description: 'Any error occurred',
);
```

After every `record()`:

```dart
final rec = _engine.historyOf('errorCode').last;
bp.evaluateRecord(rec, _engine.currentPosition);
```

---

## 8. Disabling in release builds

`TimeTravelWidget` respects `showInRelease: false` (the default). You can also
gate recording with `kDebugMode`:

```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  _engine.startRecording();
}
```

---

## 9. Saving sessions from Flutter

```dart
// e.g. in app lifecycle observer
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    _engine.stopRecording();
    _engine.saveSession().then((_) => debugPrint('Session saved.'));
  }
}
```

---

## 10. Complete counter example

See `example/flutter_app_example/` for a full runnable counter app that
demonstrates `TimeTravelWidget`, `VariableInspector`, recording, and
breakpoints in a realistic Flutter project.
