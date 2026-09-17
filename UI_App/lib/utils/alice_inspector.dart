import 'package:alice/alice.dart';
import 'package:alice/model/alice_configuration.dart';
import 'package:alice_http/alice_http_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Only active in debug so release builds stay clean.
bool get aliceEnabled => kDebugMode;

/// Alice HTTP adapter — records request/response pairs into the inspector.
final AliceHttpAdapter aliceHttpAdapter = AliceHttpAdapter();

/// Alice instance configured for shake-to-open + notifications.
///
/// Alice 1.x moved the old named params (`showNotification`,
/// `showInspectorOnShake`, `darkTheme`) into [AliceConfiguration].
final Alice alice = Alice(
  configuration: AliceConfiguration(
    showNotification: true,
    showInspectorOnShake: true, // shake the device to open the inspector
  ),
)..addAdapter(aliceHttpAdapter);

/// HTTP client that auto-logs every call through Alice in debug mode.
///
/// In release builds this is a plain [http.Client] (no overhead).
http.Client createAliceHttpClient() {
  if (!aliceEnabled) return http.Client();
  return _AliceLoggingClient(http.Client(), aliceHttpAdapter);
}

/// Thin [http.BaseClient] wrapper that pipes every response through Alice.
class _AliceLoggingClient extends http.BaseClient {
  _AliceLoggingClient(this._inner, this._adapter);

  final http.Client _inner;
  final AliceHttpAdapter _adapter;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Buffer the request body so Alice can display it after the call completes.
    // http.Request exposes `.body`; other request types don't (or shouldn't)
    // be re-read, so we only capture body for plain Request instances.
    dynamic body;
    if (request is http.Request) {
      body = request.body;
    }

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

    // Fire-and-forget into Alice — don't block the caller on inspector work.
    try {
      _adapter.onResponse(response, body: body);
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
  }

  @override
  void close() => _inner.close();
}
