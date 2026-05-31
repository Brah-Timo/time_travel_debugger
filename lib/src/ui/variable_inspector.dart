// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/time_travel_engine.dart';
import '../utils/type_inspector.dart';

/// A full-page Flutter widget that shows the complete history of a
/// single variable across all recorded steps.
///
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => VariableInspector(
///     engine: engine,
///     variableName: 'counter',
///   ),
/// ));
/// ```
class VariableInspector extends StatefulWidget {
  final TimeTravelEngine engine;
  final String variableName;

  const VariableInspector({
    required this.engine,
    required this.variableName,
  });

  @override
  State<VariableInspector> createState() => _VariableInspectorState();
}

class _VariableInspectorState extends State<VariableInspector> {
  late List<_HistoryEntry> _entries;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final records = widget.engine.historyOf(widget.variableName);
    _entries = records.map((r) {
      return _HistoryEntry(
        step: r.recordIndex,
        timestamp: r.timestamp,
        oldValue: r.oldValue,
        newValue: r.newValue,
        sourceFile: r.sourceFile,
        line: r.lineNumber,
        description: r.description,
        delta: r.numericDelta,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Inspector: ',
                style: TextStyle(
                    color: Color(0xFF8b949e), fontSize: 14),
              ),
              TextSpan(
                text: widget.variableName,
                style: const TextStyle(
                    color: Color(0xFF79c0ff),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        iconTheme:
            const IconThemeData(color: Color(0xFF58a6ff)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${_entries.length} mutations',
                style: const TextStyle(
                    color: Color(0xFF8b949e), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text(
                'No mutations recorded for this variable.',
                style: TextStyle(color: Color(0xFF8b949e)),
              ),
            )
          : Column(
              children: [
                _SummaryBar(entries: _entries),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFF30363d), height: 1),
                    itemBuilder: (_, i) =>
                        _EntryTile(entry: _entries[i]),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<_HistoryEntry> entries;
  const _SummaryBar({required this.entries});

  @override
  Widget build(BuildContext context) {
    final first = entries.first;
    final last = entries.last;
    final duration = last.timestamp.difference(first.timestamp);

    return Container(
      color: const Color(0xFF161b22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _Stat('First value',
              TypeInspector.displayValue(first.newValue)),
          const SizedBox(width: 24),
          _Stat(
              'Last value', TypeInspector.displayValue(last.newValue)),
          const SizedBox(width: 24),
          _Stat('Lifetime', _formatDuration(duration)),
          const Spacer(),
          _Stat('Mutations', '${entries.length}'),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 1) return '${d.inMilliseconds}ms';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8b949e),
                fontSize: 9,
                letterSpacing: 0.5)),
        Text(value,
            style: const TextStyle(
                color: Color(0xFFc9d1d9),
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Entry tile ────────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final _HistoryEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () => Clipboard.setData(
          ClipboardData(
              text: TypeInspector.displayValue(entry.newValue))),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step badge
            Container(
              width: 50,
              alignment: Alignment.center,
              child: Text(
                '#${entry.step}',
                style: const TextStyle(
                    color: Color(0xFF58a6ff),
                    fontSize: 10,
                    fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        TypeInspector.displayValue(entry.oldValue,
                            maxLength: 30),
                        style: const TextStyle(
                            color: Color(0xFFf85149),
                            fontSize: 12,
                            fontFamily: 'monospace'),
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward,
                            size: 12,
                            color: Color(0xFF8b949e)),
                      ),
                      Text(
                        TypeInspector.displayValue(entry.newValue,
                            maxLength: 30),
                        style: const TextStyle(
                            color: Color(0xFF3fb950),
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600),
                      ),
                      if (entry.delta != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: entry.delta!.startsWith('+')
                                ? const Color(0xFF1a3d2a)
                                : const Color(0xFF3d1a1a),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            entry.delta!,
                            style: TextStyle(
                              color: entry.delta!.startsWith('+')
                                  ? const Color(0xFF3fb950)
                                  : const Color(0xFFf85149),
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.sourceFile}:${entry.line}'
                    '${entry.description != null ? '  —  ${entry.description}' : ''}',
                    style: const TextStyle(
                        color: Color(0xFF8b949e),
                        fontSize: 9,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _HistoryEntry {
  final int step;
  final DateTime timestamp;
  final dynamic oldValue;
  final dynamic newValue;
  final String sourceFile;
  final int line;
  final String? description;
  final String? delta;

  const _HistoryEntry({
    required this.step,
    required this.timestamp,
    required this.oldValue,
    required this.newValue,
    required this.sourceFile,
    required this.line,
    this.description,
    this.delta,
  });
}
