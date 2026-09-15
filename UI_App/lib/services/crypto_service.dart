import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liboqs/liboqs.dart';

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

  /// Persist private keys in Keychain/Keystore, and public keys so the app
  /// can show them later (Settings → View My Public Key).
  static Future<void> storePrivateKeys({
    required String kemPrivHex,
    required String dsaPrivHex,
    String? kemPubHex,
    String? dsaPubHex,
  }) async {
    await _storage.write(key: kemPrivStorageKey, value: kemPrivHex);
    await _storage.write(key: dsaPrivStorageKey, value: dsaPrivHex);
    if (kemPubHex != null && kemPubHex.isNotEmpty) {
      await _storage.write(key: kemPubStorageKey, value: kemPubHex);
    }
    if (dsaPubHex != null && dsaPubHex.isNotEmpty) {
      await _storage.write(key: dsaPubStorageKey, value: dsaPubHex);
    }
  }

  static Future<bool> hasLocalPrivateKeys() async {
    final kem = await _storage.read(key: kemPrivStorageKey);
    final dsa = await _storage.read(key: dsaPrivStorageKey);
    return kem != null && kem.isNotEmpty && dsa != null && dsa.isNotEmpty;
  }

  static Future<String?> readKemPrivateKey() async {
    return _storage.read(key: kemPrivStorageKey);
  }

  static Future<String?> readDsaPrivateKey() async {
    return _storage.read(key: dsaPrivStorageKey);
  }

  static Future<String?> readKemPublicKey() async {
    return _storage.read(key: kemPubStorageKey);
  }

  static Future<String?> readDsaPublicKey() async {
    return _storage.read(key: dsaPubStorageKey);
  }

  static Future<({String? kemPubHex, String? dsaPubHex})>
      readAllPublicKeys() async {
    final kem = await _storage.read(key: kemPubStorageKey);
    final dsa = await _storage.read(key: dsaPubStorageKey);
    return (kemPubHex: kem, dsaPubHex: dsa);
  }

  /// Decrypt a Track B/H envelope locally. Plaintext stays in memory only.
  static Map<String, dynamic> decryptEnvelope(
    Map<String, dynamic> envelope,
    String kemPrivHex,
  ) {
    init();

    final wraps = envelope['wraps'];
    if (wraps is! List) {
      throw StateError('envelope missing wraps');
    }

    Map? holderWrap;
    for (final w in wraps) {
      if (w is Map && w['recipient'] == 'holder') {
        holderWrap = w;
        break;
      }
    }
    if (holderWrap == null) {
      throw StateError('no holder wrap in envelope');
    }

    final kemCtHex = holderWrap['kemCt']?.toString() ?? '';
    if (kemCtHex.isEmpty) {
      throw StateError('missing holder kemCt');
    }

    final kem = KEM.create(kemAlgorithm);
    late final Uint8List ss;
    try {
      ss = kem.decapsulate(hexDecode(kemCtHex), hexDecode(kemPrivHex));
    } finally {
      kem.dispose();
    }

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

      final wrapMap = field['wrap'];
      if (wrapMap is! Map || wrapMap['holder'] == null) {
        throw StateError('field $key missing holder wrap');
      }

      final kwk = hkdfSha3(ss, '$hkdfInfoPrefix|$credId|$key');
      final dataKey = aesGcmUnwrap(kwk, hexDecode(wrapMap['holder'].toString()));
      final plaintext = aesGcmDecrypt(
        dataKey,
        hexDecode(field['nonce']?.toString() ?? ''),
        hexDecode(field['ct']?.toString() ?? ''),
      );
      out[key] = _decodeFieldPlaintext(plaintext);
    }
    return out;
  }

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

  /// HKDF-SHA3-256 (Extract+Expand). Salt = empty (32 zero bytes) when omitted.
  static Uint8List hkdfSha3(Uint8List ikm, String info, {int length = aesKeyLen}) {
    final salt = Uint8List(32);
    final prk = _hmacSha3(salt, ikm);
    final infoBytes = utf8.encode(info);
    final hashLen = 32;
    final n = (length + hashLen - 1) ~/ hashLen;
    final okm = BytesBuilder(copy: false);
    var prev = Uint8List(0);
    for (var i = 1; i <= n; i++) {
      final input = BytesBuilder(copy: false)
        ..add(prev)
        ..add(infoBytes)
        ..addByte(i);
      prev = _hmacSha3(prk, input.toBytes());
      okm.add(prev);
    }
    return Uint8List.fromList(okm.toBytes().sublist(0, length));
  }

  /// Unwrap AES data key. Layout: nonce(12) || ciphertext || tag(16).
  static Uint8List aesGcmUnwrap(Uint8List key, Uint8List wrapped) {
    if (wrapped.length < gcmNonceLen + gcmTagLen) {
      throw StateError('wrapped key too short');
    }
    final nonce = wrapped.sublist(0, gcmNonceLen);
    final ct = wrapped.sublist(gcmNonceLen);
    return aesGcmDecrypt(key, nonce, ct);
  }

  /// AES-256-GCM decrypt. [ct] is ciphertext || tag(16).
  static Uint8List aesGcmDecrypt(Uint8List key, Uint8List nonce, Uint8List ct) {
    return _Aes256Gcm.decrypt(key, nonce, ct);
  }

  static dynamic _decodeFieldPlaintext(Uint8List bytes) {
    final s = utf8.decode(bytes);
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }

  static Uint8List _hmacSha3(Uint8List key, List<int> data) {
    const block = 136; // SHA3-256 rate
    var k = key;
    if (k.length > block) {
      k = _Sha3Digest.hash(k);
    }
    if (k.length < block) {
      final padded = Uint8List(block);
      padded.setAll(0, k);
      k = padded;
    }
    final oKey = Uint8List(block);
    final iKey = Uint8List(block);
    for (var i = 0; i < block; i++) {
      oKey[i] = k[i] ^ 0x5c;
      iKey[i] = k[i] ^ 0x36;
    }
    final inner = BytesBuilder(copy: false)
      ..add(iKey)
      ..add(data);
    final outer = BytesBuilder(copy: false)
      ..add(oKey)
      ..add(_Sha3Digest.hash(inner.toBytes()));
    return _Sha3Digest.hash(outer.toBytes());
  }
}

