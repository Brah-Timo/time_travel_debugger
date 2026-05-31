import 'dart:convert';
import 'dart:io';
import '../core/state_snapshot.dart';
import '../models/variable_record.dart';
import '../models/session_metadata.dart';
import '../models/performance_stats.dart';
import '../utils/type_inspector.dart';

/// Output format for [ReportGenerator].
enum ReportFormat { html, json, plainText, markdown }

/// Generates human-readable debug reports from a recorded session.
///
/// ```dart
/// final gen = ReportGenerator(
///   metadata: meta,
///   snapshots: timeline.allSnapshots,
///   records: recorder.allRecords,
///   stats: engine.stats(),
/// );
/// await gen.saveReport('report.html', format: ReportFormat.html);
/// ```
class ReportGenerator {
  final SessionMetadata metadata;
  final List<StateSnapshot> snapshots;
  final List<VariableRecord> records;
  final PerformanceStats stats;

  ReportGenerator({
    required this.metadata,
    required this.snapshots,
    required this.records,
    required this.stats,
  });

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generates a report string in [format].
  String generate({ReportFormat format = ReportFormat.html}) {
    switch (format) {
      case ReportFormat.html:
        return _buildHtml();
      case ReportFormat.json:
        return _buildJson();
      case ReportFormat.plainText:
        return _buildText();
      case ReportFormat.markdown:
        return _buildMarkdown();
    }
  }

