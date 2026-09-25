import 'package:flutter/foundation.dart';

/// Optional external sink (wired to Alice in [main] when Alice is on).
/// Keeps this file free of Alice imports so HTTP client + logger never cycle.
typedef AppLogSink = void Function(
  String message, {
  DiagnosticLevel level,
  Object? error,
  StackTrace? stackTrace,
});

AppLogSink? _externalSink;

/// Install a sink once at boot (Alice). No-op if null.
void setAppLogSink(AppLogSink? sink) => _externalSink = sink;

/// In-memory ring buffer so Dev Config / copy can show logs even if Alice UI
/// is closed. Newest last. Cap keeps release memory bounded.
const int kAppLogMaxEntries = 500;

final List<AppLogEntry> _buffer = <AppLogEntry>[];

/// Snapshot of recent app logs (oldest → newest). Unmodifiable view.
List<AppLogEntry> get appLogEntries =>
    List<AppLogEntry>.unmodifiable(_buffer);

void clearAppLogs() => _buffer.clear();

class AppLogEntry {
  AppLogEntry({
    required this.message,
    required this.timestamp,
    this.level = DiagnosticLevel.info,
    this.error,
    this.stackTrace,
  });

  final String message;
  final DateTime timestamp;
  final DiagnosticLevel level;
  final Object? error;
  final StackTrace? stackTrace;

  String get line {
    final t = timestamp.toIso8601String().substring(11, 23);
    final err = error == null ? '' : ' | error=$error';
    return '[$t] $message$err';
  }
}

void _append(
  String message, {
  DiagnosticLevel level = DiagnosticLevel.info,
  Object? error,
  StackTrace? stackTrace,
}) {
  final entry = AppLogEntry(
    message: message,
    timestamp: DateTime.now(),
    level: level,
    error: error,
    stackTrace: stackTrace,
  );
  _buffer.add(entry);
  while (_buffer.length > kAppLogMaxEntries) {
    _buffer.removeAt(0);
  }

  // Debug console (VS Code / Xcode / logcat when attached in debug).
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
    if (error != null) {
      // ignore: avoid_print
      print('  error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }

  try {
    _externalSink?.call(
      message,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  } catch (_) {
    // Never let logging break the app.
  }
}

/// General app log — **always** buffered (debug + release) so shared IPA/APK
/// can show logs in Alice → Logs tab and in Dev Config → App logs.
void logDebug(String message) {
  _append(message);
}

void logInfo(String message) =>
    _append(message, level: DiagnosticLevel.info);

void logWarning(String message, [Object? error, StackTrace? stackTrace]) {
  _append(
    message,
    level: DiagnosticLevel.warning,
    error: error,
    stackTrace: stackTrace,
  );
}

void logError(String message, [Object? error, StackTrace? stackTrace]) {
  _append(
    message,
    level: DiagnosticLevel.error,
    error: error,
    stackTrace: stackTrace,
  );
}

/// Logs a long string in fixed-size chunks (key dumps, big JSON).
/// Always buffered; still prints chunk-by-chunk in debug so logcat/VS Code
/// do not silently drop multi-KB lines.
void logDebugLong(String label, String value, {int chunkSize = 200}) {
  final total = value.length;
  final chunks = total == 0 ? 0 : (total / chunkSize).ceil();
  logDebug('$label ($total chars, $chunks chunks of <=$chunkSize):');
  for (int i = 0; i < chunks; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize).clamp(0, total);
    final piece = value.substring(start, end);
    logDebug('  [chunk ${i + 1}/$chunks len=${piece.length}] $piece');
  }
  var sum = 0;
  for (final cu in value.codeUnits) {
    sum = (sum + cu) & 0xffffffff;
  }
  logDebug(
    '  [checksum] len=$total sum32=$sum '
    'head8=${total >= 8 ? value.substring(0, 8) : value} '
    'tail8=${total >= 8 ? value.substring(total - 8) : value}',
  );
}