// ─── SHA3-256 (Keccak) ────────────────────────────────────────────────────────

class _Sha3Digest {
  static Uint8List hash(List<int> message) {
    final state = List<int>.filled(25, 0);
    final rate = 136;
    final buf = Uint8List(rate);
    var bufPos = 0;

    void absorbBlock() {
      for (var i = 0; i < rate; i += 8) {
        final lane = i ~/ 8;
        state[lane] ^=
            (buf[i] & 0xff) |
            ((buf[i + 1] & 0xff) << 8) |
            ((buf[i + 2] & 0xff) << 16) |
            ((buf[i + 3] & 0xff) << 24) |
            ((buf[i + 4] & 0xff) << 32) |
            ((buf[i + 5] & 0xff) << 40) |
            ((buf[i + 6] & 0xff) << 48) |
            ((buf[i + 7] & 0xff) << 56);
      }
      _keccakF1600(state);
    }

    for (final b in message) {
      buf[bufPos++] = b & 0xff;
      if (bufPos == rate) {
        absorbBlock();
        bufPos = 0;
      }
    }

    // SHA3 padding: domain 0x06, then 10*1
    buf[bufPos++] = 0x06;
    while (bufPos < rate) {
      buf[bufPos++] = 0x00;
    }
    buf[rate - 1] |= 0x80;
    absorbBlock();

    final out = Uint8List(32);
    for (var i = 0; i < 32; i += 8) {
      final v = state[i ~/ 8];
      out[i] = v & 0xff;
      out[i + 1] = (v >> 8) & 0xff;
      out[i + 2] = (v >> 16) & 0xff;
      out[i + 3] = (v >> 24) & 0xff;
      out[i + 4] = (v >> 32) & 0xff;
      out[i + 5] = (v >> 40) & 0xff;
      out[i + 6] = (v >> 48) & 0xff;
      out[i + 7] = (v >> 56) & 0xff;
    }
    return out;
  }
}

