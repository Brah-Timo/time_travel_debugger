import 'package:meta/meta.dart';

/// Metadata stored at the top of a persisted session file.
@immutable
class SessionMetadata {
  /// Auto-generated UUID for the session.
  final String sessionId;

  /// Human-readable name (optional, set by developer).
  final String? sessionName;

  /// App name / identifier.
  final String appName;

  /// App version string.
  final String appVersion;

  /// Dart SDK version at the time of recording.
  final String dartVersion;

  /// Platform description (e.g. `"Android 14"`, `"macOS 14.2"`, `"web"`).
  final String platform;

  /// When recording started.
  final DateTime startTime;

  /// When recording stopped (null while still active).
  final DateTime? endTime;

  /// Package version of `time_travel_debugger` that created this file.
  final String packageVersion;

  /// Any additional key-value metadata the developer wants to attach.
  final Map<String, String> extras;

  const SessionMetadata({
    required this.sessionId,
    this.sessionName,
    required this.appName,
    required this.appVersion,
    required this.dartVersion,
    required this.platform,
    required this.startTime,
    this.endTime,
    required this.packageVersion,
    this.extras = const {},
  });

  /// Total recording duration, or null if not yet stopped.
  Duration? get duration =>
      endTime != null ? endTime!.difference(startTime) : null;

  SessionMetadata withEndTime(DateTime end) => SessionMetadata(
        sessionId: sessionId,
        sessionName: sessionName,
        appName: appName,
        appVersion: appVersion,
        dartVersion: dartVersion,
        platform: platform,
        startTime: startTime,
        endTime: end,
        packageVersion: packageVersion,
        extras: extras,
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'sessionName': sessionName,
        'appName': appName,
        'appVersion': appVersion,
        'dartVersion': dartVersion,
        'platform': platform,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'packageVersion': packageVersion,
        'extras': extras,
      };

  factory SessionMetadata.fromJson(Map<String, dynamic> json) =>
      SessionMetadata(
        sessionId: json['sessionId'] as String,
        sessionName: json['sessionName'] as String?,
        appName: json['appName'] as String? ?? 'unknown',
        appVersion: json['appVersion'] as String? ?? '0.0.0',
        dartVersion: json['dartVersion'] as String? ?? 'unknown',
        platform: json['platform'] as String? ?? 'unknown',
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        packageVersion: json['packageVersion'] as String? ?? '1.0.0',
        extras: Map<String, String>.from(json['extras'] as Map? ?? {}),
      );
}
