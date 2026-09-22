import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liboqs/liboqs.dart';
// Hide Signature — collides with liboqs Signature (ML-DSA).
import 'package:pointycastle/export.dart' hide Signature;
import 'package:qwallet_mobileapp/utils/logger.dart';

/// Holder-side PQC helpers. Private keys stay on-device in secure storage.
class CryptoService {
  CryptoService._();

  static const kemAlgorithm = 'ML-KEM-768';
  static const dsaAlgorithm = 'ML-DSA-44';
  static const kemPrivStorageKey = 'kem_priv_key';
  static const dsaPrivStorageKey = 'dsa_priv_key';
  static const kemPubStorageKey = 'kem_pub_key';
  static const dsaPubStorageKey = 'dsa_pub_key';
  static const hkdfInfoPrefix = 'qchain/trackB/v1';
  static const gcmNonceLen = 12;
  static const gcmTagLen = 16;
  static const aesKeyLen = 32;

  /// Max bytes per keychain entry. iOS Keychain silently truncates values
  /// beyond ~2048 bytes. ML-KEM-768 private key is 2400 bytes = 4800 hex chars
  /// = 4800 bytes as UTF-8, which exceeds that limit. We chunk large values
  /// into multiple keychain entries and reassemble on read.
  static const _chunkSize = 1024; // hex chars per chunk (512 bytes)

  // Explicit platform options:
  // - iOS: first_unlock so keys stay readable after app relaunch (default
  //   unlocked can drop items when the device locks).
  // - Android: AES-GCM storage is the package default on v11 (no ESP flag).
  // Critical for large ML-KEM keys: we always chunk + verify after write.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Write a (possibly long) hex string to secure storage, chunked if it
  /// exceeds [_chunkSize]. Keys shorter than the chunk size are stored as-is.
  /// After write, always re-reads and verifies length to catch silent truncation
  /// (especially iOS Simulator Keychain / older Android Keystore limits).
  static Future<void> _secureWrite(String key, String hexValue) async {
    // Clear any previous direct or chunked entries so we never mix layouts.
    await _secureDelete(key);

    if (hexValue.length <= _chunkSize) {
      await _storage.write(key: key, value: hexValue);
    } else {
      // Split into chunks: key_0, key_1, key_2, ...
      final chunkCount = (hexValue.length + _chunkSize - 1) ~/ _chunkSize;
      await _storage.write(key: '${key}_chunks', value: chunkCount.toString());
      for (var i = 0; i < chunkCount; i++) {
        final start = i * _chunkSize;
        final end = start + _chunkSize > hexValue.length
            ? hexValue.length
            : start + _chunkSize;
        await _storage.write(
          key: '${key}_$i',
          value: hexValue.substring(start, end),
        );
      }
    }

    final verified = await _secureRead(key);
    if (verified == null || verified != hexValue) {
      throw StateError(
        'Secure storage failed to persist "$key" intact '
        '(wrote ${hexValue.length} hex chars, read ${verified?.length ?? 0}). '
        'On iOS Simulator, Keychain is unreliable for large values — try a real '
        'device, or clear the app and re-onboard.',
      );
    }
  }

  /// Remove direct + chunked storage for [key].
  static Future<void> _secureDelete(String key) async {
    await _storage.delete(key: key);
    final chunkCountStr = await _storage.read(key: '${key}_chunks');
    final chunkCount = int.tryParse(chunkCountStr ?? '') ?? 0;
    for (var i = 0; i < chunkCount; i++) {
      await _storage.delete(key: '${key}_$i');
    }
    // Also clear a few extra slots in case of a previous corrupt count.
    for (var i = chunkCount; i < chunkCount + 8; i++) {
      await _storage.delete(key: '${key}_$i');
    }
    await _storage.delete(key: '${key}_chunks');
  }

  /// Read a chunked value back. Returns null if the base key doesn't exist.
  static Future<String?> _secureRead(String key) async {
    // Prefer chunked layout when present (source of truth for long keys).
    final chunkCountStr = await _storage.read(key: '${key}_chunks');
    if (chunkCountStr != null) {
      final chunkCount = int.tryParse(chunkCountStr) ?? 0;
      if (chunkCount <= 0) {
        return _storage.read(key: key);
      }
      final buf = StringBuffer();
      for (var i = 0; i < chunkCount; i++) {
        final chunk = await _storage.read(key: '${key}_$i');
        if (chunk == null || chunk.isEmpty) {
          logDebug(
            '[_secureRead] chunk $i missing for key $key — key is corrupt!',
          );
          return null;
        }
        buf.write(chunk);
      }
      return buf.toString();
    }

    // Legacy / short keys stored under the bare name.
    return _storage.read(key: key);
  }

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

