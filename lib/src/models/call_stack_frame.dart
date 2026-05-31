import 'package:meta/meta.dart';

/// Represents a single frame in the call-stack at the moment a snapshot
/// was captured.
@immutable
class CallStackFrame {
  /// Name of the function / method.
  final String functionName;

  /// Class name, if the function is a method.
  final String? className;

  /// Package or library URI (e.g. `"package:myapp/src/counter.dart"`).
  final String? libraryUri;

  /// File path (relative to package root).
  final String? filePath;

  /// Line number in [filePath].
  final int? lineNumber;

  /// Column number in [filePath].
  final int? columnNumber;

  /// Parameters passed to this frame (serialised to strings for safety).
  final List<String> parameters;

  /// Indicates whether this frame belongs to the package itself or is an
  /// external / SDK frame.
  final bool isExternal;

  const CallStackFrame({
    required this.functionName,
    this.className,
    this.libraryUri,
    this.filePath,
    this.lineNumber,
    this.columnNumber,
    this.parameters = const [],
    this.isExternal = false,
  });

  // ── Derived ──────────────────────────────────────────────────────────────

  /// Fully-qualified name: `"ClassName.functionName"` or just `"functionName"`.
  String get qualifiedName =>
      className != null ? '$className.$functionName' : functionName;

  /// One-liner description used in stack-trace displays.
  String get shortDescription {
    final loc =
        filePath != null ? ' ($filePath${lineNumber != null ? ':$lineNumber' : ''})' : '';
    return '$qualifiedName$loc';
  }

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'functionName': functionName,
        'className': className,
        'libraryUri': libraryUri,
        'filePath': filePath,
        'lineNumber': lineNumber,
        'columnNumber': columnNumber,
        'parameters': parameters,
        'isExternal': isExternal,
      };

  factory CallStackFrame.fromJson(Map<String, dynamic> json) =>
      CallStackFrame(
        functionName: json['functionName'] as String,
        className: json['className'] as String?,
        libraryUri: json['libraryUri'] as String?,
        filePath: json['filePath'] as String?,
        lineNumber: json['lineNumber'] as int?,
        columnNumber: json['columnNumber'] as int?,
        parameters: List<String>.from(json['parameters'] as List? ?? []),
        isExternal: json['isExternal'] as bool? ?? false,
      );

  /// Build a [CallStackFrame] from a Dart [StackTrace] string line.
  ///
  /// Parses lines of the form:
  /// `#0      MyClass.myMethod (package:myapp/src/foo.dart:42:7)`
  static CallStackFrame? tryParseLine(String line) {
    // Example: #3  Foo.bar (package:myapp/lib/foo.dart:12:5)
    final re = RegExp(
        r'#\d+\s+(?:(\w+)\.)?(\w+)\s+\(([^:)]+):?(\d*):?(\d*)\)');
    final m = re.firstMatch(line.trim());
    if (m == null) return null;
    return CallStackFrame(
      className: m.group(1),
      functionName: m.group(2) ?? '<anonymous>',
      filePath: m.group(3),
      lineNumber: int.tryParse(m.group(4) ?? ''),
      columnNumber: int.tryParse(m.group(5) ?? ''),
    );
  }

  @override
  String toString() => shortDescription;
}

/// Utility to capture and convert the current Dart [StackTrace] into
/// a list of [CallStackFrame] objects.
List<CallStackFrame> captureCallStack({int skipFrames = 0}) {
  final trace = StackTrace.current.toString();
  final lines = trace.split('\n');
  return lines
      .skip(skipFrames + 1) // +1 to skip this helper itself
      .map(CallStackFrame.tryParseLine)
      .whereType<CallStackFrame>()
      .toList();
}
