import 'package:flutter/material.dart';
import 'package:time_travel_debugger/time_travel_debugger.dart';
import '../main.dart' show ttdEngine;

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int _counter = 0;
  String _lastAction = 'none';

  void _increment() {
    final old = _counter;
    setState(() {
      _counter++;
      _lastAction = 'increment';
    });
    ttdEngine.record(
      name: 'counter',
      oldValue: old,
      newValue: _counter,
      file: 'counter_screen.dart',
      line: 20,
      description: 'User tapped increment',
      tags: ['ui', 'counter'],
    );
    ttdEngine.record(
      name: 'lastAction',
      oldValue: 'none',
      newValue: _lastAction,
      file: 'counter_screen.dart',
      line: 27,
    );
  }

  void _decrement() {
    final old = _counter;
    setState(() {
      _counter--;
      _lastAction = 'decrement';
    });
    ttdEngine.record(
      name: 'counter',
      oldValue: old,
      newValue: _counter,
      file: 'counter_screen.dart',
      line: 40,
      description: 'User tapped decrement',
      tags: ['ui', 'counter'],
    );
  }

  void _reset() {
    final old = _counter;
    setState(() {
      _counter = 0;
      _lastAction = 'reset';
    });
    ttdEngine.record(
      name: 'counter',
      oldValue: old,
      newValue: 0,
      file: 'counter_screen.dart',
      line: 54,
      description: 'User reset counter',
      tags: ['ui', 'counter'],
    );
    ttdEngine.annotate('Counter reset to 0');
  }

  void _openInspector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VariableInspector(
          engine: ttdEngine,
          variableName: 'counter',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TTD Counter Example'),
        backgroundColor: const Color(0xFF161b22),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined,
                color: Color(0xFF58a6ff)),
            tooltip: 'Inspect counter variable',
            onPressed: _openInspector,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _counter.toString(),
              style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Color(0xFF58a6ff),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last action: $_lastAction',
              style: const TextStyle(
                  color: Color(0xFF8b949e), fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: Icons.remove,
                  color: const Color(0xFFf85149),
                  tooltip: 'Decrement',
                  onPressed: _decrement,
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.refresh,
                  color: const Color(0xFFd29922),
                  tooltip: 'Reset',
                  onPressed: _reset,
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.add,
                  color: const Color(0xFF3fb950),
                  tooltip: 'Increment',
                  onPressed: _increment,
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              'Steps recorded: ${ttdEngine.totalSteps}',
              style: const TextStyle(
                  color: Color(0xFF8b949e), fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap ⏰ (bottom-right) to open the Time Travel overlay',
              style: TextStyle(color: Color(0xFF8b949e), fontSize: 11),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF0d1117),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