  /// Persist private keys in Keychain/Keystore, and public keys so the app
  /// can show them later (Settings → View My Public Key).
  /// Throws if secure storage silently truncates / loses any key material.
  static Future<void> storePrivateKeys({
    required String kemPrivHex,
    required String dsaPrivHex,
    String? kemPubHex,
    String? dsaPubHex,
  }) async {
    // ML-KEM-768 secret key must be exactly 2400 bytes = 4800 hex chars.
    if (kemPrivHex.length != 4800) {
      throw StateError(
        'Refusing to store ML-KEM private key of ${kemPrivHex.length} hex chars '
        '(expected 4800).',
      );
    }
    await _secureWrite(kemPrivStorageKey, kemPrivHex);
    await _secureWrite(dsaPrivStorageKey, dsaPrivHex);
    // Public keys are long enough that iOS Keychain can also truncate them
    // (~2k+ hex chars) — store via the same chunked verified path.
    if (kemPubHex != null && kemPubHex.isNotEmpty) {
      if (kemPubHex.length != 2368) {
        throw StateError(
          'Refusing to store ML-KEM public key of ${kemPubHex.length} hex chars '
          '(expected 2368).',
        );
      }
      await _secureWrite(kemPubStorageKey, kemPubHex);
    }
    if (dsaPubHex != null && dsaPubHex.isNotEmpty) {
      await _secureWrite(dsaPubStorageKey, dsaPubHex);
    }
  }

  static Future<bool> hasLocalPrivateKeys() async {
    final kem = await readKemPrivateKey();
    final dsa = await readDsaPrivateKey();
    return kem != null &&
        kem.isNotEmpty &&
        dsa != null &&
        dsa.isNotEmpty &&
        // Guard against truncated legacy writes (pre-chunking).
        kem.length == 4800;
  }

  static Future<String?> readKemPrivateKey() async {
    return _secureRead(kemPrivStorageKey);
  }

  static Future<String?> readDsaPrivateKey() async {
    return _secureRead(dsaPrivStorageKey);
  }

  static Future<String?> readKemPublicKey() async {
    return _secureRead(kemPubStorageKey);
  }

  /// Extract the ML-KEM-768 public key embedded in a FIPS-203 expanded secret key.
  /// Layout: sk_pke(1152) || ek(1184) || H(ek)(32) || z(32) = 2400 bytes.
  static String? publicKeyFromKemPrivate(String kemPrivHex) {
    if (kemPrivHex.length != 4800) return null;
    // ek starts at byte 1152 → hex offset 2304, length 2368 hex chars.
    return kemPrivHex.substring(2304, 2304 + 2368);
  }

