import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liboqs/liboqs.dart';

/// Holder-side PQC helpers. Private keys stay on-device in secure storage.
class CryptoService {
  CryptoService._();

  static const kemAlgorithm = 'ML-KEM-768';
  static const dsaAlgorithm = 'ML-DSA-44';
  static const kemPrivStorageKey = 'kem_priv_key';
  static const dsaPrivStorageKey = 'dsa_priv_key';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    LibOQS.init();
    _initialized = true;
  }

  /// ML-KEM-768 key pair as lowercase hex. Private key must never leave the phone.
  static ({String pubHex, String privHex}) generateKemKeyPair() {
    init();
    if (!KEM.isSupported(kemAlgorithm)) {
      throw StateError('$kemAlgorithm is not supported on this device');
    }
    final kem = KEM.create(kemAlgorithm);
    try {
      final pair = kem.generateKeyPair();
      return (pubHex: hexEncode(pair.publicKey), privHex: hexEncode(pair.secretKey));
    } finally {
      kem.dispose();
    }
  }

  /// ML-DSA-44 key pair as lowercase hex. Private key must never leave the phone.
  static ({String pubHex, String privHex}) generateSigningKeyPair() {
    init();
    if (!Signature.isSupported(dsaAlgorithm)) {
      throw StateError('$dsaAlgorithm is not supported on this device');
    }
    final sig = Signature.create(dsaAlgorithm);
    try {
      final pair = sig.generateKeyPair();
      return (pubHex: hexEncode(pair.publicKey), privHex: hexEncode(pair.secretKey));
    } finally {
      sig.dispose();
    }
  }

  static Future<void> storePrivateKeys({
    required String kemPrivHex,
    required String dsaPrivHex,
  }) async {
    await _storage.write(key: kemPrivStorageKey, value: kemPrivHex);
    await _storage.write(key: dsaPrivStorageKey, value: dsaPrivHex);
  }

  static Future<bool> hasLocalPrivateKeys() async {
    final kem = await _storage.read(key: kemPrivStorageKey);
    final dsa = await _storage.read(key: dsaPrivStorageKey);
    return kem != null && kem.isNotEmpty && dsa != null && dsa.isNotEmpty;
  }

  static String hexEncode(List<int> bytes) {
    final out = StringBuffer();
    for (final b in bytes) {
      out.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }
}
