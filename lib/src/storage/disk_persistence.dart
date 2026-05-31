import 'dart:convert';
import 'dart:io';
import '../core/state_snapshot.dart';
import '../models/session_metadata.dart';
import '../models/variable_record.dart';

/// File format version written into every `.ttd` file header.
const _kFileFormatVersion = '1.0';

/// Extension used for Time Travel Debugger session files.
const kSessionFileExtension = '.ttd';

/// Result returned from [DiskPersistence.loadSession].
class LoadedSession {
  final SessionMetadata metadata;
  final List<StateSnapshot> snapshots;
  final List<VariableRecord> records;
  const LoadedSession({
    required this.metadata,
    required this.snapshots,
    required this.records,
  });
}

/// Handles reading and writing `.ttd` session files to the local filesystem.
///
/// File layout (JSON):
/// ```json
/// {
///   "ttdVersion": "1.0",
///   "metadata": { ... },
///   "snapshots": [ ... ],
///   "records": [ ... ]
/// }
/// ```
///
/// Large sessions are written in streaming mode (line-delimited JSON chunks)
/// when [streamingMode] is enabled, which avoids peak memory spikes.
class DiskPersistence {
  /// Root directory for session files.
  final String sessionDirectory;

  /// Whether to write in streaming (line-delimited) mode.
  final bool streamingMode;

  DiskPersistence({
    required this.sessionDirectory,
    this.streamingMode = false,
  });

  // ── Directory helpers ─────────────────────────────────────────────────────

  /// Ensures [sessionDirectory] exists.
  Future<void> ensureDirectory() async {
    final dir = Directory(sessionDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Returns all `.ttd` files in [sessionDirectory], sorted newest-first.
  Future<List<File>> listSessions() async {
    final dir = Directory(sessionDirectory);
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith(kSessionFileExtension))
        .cast<File>()
        .toList();
    files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Saves [snapshots] and [records] to [filePath].
  ///
  /// If [filePath] is relative it is resolved against [sessionDirectory].
  Future<String> saveSession({
    required String filePath,
    required SessionMetadata metadata,
    required List<StateSnapshot> snapshots,
    required List<VariableRecord> records,
  }) async {
    await ensureDirectory();
    final resolved = _resolve(filePath);
    final file = File(resolved);

    if (streamingMode) {
      await _saveStreaming(
          file: file,
          metadata: metadata,
          snapshots: snapshots,
          records: records);
    } else {
      await _saveBulk(
          file: file,
          metadata: metadata,
          snapshots: snapshots,
          records: records);
    }
    return resolved;
  }

  /// Saves a **single** [StateSnapshot] to its own compact file.
  Future<void> saveSnapshot({
    required String sessionId,
    required StateSnapshot snapshot,
  }) async {
    await ensureDirectory();
    final path = _resolve('$sessionId/${snapshot.stepNumber}.snap');
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(snapshot.toJson()),
      encoding: utf8,
    );
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Loads a session from [filePath].
  Future<LoadedSession> loadSession(String filePath) async {
    final resolved = _resolve(filePath);
    final file = File(resolved);
    if (!await file.exists()) {
      throw ArgumentError('Session file not found: $resolved');
    }

    final raw = await file.readAsString(encoding: utf8);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    _assertFormatVersion(data['ttdVersion'] as String?);

    final metadata = SessionMetadata.fromJson(
        Map<String, dynamic>.from(data['metadata'] as Map));

    final snapshots = (data['snapshots'] as List? ?? [])
        .map((e) =>
            StateSnapshot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final records = (data['records'] as List? ?? [])
        .map((e) =>
            VariableRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return LoadedSession(
        metadata: metadata, snapshots: snapshots, records: records);
  }

  /// Loads a single snapshot file (written by [saveSnapshot]).
  Future<StateSnapshot> loadSnapshot(String snapshotPath) async {
    final file = File(_resolve(snapshotPath));
    final raw = await file.readAsString(encoding: utf8);
    return StateSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteSession(String filePath) async {
    final file = File(_resolve(filePath));
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAllSessions() async {
    final files = await listSessions();
    for (final f in files) {
      await f.delete();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _resolve(String path) {
    if (path.startsWith('/') || path.startsWith(r'\')) return path;
    return '$sessionDirectory/$path';
  }

  Future<void> _saveBulk({
    required File file,
    required SessionMetadata metadata,
    required List<StateSnapshot> snapshots,
    required List<VariableRecord> records,
  }) async {
    final data = {
      'ttdVersion': _kFileFormatVersion,
      'metadata': metadata.toJson(),
      'snapshots': snapshots.map((s) => s.toJson()).toList(),
      'records': records.map((r) => r.toJson()).toList(),
    };
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      encoding: utf8,
    );
  }

  Future<void> _saveStreaming({
    required File file,
    required SessionMetadata metadata,
    required List<StateSnapshot> snapshots,
    required List<VariableRecord> records,
  }) async {
    await file.parent.create(recursive: true);
    final sink = file.openWrite(encoding: utf8);
    sink.writeln(jsonEncode({
      'ttdVersion': _kFileFormatVersion,
      'metadata': metadata.toJson(),
    }));
    for (final s in snapshots) {
      sink.writeln(jsonEncode({'type': 'snapshot', 'data': s.toJson()}));
    }
    for (final r in records) {
      sink.writeln(jsonEncode({'type': 'record', 'data': r.toJson()}));
    }
    await sink.flush();
    await sink.close();
  }

  void _assertFormatVersion(String? version) {
    if (version == null) return; // tolerate missing field in old files
    final major = int.tryParse(version.split('.').first) ?? 1;
    final currentMajor =
        int.tryParse(_kFileFormatVersion.split('.').first) ?? 1;
    if (major > currentMajor) {
      throw UnsupportedError(
          'Session file version $version is newer than the installed '
          'time_travel_debugger ($currentMajor.x). Please upgrade the package.');
    }
  }
}