  /// Verify the on-device ML-KEM keypair matches the backend's registered public key.
  /// Returns a diagnostic string describing the match. Call this to debug decrypt failures.
  static Future<String> verifyKemKeyMatch(String backendPubHex) async {
    final devPriv = await readKemPrivateKey();
    var devPub = await readKemPublicKey();
    final embeddedPub =
        (devPriv != null && devPriv.isNotEmpty) ? publicKeyFromKemPrivate(devPriv) : null;

    final buf = StringBuffer();
    buf.writeln('=== ML-KEM Key Match Diagnostic ===');

    if (devPriv == null || devPriv.isEmpty) {
      buf.writeln('FAIL: No ML-KEM private key on this device.');
      buf.writeln('  The app was never onboarded, or keys were lost (reinstall).');
      buf.writeln('  Fix: Re-onboard to generate + register new keys, then re-issue the credential.');
      return buf.toString();
    }

    buf.writeln(
      'Device private key: ${devPriv.length} hex chars = ${devPriv.length ~/ 2} bytes',
    );
    buf.writeln('  (ML-KEM-768 private key expected: 2400 bytes)');

    if (embeddedPub != null) {
      buf.writeln(
        'Embedded pub from priv: ${embeddedPub.substring(0, 16)}…'
        '${embeddedPub.substring(embeddedPub.length - 16)} '
        '(${embeddedPub.length} hex)',
      );
      if (devPub == null || devPub.isEmpty) {
        devPub = embeddedPub;
        buf.writeln('  (using embedded pub — device kem_pub_key not stored)');
      } else if (devPub.toLowerCase() != embeddedPub.toLowerCase()) {
        buf.writeln(
          'FAIL: stored kem_pub_key does NOT match pub embedded in private key. '
          'Secure storage is corrupt — clear app data and re-onboard.',
        );
      }
    }

    if (devPub != null && devPub.isNotEmpty) {
      buf.writeln(
        'Device public key:  ${devPub.length} hex chars = ${devPub.length ~/ 2} bytes',
      );
      final match = devPub.toLowerCase() == backendPubHex.toLowerCase();
      buf.writeln(
        'Backend public key: ${backendPubHex.length} hex chars = ${backendPubHex.length ~/ 2} bytes',
      );
      buf.writeln('MATCH: $match');
      if (!match) {
        buf.writeln('');
        buf.writeln('FAIL: Device public key != Backend registered public key.');
        buf.writeln('  The credential was encrypted to a DIFFERENT public key than');
        buf.writeln('  what is on this device. This happens when:');
        buf.writeln('  - The app was reinstalled (secure storage wiped, new keys generated)');
        buf.writeln('  - A different holder onboarding was done on this device');
        buf.writeln('  - The backend registered keys from a different device/session');
        buf.writeln('  - GENERATE_HOLDER_KEYS on the server overwrote holders.kem_public_key');
        buf.writeln('');
        buf.writeln('  Fix: Either re-onboard (generate new keys + re-issue credential),');
        buf.writeln('  or restore the original private key that matches the backend public key.');
        buf.writeln('');
        buf.writeln(
          '  Device pub (first 32 chars):  ${devPub.substring(0, devPub.length < 32 ? devPub.length : 32)}...',
        );
        buf.writeln(
          '  Backend pub (first 32 chars): ${backendPubHex.substring(0, backendPubHex.length < 32 ? backendPubHex.length : 32)}...',
        );
      }
    } else {
      buf.writeln('Device public key: NOT available');
      buf.writeln(
        '  Backend pub (first 32 chars): ${backendPubHex.substring(0, backendPubHex.length < 32 ? backendPubHex.length : 32)}...',
      );
    }

    return buf.toString();
  }

  static Future<String?> readDsaPublicKey() async {
    return _secureRead(dsaPubStorageKey);
  }

  static Future<({String? kemPubHex, String? dsaPubHex})>
      readAllPublicKeys() async {
    final kem = await readKemPublicKey();
    final dsa = await readDsaPublicKey();
    return (kemPubHex: kem, dsaPubHex: dsa);
  }

  /// Sorted-key JSON with no extra whitespace (matches Go json.Marshal maps).
  static String canonicalJsonEncode(Map<String, dynamic> map) {
    return jsonEncode(_canonicalize(map));
  }

  /// SHA3-256 hex digest of [data] (UTF-8).
  static String sha3Hex(String data) {
    return hexEncode(_sha3_256(utf8.encode(data)));
  }

  static Uint8List _sha3_256(List<int> message) {
    final d = SHA3Digest(256);
    return d.process(Uint8List.fromList(message));
  }

  /// Metadata keys the wallet UI shows, but which are NOT in on-chain FieldHashes.
  /// resolveSession hashes only body attributes sealed at issuance (`req.Info`).
  /// Including these in disclosedFields makes fieldHashesValid fail every time.
  static const presentationMetadataKeys = <String>{
    'credentialType',
    'credentialID',
    'status',
    'issuedBy',
    'holderEID',
    'holderName',
    'issuedAt',
    'expiryDate',
    'issuer',
    'holderId',
    'holderID',
  };

  /// Body attributes only — keys that can match on-chain FieldHashes.
  /// Drops UI metadata and normalizes values for Go `fmt.Sprintf("%v", …)`.
  static Map<String, dynamic> bodyDisclosedFields(
    Map<String, dynamic> attributes, {
    Set<String> hiddenKeys = const {},
  }) {
    final out = <String, dynamic>{};
    attributes.forEach((k, v) {
      if (k.isEmpty) return;
      if (presentationMetadataKeys.contains(k)) return;
      if (hiddenKeys.contains(k)) return;
      out[k] = _normalizeFieldValue(v);
    });
    return out;
  }

