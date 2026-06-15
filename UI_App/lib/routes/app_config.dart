
// kApiBaseUrl — the QChain backend base URL the app talks to.
//
// It is injected at BUILD time via --dart-define, e.g.
//   flutter build web --dart-define=API_BASE_URL=https://<vm>.<tailnet>.ts.net/api
// The web-gateway Docker image passes this automatically. When no value is
// supplied (a plain `flutter run` during development) it falls back to the
// local backend on port 3000.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

const String userEmiratesID = '784-2004-7654321-1';
