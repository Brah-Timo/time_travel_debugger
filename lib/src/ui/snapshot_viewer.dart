// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/state_snapshot.dart';
import '../utils/type_inspector.dart';

/// Displays the contents of a single [StateSnapshot] inside the debug panel.
///
/// Shows:
/// - Variables table (name | type | value)
/// - Call-stack list
/// - Changes list (what mutated to produce this snapshot)
class SnapshotViewer extends StatefulWidget {
  final StateSnapshot? snapshot;

  const SnapshotViewer({this.snapshot});

  @override
  State<SnapshotViewer> createState() => _SnapshotViewerState();
}

class _SnapshotViewerState extends State<SnapshotViewer>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot;
    if (snap == null) {
      return const Center(
        child: Text('No snapshot selected.',
            style: TextStyle(color: Color(0xFF8b949e), fontSize: 12)),
      );
    }

    return Column(
      children: [
        // ── Step info bar ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: const Color(0xFF161b22),
          child: Row(
            children: [
              _chip('Step ${snap.stepNumber}', const Color(0xFF3fb950)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  snap.description ?? '',
                  style: const TextStyle(
                      color: Color(0xFF8b949e), fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatTime(snap.timestamp),
                style: const TextStyle(
                    color: Color(0xFF8b949e),
                    fontSize: 10,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        // ── Tabs ──────────────────────────────────────────────────────
        TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF58a6ff),
          unselectedLabelColor: const Color(0xFF8b949e),
          indicatorColor: const Color(0xFF58a6ff),
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Variables (${snap.variables.length})'),
            Tab(text: 'Stack (${snap.callStack.length})'),
            Tab(text: 'Changes (${snap.changes.length})'),
          ],
        ),
        // ── Search box ────────────────────────────────────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            style: const TextStyle(
                color: Color(0xFFc9d1d9),
                fontSize: 11,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Filter…',
              hintStyle:
                  const TextStyle(color: Color(0xFF8b949e), fontSize: 11),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF8b949e), size: 16),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFF30363d)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFF30363d)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFF58a6ff)),
              ),
              filled: true,
              fillColor: const Color(0xFF161b22),
            ),
          ),
        ),
        // ── Tab bodies ────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _VariablesTab(snapshot: snap, filter: _filter),
              _StackTab(snapshot: snap, filter: _filter),
              _ChangesTab(snapshot: snap, filter: _filter),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${(t.millisecond / 10).floor().toString().padLeft(2, '0')}';

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ── Variables tab ─────────────────────────────────────────────────────────────

class _VariablesTab extends StatelessWidget {
  final StateSnapshot snapshot;
  final String filter;
  const _VariablesTab({required this.snapshot, required this.filter});

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.variables.entries
        .where((e) =>
            filter.isEmpty ||
            e.key.toLowerCase().contains(filter) ||
            TypeInspector.displayValue(e.value)
                .toLowerCase()
                .contains(filter))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const Center(
          child: Text('No variables.',
              style: TextStyle(color: Color(0xFF8b949e), fontSize: 12)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return _VarRow(name: e.key, value: e.value);
      },
    );
  }
}

class _VarRow extends StatelessWidget {
  final String name;
  final dynamic value;
  const _VarRow({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final display = TypeInspector.displayValue(value, maxLength: 60);
    final typeName = TypeInspector.typeName(value);

    return InkWell(
      onTap: () => Clipboard.setData(ClipboardData(text: display)),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                name,
                style: const TextStyle(
                    color: Color(0xFF79c0ff),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1a3d2a),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                typeName,
                style: const TextStyle(
                    color: Color(0xFF3fb950),
                    fontSize: 9,
                    fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                display,
                style: const TextStyle(
                    color: Color(0xFFc9d1d9),
                    fontSize: 11,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stack tab ─────────────────────────────────────────────────────────────────

class _StackTab extends StatelessWidget {
  final StateSnapshot snapshot;
  final String filter;
  const _StackTab({required this.snapshot, required this.filter});

  @override
  Widget build(BuildContext context) {
    final frames = snapshot.callStack.reversed
        .where((f) =>
            filter.isEmpty ||
            f.functionName.toLowerCase().contains(filter) ||
            (f.filePath?.toLowerCase().contains(filter) ?? false))
        .toList();

    if (frames.isEmpty) {
      return const Center(
          child: Text('Empty call stack.',
              style: TextStyle(color: Color(0xFF8b949e), fontSize: 12)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: frames.length,
      itemBuilder: (_, i) {
        final f = frames[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(
                '${i.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: Color(0xFF8b949e),
                    fontSize: 10,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  f.shortDescription,
                  style: TextStyle(
                    color: f.isExternal
                        ? const Color(0xFF8b949e)
                        : const Color(0xFFd29922),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Changes tab ───────────────────────────────────────────────────────────────

class _ChangesTab extends StatelessWidget {
  final StateSnapshot snapshot;
  final String filter;
  const _ChangesTab({required this.snapshot, required this.filter});

  @override
  Widget build(BuildContext context) {
    final changes = snapshot.changes
        .where((r) =>
            filter.isEmpty ||
            r.variableName.toLowerCase().contains(filter))
        .toList();

    if (changes.isEmpty) {
      return const Center(
          child: Text('No changes in this step.',
              style: TextStyle(color: Color(0xFF8b949e), fontSize: 12)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: changes.length,
      itemBuilder: (_, i) {
        final r = changes[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_forward,
                  color: Color(0xFF58a6ff), size: 12),
              const SizedBox(width: 6),
              SizedBox(
                width: 90,
                child: Text(
                  r.variableName,
                  style: const TextStyle(
                      color: Color(0xFF79c0ff),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                TypeInspector.displayValue(r.oldValue, maxLength: 25),
                style: const TextStyle(
                    color: Color(0xFFf85149),
                    fontSize: 10,
                    fontFamily: 'monospace'),
              ),
              const Text('  →  ',
                  style: TextStyle(
                      color: Color(0xFF8b949e), fontSize: 10)),
              Expanded(
                child: Text(
                  TypeInspector.displayValue(r.newValue, maxLength: 25),
                  style: const TextStyle(
                      color: Color(0xFF3fb950),
                      fontSize: 10,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