void _keccakF1600(List<int> st) {
  const rc = <int>[
    0x0000000000000001,
    0x0000000000008082,
    0x800000000000808a,
    0x8000000080008000,
    0x000000000000808b,
    0x0000000080000001,
    0x8000000080008081,
    0x8000000000008009,
    0x000000000000008a,
    0x0000000000000088,
    0x0000000080008009,
    0x000000008000000a,
    0x000000008000808b,
    0x800000000000008b,
    0x8000000000008089,
    0x8000000000008003,
    0x8000000000008002,
    0x8000000000000080,
    0x000000000000800a,
    0x800000008000000a,
    0x8000000080008081,
    0x8000000000008080,
    0x0000000080000001,
    0x8000000080008008,
  ];
  const rotc = <int>[
    1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14,
    27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44,
  ];
  const piln = <int>[
    10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
    15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1,
  ];

  const mask64 = 0xFFFFFFFFFFFFFFFF;
  int rotl64(int x, int n) {
    x &= mask64;
    return ((x << n) | (x >> (64 - n))) & mask64;
  }

  for (var round = 0; round < 24; round++) {
    final bc = List<int>.filled(5, 0);
    for (var i = 0; i < 5; i++) {
      bc[i] =
          (st[i] ^ st[i + 5] ^ st[i + 10] ^ st[i + 15] ^ st[i + 20]) & mask64;
    }
    for (var i = 0; i < 5; i++) {
      final t = (bc[(i + 4) % 5] ^ rotl64(bc[(i + 1) % 5], 1)) & mask64;
      for (var j = 0; j < 25; j += 5) {
        st[j + i] = (st[j + i] ^ t) & mask64;
      }
    }

    var t = st[1];
    for (var i = 0; i < 24; i++) {
      final j = piln[i];
      final tmp = st[j];
      st[j] = rotl64(t, rotc[i]);
      t = tmp;
    }

    for (var j = 0; j < 25; j += 5) {
      final a0 = st[j];
      final a1 = st[j + 1];
      final a2 = st[j + 2];
      final a3 = st[j + 3];
      final a4 = st[j + 4];
      // chi: x ^ ((~y) & z) with 64-bit complement
      st[j] = (a0 ^ ((a1 ^ mask64) & a2)) & mask64;
      st[j + 1] = (a1 ^ ((a2 ^ mask64) & a3)) & mask64;
      st[j + 2] = (a2 ^ ((a3 ^ mask64) & a4)) & mask64;
      st[j + 3] = (a3 ^ ((a4 ^ mask64) & a0)) & mask64;
      st[j + 4] = (a4 ^ ((a0 ^ mask64) & a1)) & mask64;
    }

    st[0] = (st[0] ^ rc[round]) & mask64;
  }
}

// ─── AES-256-GCM ──────────────────────────────────────────────────────────────

class _Aes256Gcm {
  static const _tagLen = 16;

  static Uint8List decrypt(Uint8List key, Uint8List nonce, Uint8List ctAndTag) {
    if (key.length != 32) {
      throw StateError('AES-256 key must be 32 bytes');
    }
    if (nonce.isEmpty) {
      throw StateError('nonce required');
    }
    if (ctAndTag.length < _tagLen) {
      throw StateError('ciphertext too short');
    }

    final ct = ctAndTag.sublist(0, ctAndTag.length - _tagLen);
    final tag = ctAndTag.sublist(ctAndTag.length - _tagLen);
    final aes = _Aes256(key);
    final h = aes.encryptBlock(Uint8List(16));
    final j0 = _computeJ0(nonce, h);
    final plain = _gctr(aes, _inc32(j0), ct);
    final s = _ghash(h, Uint8List(0), ct);
    final expected = _xor16(aes.encryptBlock(j0), s);
    if (!_constEq(expected, tag)) {
      throw StateError('AES-GCM authentication failed');
    }
    return plain;
  }

