import 'package:http/http.dart' as http;
import 'package:qportal_webapp/utils/webApp_config.dart';
import 'package:qportal_webapp/utils/logger.dart';

// ─── Exceptions ──────────────────────────────────────────────────────────────
class ConnectionException implements Exception {
  final String message;
  ConnectionException([this.message = 'Unable to connect to the server.']);
  @override
  String toString() => message;
}

class ApiCore {
  static final client = http.Client();

  static bool _isConnected = false;
  static DateTime? _lastHealthCheck;

  // GET /health
  static Future<bool> checkHealth() async {
    logDebug('[ApiCore] checkHealth called');
    try {
      final res = await client
          .get(Uri.parse('$kApiBaseUrl/health'))
          .timeout(const Duration(seconds: 15));
      _isConnected = res.statusCode == 200;
      _lastHealthCheck = DateTime.now();

      if (_isConnected) {
        logDebug('[ApiCore] checkHealth success: API is reachable');
      } else {
        logDebug('[ApiCore] checkHealth failed: HTTP ${res.statusCode}');
      }

      return _isConnected;
    } catch (e) {
      _isConnected = false;
      _lastHealthCheck = DateTime.now();
      logDebug('[ApiCore] checkHealth exception: $e');
      return false;
    }
  }

  static Future<bool> ensureConnection() async {
    final startTime = DateTime.now();
    while (true) {
      if (_lastHealthCheck != null &&
          DateTime.now().difference(_lastHealthCheck!).inSeconds < 10) {
        if (_isConnected) return true;
      } else {
        final ok = await checkHealth();
        if (ok) return true;
      }

      if (DateTime.now().difference(startTime).inSeconds >= 50) {
        return false;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