  /// Match Go `fmt.Sprintf("%v", v)` for common JSON scalars so
  /// SHA3-256(field + ":" + value) equals issuance FieldHashes.
  static dynamic _normalizeFieldValue(dynamic v) {
    if (v == null) return '';
    if (v is bool || v is String) return v;
    if (v is int) return v;
    if (v is double) {
      // Go %v for whole numbers prints without trailing .0
      if (v == v.roundToDouble() && !v.isNaN && !v.isInfinite) {
        return v.toInt();
      }
      return v;
    }
    if (v is num) return v;
    // Nested maps/lists: keep structure; hash path stringifies via Go %v rarely
    // used for nested attrs in current issuers (flat fields).
    return v;
  }

  /// ML-DSA-44 sign. Matches Go `pqcSign`/`pqcVerify`: message is the
  /// **UTF-8 bytes of the SHA3-256 hex string** (not the raw 32-byte digest).
  /// Same convention as issuer signatures over CredentialHash hex.
  static String signPayload(String payloadHashHex, String dsaPrivHex) {
    init();
    if (!Signature.isSupported(dsaAlgorithm)) {
      throw StateError('$dsaAlgorithm is not supported on this device');
    }
    final sig = Signature.create(dsaAlgorithm);
    try {
      final message = Uint8List.fromList(utf8.encode(payloadHashHex));
      final signature = sig.sign(message, hexDecode(dsaPrivHex));
      return hexEncode(signature);
    } finally {
      sig.dispose();
    }
  }

