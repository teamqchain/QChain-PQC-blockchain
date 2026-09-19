import 'package:flutter/foundation.dart';

void logDebug(String message) {
  if (kDebugMode) {
    print(message);
  }
}

/// Logs a long string in fixed-size chunks.
///
/// Android logcat caps each log entry at ~4078 bytes and VS Code's Debug
/// Console truncates long lines (showing `<…>`), so a single `print()` of a
/// multi-kilobyte value (e.g. a PQC private key) is silently cut. This splits
/// the message into chunks of [chunkSize] characters and prints each one on its
/// own line, labelled with `[chunk i/n]`, so the full value survives transport.
void logDebugLong(String label, String value, {int chunkSize = 200}) {
  if (!kDebugMode) return;
  // Keep chunks small: VS Code Debug Console and Android logcat still
  // clip long lines (often around ~800–1000 visible chars), which used to
  // silently drop hex from ML-KEM key dumps at join boundaries.
  final total = value.length;
  final chunks = total == 0 ? 0 : (total / chunkSize).ceil();
  logDebug('$label ($total chars, $chunks chunks of <=$chunkSize):');
  for (int i = 0; i < chunks; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize).clamp(0, total);
    final piece = value.substring(start, end);
    logDebug('  [chunk ${i + 1}/$chunks len=${piece.length}] $piece');
  }
  // Checksum so re-assembled pastes can be verified complete.
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