  static Uint8List _computeJ0(Uint8List nonce, Uint8List h) {
    if (nonce.length == 12) {
      final j0 = Uint8List(16);
      j0.setRange(0, 12, nonce);
      j0[15] = 1;
      return j0;
    }
    return _ghash(h, nonce, Uint8List(0));
  }

  static Uint8List _inc32(Uint8List counter) {
    final out = Uint8List.fromList(counter);
    for (var i = 15; i >= 12; i--) {
      final v = (out[i] + 1) & 0xff;
      out[i] = v;
      if (v != 0) break;
    }
    return out;
  }

  static Uint8List _gctr(_Aes256 aes, Uint8List icb, Uint8List data) {
    if (data.isEmpty) return Uint8List(0);
    final out = Uint8List(data.length);
    var cb = Uint8List.fromList(icb);
    var offset = 0;
    while (offset < data.length) {
      final block = aes.encryptBlock(cb);
      final n = (data.length - offset).clamp(0, 16);
      for (var i = 0; i < n; i++) {
        out[offset + i] = data[offset + i] ^ block[i];
      }
      offset += n;
      cb = _inc32(cb);
    }
    return out;
  }

  static Uint8List _ghash(Uint8List h, List<int> aad, List<int> ct) {
    var y = Uint8List(16);
    void absorb(List<int> data) {
      var i = 0;
      while (i + 16 <= data.length) {
        for (var j = 0; j < 16; j++) {
          y[j] ^= data[i + j] & 0xff;
        }
        y = _gfMul(y, h);
        i += 16;
      }
      if (i < data.length) {
        final last = Uint8List(16);
        for (var j = 0; i + j < data.length; j++) {
          last[j] = data[i + j] & 0xff;
        }
        for (var j = 0; j < 16; j++) {
          y[j] ^= last[j];
        }
        y = _gfMul(y, h);
      }
    }

    absorb(aad);
    absorb(ct);

    final lenBlock = Uint8List(16);
    final aadBits = aad.length * 8;
    final ctBits = ct.length * 8;
    _writeU64BE(lenBlock, 0, aadBits);
    _writeU64BE(lenBlock, 8, ctBits);
    for (var j = 0; j < 16; j++) {
      y[j] ^= lenBlock[j];
    }
    return _gfMul(y, h);
  }

  static Uint8List _gfMul(Uint8List x, Uint8List y) {
    var v = List<int>.from(y);
    var z = List<int>.filled(16, 0);
    for (var i = 0; i < 128; i++) {
      final bit = (x[i ~/ 8] >> (7 - (i % 8))) & 1;
      if (bit == 1) {
        for (var j = 0; j < 16; j++) {
          z[j] ^= v[j];
        }
      }
      final lsb = v[15] & 1;
      for (var j = 15; j > 0; j--) {
        v[j] = ((v[j] >> 1) | ((v[j - 1] & 1) << 7)) & 0xff;
      }
      v[0] = (v[0] >> 1) & 0xff;
      if (lsb != 0) {
        v[0] ^= 0xe1;
      }
    }
    return Uint8List.fromList(z);
  }

  static Uint8List _xor16(Uint8List a, Uint8List b) {
    final out = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      out[i] = a[i] ^ b[i];
    }
    return out;
  }

  static bool _constEq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static void _writeU64BE(Uint8List out, int offset, int value) {
    // lengths used for GCM len block fit in 32 bits for our field sizes
    out[offset] = 0;
    out[offset + 1] = 0;
    out[offset + 2] = 0;
    out[offset + 3] = 0;
    out[offset + 4] = (value >> 24) & 0xff;
    out[offset + 5] = (value >> 16) & 0xff;
    out[offset + 6] = (value >> 8) & 0xff;
    out[offset + 7] = value & 0xff;
  }
}

class _Aes256 {
  // 15 round keys as 16-byte blocks (AES-256 = 14 rounds + initial)
  final List<Uint8List> _roundKeys;

  _Aes256(Uint8List key) : _roundKeys = _expandKey(key);