  /// Saves the report to [filePath].
  Future<void> saveReport(
    String filePath, {
    ReportFormat format = ReportFormat.html,
  }) async {
    final content = generate(format: format);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, encoding: utf8);
  }

  // ── HTML ──────────────────────────────────────────────────────────────────

  String _buildHtml() {
    final varStats = _collectVariableStats();
    final sb = StringBuffer();

    sb.write('''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Time Travel Debug Report — ${metadata.appName}</title>
<style>
  :root {
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --text: #c9d1d9; --accent: #58a6ff; --green: #3fb950;
    --red: #f85149; --yellow: #d29922; --purple: #bc8cff;
    --font-mono: "JetBrains Mono", "Fira Code", monospace;
    --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text);
         font-family: var(--font-sans); line-height: 1.6; padding: 2rem; }
  h1 { color: var(--accent); font-size: 1.8rem; margin-bottom: 0.3rem; }
  h2 { color: var(--purple); font-size: 1.2rem; margin: 1.5rem 0 0.5rem; }
  h3 { color: var(--yellow); font-size: 1rem; margin: 1rem 0 0.3rem; }
  .badge { display: inline-block; padding: 0.15rem 0.5rem;
           border-radius: 12px; font-size: 0.75rem; font-weight: 600; }
  .badge-green { background: #1a3d2a; color: var(--green); }
  .badge-blue  { background: #102040; color: var(--accent); }
  .badge-red   { background: #3d1a1a; color: var(--red);   }
  .meta-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
               gap: 1rem; margin-top: 1rem; }
  .meta-card { background: var(--surface); border: 1px solid var(--border);
               border-radius: 8px; padding: 1rem; }
  .meta-card .label { font-size: 0.7rem; text-transform: uppercase;
                      letter-spacing: 0.08em; color: #8b949e; margin-bottom: 0.25rem; }
  .meta-card .value { font-family: var(--font-mono); font-size: 1.1rem; color: var(--text); }
  table { width: 100%; border-collapse: collapse; font-size: 0.85rem; margin-top: 0.5rem; }
  th { background: var(--surface); color: var(--accent); text-align: left;
       padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--border); }
  td { padding: 0.4rem 0.75rem; border-bottom: 1px solid var(--border);
       font-family: var(--font-mono); }
  tr:hover td { background: var(--surface); }
  .added   { color: var(--green); }
  .removed { color: var(--red); }
  .modified{ color: var(--yellow); }
  code { background: var(--surface); padding: 0.1rem 0.3rem;
         border-radius: 4px; font-family: var(--font-mono); font-size: 0.85em; }
</style>
</head>
<body>
<h1>🕰 Time Travel Debug Report</h1>
<p>Session: <code>${metadata.sessionId}</code>
   &nbsp;&bull;&nbsp; App: <strong>${metadata.appName}</strong>
   &nbsp;&bull;&nbsp; Generated: <code>${DateTime.now().toIso8601String()}</code>
</p>
<h2>📊 Performance Overview</h2>
<div class="meta-grid">
  ${_metaCard('Total Events', '${stats.totalEvents}')}
  ${_metaCard('Snapshots', '${stats.snapshotsInMemory}')}
  ${_metaCard('Tracked Variables', '${stats.trackedVariables}')}
  ${_metaCard('Avg Record Latency', '${stats.avgRecordingLatencyMicros.toStringAsFixed(1)} µs')}
  ${_metaCard('Session Duration', '${stats.sessionDuration.inSeconds}s')}
  ${_metaCard('Hot Cache', '${(stats.hotCacheBytes / 1024).toStringAsFixed(1)} KB')}
</div>
<h2>📝 Variable Mutation Summary</h2>
<table>
<thead><tr><th>Variable</th><th>Type</th><th>Mutations</th><th>First Value</th><th>Last Value</th></tr></thead>
<tbody>
${varStats.entries.map((e) => _varRow(e.key, e.value)).join('\n')}
</tbody>
</table>
<h2>🔍 Top 50 Recent Mutations</h2>
<table>
<thead><tr><th>#</th><th>Variable</th><th>Before</th><th>After</th><th>File:Line</th><th>Time</th></tr></thead>
<tbody>
${records.reversed.take(50).toList().reversed.mapIndexed((i, r) => _recordRow(i, r)).join('\n')}
</tbody>
</table>
</body>
</html>''');

    return sb.toString();
  }

  String _metaCard(String label, String value) =>
      '<div class="meta-card"><div class="label">$label</div>'
      '<div class="value">$value</div></div>';

  String _varRow(String name, _VarStat s) =>
      '<tr><td>${_esc(name)}</td><td>${_esc(s.typeName)}</td>'
      '<td><span class="badge badge-blue">${s.mutations}</span></td>'
      '<td>${_esc(TypeInspector.displayValue(s.firstValue))}</td>'
      '<td>${_esc(TypeInspector.displayValue(s.lastValue))}</td></tr>';

  String _recordRow(int i, VariableRecord r) =>
      '<tr><td>${i + 1}</td>'
      '<td>${_esc(r.variableName)}</td>'
      '<td class="removed">${_esc(TypeInspector.displayValue(r.oldValue))}</td>'
      '<td class="added">${_esc(TypeInspector.displayValue(r.newValue))}</td>'
      '<td>${_esc(r.sourceFile)}:${r.lineNumber}</td>'
      '<td>${r.timestamp.toIso8601String()}</td></tr>';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── JSON ──────────────────────────────────────────────────────────────────

  String _buildJson() {
    final data = {
      'reportType': 'time_travel_debugger',
      'generatedAt': DateTime.now().toIso8601String(),
      'metadata': metadata.toJson(),
      'stats': stats.toJson(),
      'variableSummary': _collectVariableStats().map(
        (k, v) => MapEntry(k, {
          'mutations': v.mutations,
          'typeName': v.typeName,
          'firstValue': _encodeValue(v.firstValue),
          'lastValue': _encodeValue(v.lastValue),
        }),
      ),
      'recentRecords':
          records.reversed.take(200).map((r) => r.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ── Plain Text ────────────────────────────────────────────────────────────

  String _buildText() {
    final sb = StringBuffer();
    sb.writeln('========================================');
    sb.writeln(' Time Travel Debug Report');
    sb.writeln('========================================');
    sb.writeln('Session  : ${metadata.sessionId}');
    sb.writeln('App      : ${metadata.appName} ${metadata.appVersion}');
    sb.writeln('Platform : ${metadata.platform}');
    sb.writeln('Duration : ${stats.sessionDuration.inSeconds}s');
    sb.writeln('Events   : ${stats.totalEvents}');
    sb.writeln('Variables: ${stats.trackedVariables}');
    sb.writeln('');
    sb.writeln('--- Variable Mutations ---');
    for (final e in _collectVariableStats().entries) {
      sb.writeln('  ${e.key.padRight(30)} × ${e.value.mutations}');
    }
    sb.writeln('');
    sb.writeln('--- Last 20 Records ---');
    for (final r in records.reversed.take(20)) {
      sb.writeln('  ${r.variableName.padRight(20)} '
          '${TypeInspector.displayValue(r.oldValue).padRight(15)} → '
          '${TypeInspector.displayValue(r.newValue).padRight(15)} '
          '@ ${r.sourceFile}:${r.lineNumber}');
    }
    return sb.toString();
  }

  // ── Markdown ──────────────────────────────────────────────────────────────

  String _buildMarkdown() {
    final sb = StringBuffer();
    sb.writeln('# 🕰 Time Travel Debug Report');
    sb.writeln();
    sb.writeln('**Session:** `${metadata.sessionId}`  ');
    sb.writeln('**App:** ${metadata.appName} ${metadata.appVersion}  ');
    sb.writeln('**Platform:** ${metadata.platform}  ');
    sb.writeln('**Generated:** ${DateTime.now().toIso8601String()}');
    sb.writeln();
    sb.writeln('## 📊 Stats');
    sb.writeln('| Metric | Value |');
    sb.writeln('|--------|-------|');
    sb.writeln('| Total Events | ${stats.totalEvents} |');
    sb.writeln('| Tracked Variables | ${stats.trackedVariables} |');
    sb.writeln('| Session Duration | ${stats.sessionDuration.inSeconds}s |');
    sb.writeln(
        '| Avg Latency | ${stats.avgRecordingLatencyMicros.toStringAsFixed(1)} µs |');
    sb.writeln();
    sb.writeln('## 📝 Variable Summary');
    sb.writeln('| Variable | Mutations | Last Value |');
    sb.writeln('|----------|-----------|------------|');
    for (final e in _collectVariableStats().entries) {
      sb.writeln('| `${e.key}` | ${e.value.mutations} | '
          '`${TypeInspector.displayValue(e.value.lastValue)}` |');
    }
    return sb.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, _VarStat> _collectVariableStats() {
    final stats = <String, _VarStat>{};
    for (final r in records) {
      if (!stats.containsKey(r.variableName)) {
        stats[r.variableName] = _VarStat(
          typeName: r.dataType,
          firstValue: r.oldValue,
          lastValue: r.newValue,
        );
      } else {
        final s = stats[r.variableName]!;
        s.mutations += 1;
        s.lastValue = r.newValue;
      }
    }
    return stats;
  }
}

class _VarStat {
  final String typeName;
  final dynamic firstValue;
  dynamic lastValue;
  int mutations = 1;

  _VarStat({
    required this.typeName,
    required this.firstValue,
    required this.lastValue,
  });
}

// ── Utility extension ─────────────────────────────────────────────────────

extension _MapIndexed<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T item) f) sync* {
    var i = 0;
    for (final item in this) {
      yield f(i++, item);
    }
  }
}

dynamic _encodeValue(dynamic v) {
  if (v == null || v is bool || v is num || v is String) return v;
  return v.toString();
}
