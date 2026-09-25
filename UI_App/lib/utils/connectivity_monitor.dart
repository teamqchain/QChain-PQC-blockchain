import 'dart:async';
import 'dart:io';

import 'package:qwallet_mobileapp/utils/logger.dart';

/// Lightweight online check with no extra packages.
///
/// Uses a DNS lookup of a well-known host. False negatives are possible on
/// captive portals / strict DNS; false positives are rare. Polls on a timer so
/// splash (and other screens) can react when the radio comes back.
class ConnectivityMonitor {
  ConnectivityMonitor._();
  static final ConnectivityMonitor instance = ConnectivityMonitor._();

  static const Duration _probeTimeout = Duration(seconds: 3);
  static const Duration _pollInterval = Duration(seconds: 3);

  final _controller = StreamController<bool>.broadcast();
  bool? _online;
  Timer? _timer;
  int _listeners = 0;
  bool _probing = false;

  /// Last known state; null until the first probe finishes.
  bool? get isOnline => _online;

  /// Emits after every successful probe. Subscribe via [watch].
  Stream<bool> get onStatus => _controller.stream;

  /// Start polling (ref-counted). Returns a stream of online/offline.
  Stream<bool> watch() {
    _listeners++;
    if (_listeners == 1) {
      _timer?.cancel();
      _timer = Timer.periodic(_pollInterval, (_) => probe());
      // Kick immediately so the UI doesn't wait a full interval.
      unawaited(probe());
    }
    return Stream.multi((multi) {
      if (_online != null) multi.add(_online!);
      final sub = _controller.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = () {
        sub.cancel();
        _listeners = (_listeners - 1).clamp(0, 1 << 30);
        if (_listeners == 0) {
          _timer?.cancel();
          _timer = null;
        }
      };
    });
  }

  /// Force a single probe (e.g. pull-to-retry). Safe to call anytime.
  Future<bool> probe() async {
    if (_probing) return _online ?? false;
    _probing = true;
    try {
      final online = await _lookup();
      if (_online != online) {
        logDebug('[net] ${online ? "online" : "offline"}');
      }
      _online = online;
      if (!_controller.isClosed) _controller.add(online);
      return online;
    } finally {
      _probing = false;
    }
  }

  Future<bool> _lookup() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(_probeTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      logDebug('[net] probe error: $e');
      return false;
    }
  }
}
