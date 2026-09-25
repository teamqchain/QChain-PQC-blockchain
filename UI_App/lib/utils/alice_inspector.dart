import 'dart:convert';

import 'package:alice/alice.dart';
import 'package:alice_http/alice_http_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:qwallet_mobileapp/utils/logger.dart';

/// Always on (debug + release) for free-tier release IPA testing (D5).
///
/// STORE GATE — before any App Store / production build, restore:
///   import 'package:flutter/foundation.dart';
///   bool get aliceEnabled => kDebugMode;
/// Leave `true` only while shipping free-Apple-ID internal IPAs.
bool get aliceEnabled => true;

/// Alice HTTP adapter — records successful request/response pairs.
final AliceHttpAdapter aliceHttpAdapter = AliceHttpAdapter();

/// Alice instance configured for shake-to-open + notifications.
///
/// Alice 1.x moved the old named params (`showNotification`,
/// `showInspectorOnShake`, `darkTheme`) into [AliceConfiguration].
///
/// Open: **shake the device**. Inspector has HTTP calls + a **Logs** tab
/// (fed by [logDebug] / [logError] via [wireAliceLogSink]).
final Alice alice = Alice(
  configuration: AliceConfiguration(
    showNotification: true,
    showInspectorOnShake: true, // shake the device to open the inspector
  ),
)..addAdapter(aliceHttpAdapter);

/// Pipe app logger into Alice → Logs tab (debug + release).
/// Call once from [main] after bindings are ready.
void wireAliceLogSink() {
  if (!aliceEnabled) return;
  setAppLogSink((
    message, {
    DiagnosticLevel level = DiagnosticLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    try {
      alice.addLog(
        AliceLog(
          message: message,
          level: level,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (_) {
      // Never break the caller on inspector failures.
    }
  });
}

/// HTTP client that auto-logs every call through Alice when [aliceEnabled].
///
/// Records **successes and failures** (timeouts, DNS, socket, no INTERNET).
/// When Alice is gated off, this is a plain [http.Client] (no overhead).
http.Client createAliceHttpClient() {
  if (!aliceEnabled) return http.Client();
  return _AliceLoggingClient(http.Client(), aliceHttpAdapter);
}

/// Thin [http.BaseClient] wrapper that pipes every call through Alice +
/// [logDebug]/logError]. Failures no longer disappear into an empty Alice.
class _AliceLoggingClient extends http.BaseClient {
  _AliceLoggingClient(this._inner, this._adapter);

  final http.Client _inner;
  final AliceHttpAdapter _adapter;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Buffer the request body so Alice can display it after the call completes.
    dynamic body;
    if (request is http.Request) {
      body = request.body;
    }

    final started = DateTime.now();
    logDebug('[HTTP] → ${request.method} ${request.url}');

    try {
      final streamed = await _inner.send(request);
      // Materialise the full response so we can feed it to Alice and still
      // return a usable StreamedResponse to the caller.
      final bytes = await streamed.stream.toBytes();
      final response = http.Response.bytes(
        bytes,
        streamed.statusCode,
        request: request,
        headers: streamed.headers,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );

      final ms = DateTime.now().difference(started).inMilliseconds;
      logDebug(
        '[HTTP] ← ${response.statusCode} ${request.method} ${request.url} '
        '(${ms}ms, ${bytes.length}b)',
      );

      try {
        _adapter.onResponse(
          response,
          body: body,
          duration: DateTime.now().difference(started),
        );
      } catch (_) {
        // Never let logging failures break real API traffic.
      }

      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e, st) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      logError(
        '[HTTP] ✗ ${request.method} ${request.url} failed after ${ms}ms',
        e,
        st,
      );
      try {
        _recordFailedCall(request, body, e, st, started);
      } catch (_) {
        // Never let logging failures break real API traffic.
      }
      rethrow;
    }
  }

  /// Record connect/timeout/DNS failures in Alice (status -1 = ERR).
  /// [Alice.addHttpCall] requires non-null request + response.
  void _recordFailedCall(
    http.BaseRequest request,
    dynamic body,
    Object error,
    StackTrace stackTrace,
    DateTime started,
  ) {
    final now = DateTime.now();
    final path = request.url.path.isEmpty ? '/' : request.url.path;
    final httpRequest = AliceHttpRequest()
      ..time = started
      ..headers = Map<String, String>.from(request.headers)
      ..body = body ?? ''
      ..size = body == null ? 0 : utf8.encode(body.toString()).length
      ..contentType = request.headers['Content-Type'] ??
          request.headers['content-type'] ??
          'unknown'
      ..queryParameters = Map<String, dynamic>.from(request.url.queryParameters);

    final httpResponse = AliceHttpResponse()
      ..status = -1
      ..time = now
      ..body = error.toString()
      ..size = 0
      ..headers = <String, String>{};

    final call = AliceHttpCall(request.hashCode)
      ..loading = false
      ..client = 'HttpClient (http package)'
      ..uri = request.url.toString()
      ..method = request.method
      ..endpoint = path
      ..server = request.url.host
      ..secure = request.url.scheme == 'https'
      ..duration = now.difference(started).inMilliseconds
      ..request = httpRequest
      ..response = httpResponse
      ..error = (AliceHttpError()
        ..error = error
        ..stackTrace = stackTrace);

    alice.addHttpCall(call);
  }

  @override
  void close() => _inner.close();
}