  Uint8List encryptBlock(Uint8List input) {
    final s = Uint8List.fromList(input);
    _addRoundKey(s, _roundKeys[0]);
    for (var round = 1; round < 14; round++) {
      _subBytes(s);
      _shiftRows(s);
      _mixColumns(s);
      _addRoundKey(s, _roundKeys[round]);
    }
    _subBytes(s);
    _shiftRows(s);
    _addRoundKey(s, _roundKeys[14]);
    return s;
  }

  static List<Uint8List> _expandKey(Uint8List key) {
    final w = List<int>.filled(60, 0);
    for (var i = 0; i < 8; i++) {
      w[i] = _u32(key, i * 4);
    }
    for (var i = 8; i < 60; i++) {
      var temp = w[i - 1];
      if (i % 8 == 0) {
        temp = _subWord(_rotWord(temp)) ^ (_rcon[i ~/ 8] << 24);
      } else if (i % 8 == 4) {
        temp = _subWord(temp);
      }
      w[i] = (w[i - 8] ^ temp) & 0xffffffff;
    }
    final keys = <Uint8List>[];
    for (var r = 0; r < 15; r++) {
      final block = Uint8List(16);
      for (var c = 0; c < 4; c++) {
        _putU32(block, c * 4, w[r * 4 + c]);
      }
      keys.add(block);
    }
    return keys;
  }

  static void _addRoundKey(Uint8List s, Uint8List rk) {
    for (var i = 0; i < 16; i++) {
      s[i] ^= rk[i];
    }
  }

  static void _subBytes(Uint8List s) {
    for (var i = 0; i < 16; i++) {
      s[i] = _sbox[s[i]];
    }
  }

  static void _shiftRows(Uint8List s) {
    // row 1
    final t1 = s[1];
    s[1] = s[5];
    s[5] = s[9];
    s[9] = s[13];
    s[13] = t1;
    // row 2
    final t2a = s[2];
    final t2b = s[6];
    s[2] = s[10];
    s[6] = s[14];
    s[10] = t2a;
    s[14] = t2b;
    // row 3
    final t3 = s[15];
    s[15] = s[11];
    s[11] = s[7];
    s[7] = s[3];
    s[3] = t3;
  }

  static void _mixColumns(Uint8List s) {
    for (var c = 0; c < 4; c++) {
      final i = c * 4;
      final a0 = s[i];
      final a1 = s[i + 1];
      final a2 = s[i + 2];
      final a3 = s[i + 3];
      s[i] = _xtime(a0) ^ _xtime(a1) ^ a1 ^ a2 ^ a3;
      s[i + 1] = a0 ^ _xtime(a1) ^ _xtime(a2) ^ a2 ^ a3;
      s[i + 2] = a0 ^ a1 ^ _xtime(a2) ^ _xtime(a3) ^ a3;
      s[i + 3] = _xtime(a0) ^ a0 ^ a1 ^ a2 ^ _xtime(a3);
    }
  }

  static int _u32(Uint8List b, int o) =>
      ((b[o] & 0xff) << 24) |
      ((b[o + 1] & 0xff) << 16) |
      ((b[o + 2] & 0xff) << 8) |
      (b[o + 3] & 0xff);

  static void _putU32(Uint8List b, int o, int v) {
    b[o] = (v >> 24) & 0xff;
    b[o + 1] = (v >> 16) & 0xff;
    b[o + 2] = (v >> 8) & 0xff;
    b[o + 3] = v & 0xff;
  }

  static int _rotWord(int w) =>
      (((w << 8) & 0xffffffff) | ((w >> 24) & 0xff)) & 0xffffffff;

  static int _subWord(int w) =>
      (_sbox[(w >> 24) & 0xff] << 24) |
      (_sbox[(w >> 16) & 0xff] << 16) |
      (_sbox[(w >> 8) & 0xff] << 8) |
      _sbox[w & 0xff];

  static int _xtime(int a) {
    a &= 0xff;
    return ((a << 1) ^ (((a >> 7) & 1) * 0x1b)) & 0xff;
  }

  static const _rcon = <int>[
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36,
  ];

  static const _sbox = <int>[
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];
}
