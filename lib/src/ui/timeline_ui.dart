// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors
import 'package:flutter/material.dart';
import '../core/time_travel_engine.dart';

/// A compact timeline scrubber widget.
///
/// Displays the full execution timeline as a horizontal slider plus
/// navigation buttons (first / prev / next / last), a step counter,
/// and bookmark indicators.
class TimelineUI extends StatelessWidget {
  final TimeTravelEngine engine;
  final int currentStep;
  final ValueChanged<int> onStepChanged;

  const TimelineUI({
    required this.engine,
    required this.currentStep,
    required this.onStepChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = engine.totalSteps;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFF161b22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Slider ─────────────────────────────────────────────────
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbSize: const WidgetStatePropertyAll(Size.fromRadius(7)),
              thumbColor: const Color(0xFF58a6ff),
              activeTrackColor: const Color(0xFF58a6ff),
              inactiveTrackColor: const Color(0xFF30363d),
              overlayColor: const Color(0xFF58a6ff).withValues(alpha: 0.2),
            ),
            child: Slider(
              min: 0,
              max: (total - 1).toDouble().clamp(0, double.infinity),
              value: currentStep
                  .toDouble()
                  .clamp(0, (total - 1).toDouble()),
              onChanged: (v) => onStepChanged(v.round()),
            ),
          ),
          // ── Navigation buttons ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Step counter
              Text(
                'Step ${currentStep + 1} / $total',
                style: const TextStyle(
                    color: Color(0xFF8b949e),
                    fontSize: 10,
                    fontFamily: 'monospace'),
              ),
              Row(
                children: [
                  _NavBtn(
                    icon: Icons.first_page,
                    tooltip: 'First',
                    onTap: () => onStepChanged(0),
                  ),
                  _NavBtn(
                    icon: Icons.chevron_left,
                    tooltip: 'Previous',
                    onTap: currentStep > 0
                        ? () => onStepChanged(currentStep - 1)
                        : null,
                  ),
                  _NavBtn(
                    icon: Icons.chevron_right,
                    tooltip: 'Next',
                    onTap: currentStep < total - 1
                        ? () => onStepChanged(currentStep + 1)
                        : null,
                  ),
                  _NavBtn(
                    icon: Icons.last_page,
                    tooltip: 'Last',
                    onTap: () => onStepChanged(total - 1),
                  ),
                ],
              ),
              // Quick jump input
              _StepJumpField(
                  totalSteps: total, onJump: onStepChanged),
            ],
          ),
          // ── Bookmark strip ────────────────────────────────────────
          _BookmarkStrip(engine: engine, onStepChanged: onStepChanged),
        ],
      ),
    );
  }
}

// ── Navigation button ─────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _NavBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 18,
            color: onTap != null
                ? const Color(0xFF58a6ff)
                : const Color(0xFF30363d),
          ),
        ),
      ),
    );
  }
}

// ── Quick step-jump input ─────────────────────────────────────────────────────

class _StepJumpField extends StatefulWidget {
  final int totalSteps;
  final ValueChanged<int> onJump;
  const _StepJumpField(
      {required this.totalSteps, required this.onJump});

  @override
  State<_StepJumpField> createState() => _StepJumpFieldState();
}

class _StepJumpFieldState extends State<_StepJumpField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v != null && v >= 1 && v <= widget.totalSteps) {
      widget.onJump(v - 1);
    }
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(
            color: Color(0xFFc9d1d9),
            fontSize: 10,
            fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: 'Go…',
          hintStyle: const TextStyle(
              color: Color(0xFF8b949e), fontSize: 10),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: Color(0xFF30363d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: Color(0xFF30363d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: Color(0xFF58a6ff)),
          ),
          filled: true,
          fillColor: const Color(0xFF0d1117),
        ),
      ),
    );
  }
}

// ── Bookmark strip ────────────────────────────────────────────────────────────

class _BookmarkStrip extends StatelessWidget {
  final TimeTravelEngine engine;
  final ValueChanged<int> onStepChanged;
  const _BookmarkStrip(
      {required this.engine, required this.onStepChanged});

  @override
  Widget build(BuildContext context) {
    final bookmarks = engine.bookmarks();
    if (bookmarks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: bookmarks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final bm = bookmarks[i];
          return GestureDetector(
            onTap: () => onStepChanged(bm.stepNumber),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF3d2b00),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: const Color(0xFFd29922).withValues(alpha: 0.5)),
              ),
              child: Text(
                '🔖 ${bm.bookmarkLabel ?? 'step ${bm.stepNumber}'}',
                style: const TextStyle(
                    color: Color(0xFFd29922), fontSize: 9),
              ),
            ),
          );
        },
      ),
    );
  }
}
