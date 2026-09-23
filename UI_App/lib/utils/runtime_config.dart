import 'package:get/get.dart';
import 'package:qwallet_mobileapp/utils/app_config.dart';

/// In-memory overrides for the build-time defaults in [app_config.dart].
///
/// No override means the hardcoded default. Overrides live for this process
/// only (D6): kill the app and the next cold start is back to defaults.
/// There is no disk persistence and no mid-session reset (D2, D8).
///
/// Dev Config (PR3) writes overrides. Until then, getters return defaults.
class RuntimeConfig extends GetxController {
  static RuntimeConfig get to => Get.find<RuntimeConfig>();

  String? _apiBaseUrlOverride;
  String? _emiratesIDOverride;

  /// Effective backend base. Exactly the override when set, otherwise
  /// [kApiBaseUrl]. Callers append `/endpoint` themselves (D3).
  String get apiBaseUrl {
    final override = _apiBaseUrlOverride;
    if (override == null || override.isEmpty) return kApiBaseUrl;
    return override;
  }

  /// Effective holder. Exactly the override when set, otherwise
  /// [userEmiratesID].
  String get emiratesID {
    final override = _emiratesIDOverride;
    if (override == null || override.isEmpty) return userEmiratesID;
    return override;
  }

  bool get hasApiBaseUrlOverride =>
      _apiBaseUrlOverride != null && _apiBaseUrlOverride!.isNotEmpty;

  bool get hasEmiratesIDOverride =>
      _emiratesIDOverride != null && _emiratesIDOverride!.isNotEmpty;

  /// Trim, and drop a single trailing slash (D3). Empty or value equal to
  /// [kApiBaseUrl] clears the override (build default). Partial save is valid:
  /// URL-only or holder-only leaves the other field untouched.
  void setApiBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _apiBaseUrlOverride = null;
    } else {
      final cleaned = trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
      _apiBaseUrlOverride = cleaned == kApiBaseUrl ? null : cleaned;
    }
    update();
  }

  void setEmiratesID(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == userEmiratesID) {
      _emiratesIDOverride = null;
    } else {
      _emiratesIDOverride = trimmed;
    }
    update();
  }

  /// Drop both overrides. Next read is the build defaults.
  void reset() {
    _apiBaseUrlOverride = null;
    _emiratesIDOverride = null;
    update();
  }
}
