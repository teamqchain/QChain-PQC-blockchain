import 'package:flutter/services.dart';

/// Shared haptic helpers for QWallet (mobile only).
class QHaptics {
  QHaptics._();

  /// Medium impact — used when pull-to-refresh is triggered.
  static Future<void> refresh() => HapticFeedback.mediumImpact();

  /// Medium impact — used when the stack-view card advances.
  static Future<void> cardSwipe() => HapticFeedback.mediumImpact();

  /// Light impact — successful snackbar / positive result.
  static Future<void> success() => HapticFeedback.lightImpact();

  /// Heavy impact — failed snackbar / error result.
  static Future<void> error() => HapticFeedback.heavyImpact();
}
