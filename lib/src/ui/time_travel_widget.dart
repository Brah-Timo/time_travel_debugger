// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors
import 'package:flutter/material.dart';
import '../core/time_travel_engine.dart';
import '../core/state_snapshot.dart';
import 'snapshot_viewer.dart';
import 'timeline_ui.dart';

/// The root Flutter overlay widget for the Time Travel Debugger.
///
/// Wraps your app in a [Stack] and injects a draggable floating panel
/// that surfaces the timeline scrubber, snapshot viewer, and variable
/// inspector.
///
/// ### Minimal usage
/// ```dart
/// void main() {
///   final engine = TimeTravelEngine();
///   runApp(
///     TimeTravelWidget(
///       engine: engine,
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// The overlay is only shown in **debug** mode by default (controlled by
/// [showInRelease]).
class TimeTravelWidget extends StatefulWidget {
  final TimeTravelEngine engine;
  final Widget child;

  /// Whether to show the overlay even in release builds.
  final bool showInRelease;

  /// Initial side of the screen where the panel is anchored.
  final Alignment initialAlignment;

  const TimeTravelWidget({
    required this.engine,
    required this.child,
    this.showInRelease = false,
    this.initialAlignment = Alignment.bottomRight,
  });

  @override
  State<TimeTravelWidget> createState() => _TimeTravelWidgetState();
}

class _TimeTravelWidgetState extends State<TimeTravelWidget>
    with SingleTickerProviderStateMixin {
  bool _panelOpen = false;
  StateSnapshot? _currentSnapshot;
  Offset _offset = const Offset(16, 100);

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
    if (_panelOpen) {
      _currentSnapshot = widget.engine.latestSnapshot();
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _onStepChanged(int step) {
    setState(() {
      _currentSnapshot = widget.engine.jumpTo(step);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bool isDebug = !bool.fromEnvironment('dart.vm.product');
    if (!isDebug && !widget.showInRelease) {
      return widget.child;
    }

    return Material(
      child: Stack(
        children: [
          widget.child,
          // ── Floating FAB ──────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 90,
            child: _TtdFab(
              isOpen: _panelOpen,
              onTap: _togglePanel,
            ),
          ),
          // ── Draggable panel ───────────────────────────────────────────
          if (_panelOpen)
            FadeTransition(
              opacity: _fadeAnimation,
              child: _TtdDraggablePanel(
                initialOffset: _offset,
                onOffsetChanged: (o) => setState(() => _offset = o),
                child: _TtdPanel(
                  engine: widget.engine,
                  snapshot: _currentSnapshot,
                  onStepChanged: _onStepChanged,
                  onClose: _togglePanel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Floating Action Button ────────────────────────────────────────────────────

class _TtdFab extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;
  const _TtdFab({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isOpen
              ? const Color(0xFF58a6ff)
              : const Color(0xFF161b22),
          border: Border.all(
              color: const Color(0xFF58a6ff), width: 1.5),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF58a6ff).withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isOpen ? Icons.close : Icons.history,
          color: isOpen ? Colors.white : const Color(0xFF58a6ff),
          size: 26,
        ),
      ),
    );
  }
}

// ── Draggable container ───────────────────────────────────────────────────────

class _TtdDraggablePanel extends StatefulWidget {
  final Offset initialOffset;
  final ValueChanged<Offset> onOffsetChanged;
  final Widget child;
  const _TtdDraggablePanel({
    required this.initialOffset,
    required this.onOffsetChanged,
    required this.child,
  });

  @override
  State<_TtdDraggablePanel> createState() => _TtdDraggablePanelState();
}

class _TtdDraggablePanelState extends State<_TtdDraggablePanel> {
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          final size = MediaQuery.of(context).size;
          setState(() {
            _offset = Offset(
              (_offset.dx + d.delta.dx).clamp(0, size.width - 340),
              (_offset.dy + d.delta.dy).clamp(0, size.height - 500),
            );
          });
          widget.onOffsetChanged(_offset);
        },
        child: widget.child,
      ),
    );
  }
}

// ── Main panel ────────────────────────────────────────────────────────────────

class _TtdPanel extends StatelessWidget {
  final TimeTravelEngine engine;
  final StateSnapshot? snapshot;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onClose;

  const _TtdPanel({
    required this.engine,
    required this.snapshot,
    required this.onStepChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117),
        border: Border.all(color: const Color(0xFF30363d)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161b22),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF58a6ff), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Time Travel Debugger',
                  style: TextStyle(
                    color: Color(0xFF58a6ff),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _StatsChip(engine: engine),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close,
                      color: Color(0xFF8b949e), size: 18),
                ),
              ],
            ),
          ),
          // ── Timeline scrubber ─────────────────────────────────────────
          TimelineUI(
            engine: engine,
            currentStep: snapshot?.stepNumber ?? 0,
            onStepChanged: onStepChanged,
          ),
          // ── Snapshot viewer ───────────────────────────────────────────
          Expanded(
            child: SnapshotViewer(snapshot: snapshot),
          ),
        ],
      ),
    );
  }
}

// ── Stats chip ────────────────────────────────────────────────────────────────

class _StatsChip extends StatelessWidget {
  final TimeTravelEngine engine;
  const _StatsChip({required this.engine});

  @override
  Widget build(BuildContext context) {
    final s = engine.stats();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF102040),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${s.totalEvents} events',
        style: const TextStyle(
          color: Color(0xFF58a6ff),
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
