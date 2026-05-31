/// Flutter Counter App — Time Travel Debugger integration example.
///
/// Wraps a standard counter app with [TimeTravelWidget].
/// Tap the blue ⏰ FAB (bottom-right) to open the debug overlay.

import 'package:flutter/material.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';
import 'screens/counter_screen.dart';

// ── Global engine (shared across the app) ────────────────────────────────────
final TimeTravelEngine ttdEngine = TimeTravelEngine(
  config: const TimeTravelConfig(
    appName: 'FlutterCounterExample',
    appVersion: '1.0.0',
    autoCompressInterval: Duration(seconds: 30),
  ),
);

void main() {
  ttdEngine.startRecording();
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTD Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58a6ff),
          brightness: Brightness.dark,
        ),
      ),
      home: TimeTravelWidget(
        engine: ttdEngine,
        child: const CounterScreen(),
      ),
    );
  }
}