  /// Build disclosed payload, hash, and sign for Track H presentation.
  ///
  /// Wire shape matches resolveSession:
  /// ```json
  /// { "credentialID", "disclosedFields": { body… }, "timestamp" }
  /// ```
  /// `credentialID` is plain text inside the signed JSON (not per-field hashed).
  /// That binds the presentation to one credential so a signature over shared
  /// field values cannot be applied to a different credentialID.
  ///
  /// Backend verifies:
  /// - payload.credentialID is present and matches the session target
  /// - holderSig = ML-DSA over SHA3-256(this JSON string) as hex UTF-8
  /// - each disclosedFields[k] vs on-chain FieldHashes[k]
  static Future<({String disclosedPayloadJson, String holderSignatureHex})>
      buildSignedDisclosedPayload({
    required String credentialID,
    required Map<String, dynamic> disclosedFields,
  }) async {
    final trimmedCredID = credentialID.trim();
    if (trimmedCredID.isEmpty) {
      throw StateError(
        'credentialID is required in the signed disclosed payload '
        '(binds the presentation to one credential)',
      );
    }

    final dsaPrivHex = await readDsaPrivateKey();
    if (dsaPrivHex == null || dsaPrivHex.isEmpty) {
      throw StateError('ML-DSA private key not found on this device');
    }

    // Strip metadata if a caller still passed mixed maps.
    final bodyOnly = <String, dynamic>{};
    disclosedFields.forEach((k, v) {
      if (presentationMetadataKeys.contains(k)) return;
      bodyOnly[k] = _normalizeFieldValue(v);
    });
    if (bodyOnly.isEmpty) {
      throw StateError(
        'No body attributes to disclose. Decrypt the credential first, '
        'then share at least one field that was hashed at issuance.',
      );
    }

    // Plain credentialID is intentional: public lookup id, cryptographically
    // bound because the holder signs SHA3-256(canonical JSON of this object).
    final disclosedPayload = <String, dynamic>{
      'credentialID': trimmedCredID,
      'disclosedFields': bodyOnly,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final payloadJson = canonicalJsonEncode(disclosedPayload);
    final payloadHash = sha3Hex(payloadJson);
    final holderSignatureHex = signPayload(payloadHash, dsaPrivHex);
    logDebug(
      '[presentation] signed cred=$trimmedCredID '
      'fields=${bodyOnly.keys.toList()} '
      'hash0=${payloadHash.substring(0, 16)}…',
    );
    return (
      disclosedPayloadJson: payloadJson,
      holderSignatureHex: holderSignatureHex,
    );
  }

  /// Parse backend `expiresAt` (Asia/Dubai local, no Z) → UTC DateTime.
  /// Guide: append +04:00 (Dubai has no DST).
  static DateTime? parseExpiresAt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.trim();
    try {
      if (s.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s) ||
          RegExp(r'[+-]\d{4}$').hasMatch(s)) {
        return DateTime.parse(s).toUtc();
      }
      return DateTime.parse('$s+04:00').toUtc();
    } catch (_) {
      return DateTime.tryParse(s)?.toUtc();
    }
  }

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final out = <String, dynamic>{};
      for (final k in keys) {
        out[k] = _canonicalize(value[k]);
      }
      return out;
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }

  /// Accept either a bare envelope map or a wrapper like `{ envelope: {...} }`.
  static Map<String, dynamic> unwrapEnvelopePayload(Map<String, dynamic> body) {
    if (body.containsKey('wraps') && body.containsKey('fields')) {
      return body;
    }
    final nested = body['envelope'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    if (nested is String && nested.trim().isNotEmpty) {
      final decoded = jsonDecode(nested);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    // Some backends put the envelope JSON string in credential_data / data.
    for (final key in const ['credential_data', 'credentialData', 'data']) {
      final v = body[key];
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v is String && v.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
    }
    return body;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Track B/H envelope decrypt — 1:1 mirror of offchain/envelope.go openAttributes
  // and offchain/kem.go {deriveKey, unwrapKey, aesOpen}.
  //
  // Backend seal (encrypt) does:
  //   kemCt, ss = ML-KEM-768.Encap(holderPub)
  //   for each field:
  //     dataKey = random 32B
  //     nonce, ct = AES-256-GCM.Seal(dataKey, randomNonce12, fieldJSON, aad=nil)
  //                 → ct already includes the 16B tag
  //     kwk = HKDF-SHA3-256(ikm=ss, salt=nil→32×0x00, info="qchain/trackB/v1|<credId>|<key>", L=32)
  //     wrap = AES-256-GCM.Seal(kwk, nonce=12×0x00, dataKey, aad=nil)  // 48B = 32+16
  //
  // Backend open (decrypt) does the inverse — this file implements that inverse.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Decrypt a Track B/H envelope locally. Mirrors Go `openAttributes(env, "holder", sk)`.
  static Map<String, dynamic> decryptEnvelope(
    Map<String, dynamic> envelope,
    String kemPrivHex,
  ) {
    init();

    // ── 1. Find holder kemCt  (Go: env.Wraps where Recipient == "holder") ──
    final wraps = envelope['wraps'];
    if (wraps is! List) {
      throw StateError('envelope missing wraps');
    }
    String? kemCtHex;
    for (final w in wraps) {
      if (w is Map && w['recipient']?.toString() == 'holder') {
        kemCtHex = w['kemCt']?.toString();
        break;
      }
    }
    // Fallback: legacy "holder:<id>" recipient if plain "holder" absent.
    if (kemCtHex == null || kemCtHex.isEmpty) {
      for (final w in wraps) {
        if (w is Map) {
          final r = w['recipient']?.toString() ?? '';
          if (r.startsWith('holder')) {
            kemCtHex = w['kemCt']?.toString();
            break;
          }
        }
      }
    }
    if (kemCtHex == null || kemCtHex.isEmpty) {
      throw StateError('envelope has no holder kemCt');
    }

    // ── 2. kemDecap  (Go: kemDecap(kemCt, sec) → ss) ──
    final kemPrivBytes = hexDecode(kemPrivHex);
    if (kemPrivBytes.length != 2400) {
      throw StateError(
        'ML-KEM-768 private key is ${kemPrivBytes.length} bytes, expected 2400',
      );
    }
    final kem = KEM.create(kemAlgorithm);
    late final Uint8List ss;
    try {
      ss = kem.decapsulate(hexDecode(kemCtHex), kemPrivBytes);
    } finally {
      kem.dispose();
    }
    if (ss.length != 32) {
      throw StateError('KEM shared secret is ${ss.length} bytes, expected 32');
    }
    logDebug(
      '[decryptEnvelope] kemDecap ok ss=${hexEncode(ss.sublist(0, 8))}…',
    );

    // ── 3. Per-field open  (Go: deriveKey → unwrapKey → aesOpen) ──
    final credId = envelope['credId']?.toString() ?? '';
    final fields = envelope['fields'];
    if (fields is! List) {
      throw StateError('envelope missing fields');
    }

    final out = <String, dynamic>{};
    for (final field in fields) {
      if (field is! Map) continue;
      final key = field['key']?.toString();
      if (key == null || key.isEmpty) continue;

      // wrap.holder hex  (Go: f.Wrap["holder"])
      final wrapMap = field['wrap'];
      if (wrapMap is! Map) {
        throw StateError('field "$key" missing wrap map');
      }
      final wrapHex = (wrapMap['holder'] ?? wrapMap['org'])?.toString() ?? '';
      if (wrapHex.isEmpty) {
        throw StateError('field "$key" missing holder/org wrap');
      }

      // deriveKey: info = "qchain/trackB/v1|<credId>|<key>"
      final info = '$hkdfInfoPrefix|$credId|$key';
      final kwk = deriveKey(ss, info); // 32 bytes

      // unwrapKey: AES-GCM open with fixed zero nonce
      final dataKey = unwrapKey(kwk, hexDecode(wrapHex)); // 32 bytes

      // aesOpen: AES-GCM open with field.nonce, field.ct (ct already has tag)
      final nonce = hexDecode(field['nonce']?.toString() ?? '');
      final ct = hexDecode(field['ct']?.toString() ?? '');
      final plaintext = aesOpen(dataKey, nonce, ct);

      out[key] = _decodeFieldPlaintext(plaintext);
      logDebug('[decryptEnvelope] field "$key" ok (${plaintext.length}B)');
    }
    return out;
  }

  // ── hex helpers ──────────────────────────────────────────────────────────

  static String hexEncode(List<int> bytes) {
    final out = StringBuffer();
    for (final b in bytes) {
      out.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }

  static Uint8List hexDecode(String hex) {
    var s = hex.trim();
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    if (s.length.isOdd) {
      throw FormatException('odd-length hex string');
    }
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  // ── primitives matching offchain/kem.go ──────────────────────────────────

  /// Go `deriveKey(ss, info)` — HKDF-SHA3-256, salt=nil → 32 zero bytes, L=32.
  /// RFC 5869 Extract+Expand. HMAC block size for SHA3-256 = rate = 136.
  static Uint8List deriveKey(Uint8List ss, String info, {int length = aesKeyLen}) {
    final infoBytes = Uint8List.fromList(utf8.encode(info));
    // Extract: PRK = HMAC-SHA3-256(salt=32×0x00, ikm=ss)
    final prk = _hmacSha3_256(Uint8List(32), ss);
    // Expand: T(1) = HMAC(PRK, info || 0x01); OKM = T(1)[0..L)
    final out = Uint8List(length);
    var t = Uint8List(0);
    var offset = 0;
    var counter = 1;
    while (offset < length) {
      final msg = Uint8List(t.length + infoBytes.length + 1);
      msg.setAll(0, t);
      msg.setAll(t.length, infoBytes);
      msg[msg.length - 1] = counter;
      t = _hmacSha3_256(prk, msg);
      var n = length - offset;
      if (n > t.length) n = t.length;
      out.setRange(offset, offset + n, t.sublist(0, n));
      offset += n;
      counter++;
    }
    return out;
  }

  /// Alias kept for older call sites / tests.
  static Uint8List hkdfSha3(Uint8List ikm, String info, {int length = aesKeyLen}) =>
      deriveKey(ikm, info, length: length);

  /// HMAC-SHA3-256. Block length = SHA3-256 rate = 136 (NOT 64).
  static Uint8List _hmacSha3_256(Uint8List key, Uint8List data) {
    const blockLen = 136;
    final mac = HMac(SHA3Digest(256), blockLen)..init(KeyParameter(key));
    mac.update(data, 0, data.length);
    final out = Uint8List(mac.macSize);
    mac.doFinal(out, 0);
    return out;
  }

  /// Go `unwrapKey(kwk, wrap)` — AES-256-GCM open with fixed 12-byte zero nonce.
  /// [wrapped] layout = ciphertext || tag (Go cipher.AEAD.Seal appends tag).
  static Uint8List unwrapKey(Uint8List kwk, Uint8List wrapped) {
    if (kwk.length != 32) {
      throw StateError('kwk must be 32 bytes, got ${kwk.length}');
    }
    if (wrapped.length < gcmTagLen) {
      throw StateError('wrap too short: ${wrapped.length}');
    }
    return _aes256GcmOpen(kwk, Uint8List(gcmNonceLen), wrapped);
  }

  /// Alias kept for older call sites / tests.
  static Uint8List aesGcmUnwrap(Uint8List key, Uint8List wrapped) =>
      unwrapKey(key, wrapped);

  /// Go `aesOpen(key, nonce, ct)` — AES-256-GCM open, AAD=nil.
  /// [ct] layout = ciphertext || tag.
  static Uint8List aesOpen(Uint8List key, Uint8List nonce, Uint8List ct) {
    if (key.length != 32) {
      throw StateError('AES key must be 32 bytes, got ${key.length}');
    }
    if (nonce.length != gcmNonceLen) {
      throw StateError('nonce must be $gcmNonceLen bytes, got ${nonce.length}');
    }
    if (ct.length < gcmTagLen) {
      throw StateError('ct too short: ${ct.length}');
    }
    return _aes256GcmOpen(key, nonce, ct);
  }

  /// Alias kept for older call sites / tests.
  static Uint8List aesGcmDecrypt(Uint8List key, Uint8List nonce, Uint8List ct) =>
      aesOpen(key, nonce, ct);

  /// AES-256-GCM open via PointyCastle. Input is ciphertext||tag; AAD empty.
  static Uint8List _aes256GcmOpen(
    Uint8List key,
    Uint8List nonce,
    Uint8List ctAndTag,
  ) {
    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false, // decrypt
          AEADParameters(KeyParameter(key), gcmTagLen * 8, nonce, Uint8List(0)),
        );
      return cipher.process(ctAndTag);
    } on InvalidCipherTextException catch (e) {
      throw StateError('AES-GCM authentication failed: $e');
    }
  }

  /// AES-256-GCM seal (for self-tests / round-trip only).
  static Uint8List _aes256GcmSeal(
    Uint8List key,
    Uint8List nonce,
    Uint8List plain,
  ) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // encrypt
        AEADParameters(KeyParameter(key), gcmTagLen * 8, nonce, Uint8List(0)),
      );
    return cipher.process(plain); // ct || tag
  }

  /// Self-test against NIST CAVP + Go KA vectors. Safe to call anytime.
  static void selfTestSymmetricCrypto() {
    // SHA3-256("")
    const sha3Empty =
        'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a';
    if (sha3Hex('') != sha3Empty) {
      throw StateError('SHA3-256 empty mismatch: ${sha3Hex('')}');
    }

    // AES-256-GCM empty PT (NIST gcmEncryptExtIV256 Count 0)
    final k0 = Uint8List(32);
    final n0 = Uint8List(12);
    final emptyTag = _aes256GcmSeal(k0, n0, Uint8List(0));
    const wantEmpty = '530f8afbc74536b9a963b4f1c4cb738b';
    if (hexEncode(emptyTag) != wantEmpty) {
      throw StateError(
        'AES-GCM empty-PT tag mismatch: got ${hexEncode(emptyTag)} want $wantEmpty',
      );
    }
    if (aesOpen(k0, n0, emptyTag).isNotEmpty) {
      throw StateError('AES-GCM empty-PT decrypt produced non-empty PT');
    }

    // AES-256-GCM one-block zero PT (NIST Count 1)
    final one = _aes256GcmSeal(k0, n0, Uint8List(16));
    const wantOne =
        'cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919';
    if (hexEncode(one) != wantOne) {
      throw StateError(
        'AES-GCM one-block mismatch: got ${hexEncode(one)} want $wantOne',
      );
    }

    // Key-wrap round-trip (zero nonce, 32B data key) — Go wrapKey/unwrapKey shape
    final kwk = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final dataKey = Uint8List.fromList(List<int>.filled(32, 0xaa));
    final wrap = _aes256GcmSeal(kwk, Uint8List(12), dataKey);
    if (wrap.length != 48) {
      throw StateError('wrap length ${wrap.length}, expected 48');
    }
    final opened = unwrapKey(kwk, wrap);
    for (var i = 0; i < 32; i++) {
      if (opened[i] != dataKey[i]) {
        throw StateError('unwrapKey round-trip failed at byte $i');
      }
    }

    // HKDF KA — must match Go: hkdf.New(sha3.New256, 32×0x42, nil, info)
    final ikm = Uint8List.fromList(List<int>.filled(32, 0x42));
    final kwk2 = deriveKey(ikm, 'qchain/trackB/v1|test|field');
    const wantKwk =
        'ba4b764a81ad432c9f3faa58684bb6b7e1e79d75fe295e55591adb834c728ff7';
    if (hexEncode(kwk2) != wantKwk) {
      throw StateError(
        'HKDF-SHA3 KA mismatch: got ${hexEncode(kwk2)} want $wantKwk',
      );
    }
  }

  static dynamic _decodeFieldPlaintext(Uint8List bytes) {
    final s = utf8.decode(bytes);
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }
}
