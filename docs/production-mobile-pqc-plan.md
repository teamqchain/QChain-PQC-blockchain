# QChain — Production Mobile PQC Architecture & Flutter Integration Plan
## Device-Side Post-Quantum Key Management & Decryption (QWallet)

**Audience:** Flutter Mobile Developers, Backend Engineers, Security Architects  
**Goal:** Transition QChain from server-assisted testing (B2 test keys) to **true zero-knowledge client-side encryption**, where holder ML-KEM-768 private keys are generated and stored exclusively on the user's mobile device, and all credential decryption occurs locally.

---

## 1. Do We Need Backend Changes Right Now?

**No. The backend is already fully compatible and ready for your mobile implementation.**

The Go backend already provides:
1. **`POST /mobile/registerHolderKey`**: Accepts `{ "emiratesID": "...", "kemPublicKeyHex": "..." }` and registers the device-generated public key into MySQL (`holders.kem_public_key`).
2. **`POST /issueCredential`**: Automatically looks up the holder's `kem_public_key` and seals the off-chain envelope to `"holder:<holderID>"`.
3. **`GET /mobile/getCredentialsByHolder`**: Returns credential records with two key fields:
   - **`"envelope"`**: 🔒 **The raw ML-KEM-768 encrypted JSON string.** (Your target: decrypt this on-device).
   - **`"attributes"`**: ⚠️ **Temporary server-decrypted fallback.** (Keeps the current UI alive during development; will be removed in production).

> [!IMPORTANT]
> **To the Flutter Developer:** Build and test your client-side decryption against the **`"envelope"`** field. Do not rely on `"attributes"`, as `"attributes"` will be removed in production once your on-device decryption is verified.

---

## 2. Target Architecture Overview

```
[ User Smartphone (QWallet Flutter App) ]
   │
   ├── 1. Wallet Setup ────────▶ Generates ML-KEM-768 Key Pair on Device (via liboqs C/FFI)
   │                              • Secret Key ──▶ Saved to iOS Keychain / Android Keystore
   │                              • Public Key ──▶ Sent to POST /mobile/registerHolderKey
   │
   └── 2. Document Fetching ───▶ Calls GET /mobile/getCredentialsByHolder
                                  • Receives Encrypted Envelope JSON
                                  • Decapsulates master secret using Device Private Key
                                  • Unwraps AES-256-GCM data keys (HKDF-SHA3-256)
                                  • Decrypts & displays verified attributes locally
```

---

## 3. Flutter Developer Implementation Guide

### Step 1: Native Post-Quantum C Library (`liboqs`) Integration

To run Post-Quantum Cryptography natively on iOS and Android without server assistance, bind the C library `liboqs` using **Dart FFI** (`dart:ffi`).

#### A. Precompiled Static Libraries
Compile `liboqs` with `SIG_ml_dsa_44` and `KEM_ml_kem_768`:
- **iOS**: Build an Apple `.xcframework` containing `arm64` (device) and `x86_64` (Simulator) slices. Place in `ios/Frameworks/`.
- **Android**: Build NDK `.so` shared libraries for `arm64-v8a`, `armeabi-v7a`, `x86_64`. Place in `android/app/src/main/jniLibs/`.

#### B. Dart FFI Bindings
Expose the two required C functions from `liboqs`:

```dart
// 1. Generate ML-KEM-768 key pair on device
// Returns (publicKeyHex [1184 bytes = 2368 hex chars], privateKeyHex [2400 bytes = 4800 hex chars])
(String publicKeyHex, String privateKeyHex) generateHolderKemKeypair();

// 2. Decapsulate shared secret from ciphertext
// Inputs: kemCtHex (from envelope wraps), privateKeyHex (from device secure storage)
// Returns: sharedSecretHex (32 bytes = 64 hex chars)
String kemDecapsulate(String kemCtHex, String privateKeyHex);
```

---

### Step 2: Hardware-Backed Secure Storage

Holder private keys must **never be stored in plaintext** in `SharedPreferences` or standard files. Use hardware-backed secure storage:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );

  static Future<void> saveHolderPrivateKey(String holderID, String privHex) async {
    await _storage.write(key: 'kem_priv_$holderID', value: privHex);
  }

  static Future<String?> getHolderPrivateKey(String holderID) async {
    return await _storage.read(key: 'kem_priv_$holderID');
  }
}
```

---

### Step 3: Wallet Activation / Key Registration Flow

When a user logs in with their Emirates ID for the first time:

```dart
Future<void> initializeHolderKeys(String emiratesID) async {
  String? existingPriv = await SecureKeyStorage.getHolderPrivateKey(emiratesID);
  
  if (existingPriv == null) {
    // 1. Generate fresh ML-KEM-768 key pair on phone
    final (pubHex, privHex) = generateHolderKemKeypair();
    
    // 2. Save private key in device hardware keystore
    await SecureKeyStorage.saveHolderPrivateKey(emiratesID, privHex);
    
    // 3. Register ONLY the public key with the backend
    final response = await http.post(
      Uri.parse('$kApiBaseUrl/mobile/registerHolderKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'emiratesID': emiratesID,
        'kemPublicKeyHex': pubHex,
      }),
    );
  }
}
```

---

### Step 4: Client-Side Envelope Decryption

When fetching credentials via `GET /mobile/getCredentialsByHolder?emiratesID=...`:

#### Envelope JSON Structure:
```json
{
  "_qc_env": "qchain-env",
  "v": 1,
  "kemAlg": "ML-KEM-768",
  "aeadAlg": "AES-256-GCM",
  "kdf": "HKDF-SHA3-256",
  "credId": "cb3a40d1...",
  "wraps": [
    {
      "recipient": "holder:H-0001",
      "kemCt": "371d901d3d7c..."
    }
  ],
  "fields": [
    {
      "key": "Degree Title",
      "nonce": "4ebd92c1bad249eaf229753e",
      "ct": "d1e57eb86d3b7ba9073181b9a143f541...",
      "wrap": {
        "holder:H-0001": "a66bc5c385f8b220e44008f5c7ca47a2..."
      }
    }
  ]
}
```

#### Decryption Algorithm in Dart:
1. **Find Recipient Wrap**: Find the item in `wraps` where `recipient == "holder:<holderID>"`.
2. **Decapsulate Master Secret**:
   ```dart
   String sharedSecret = kemDecapsulate(wrap.kemCt, devicePrivateKey);
   ```
3. **Decrypt Each Field**:
   For each item in `fields`:
   - Derive the key-wrapping key using HKDF-SHA3-256:
     $$\text{KWK} = \text{HKDF-SHA3-256}(\text{sharedSecret}, \text{"qchain/trackB/v1|" + credId + "|" + field.key})$$
   - Unwrap the 32-byte field data key using AES-256-GCM with a zero nonce ($12 \times 0x00$ bytes):
     $$\text{DataKey} = \text{AES-GCM-Decrypt}(\text{KWK}, \text{zeroNonce}, \text{field.wrap["holder:<holderID>"]})$$
   - Decrypt the attribute value:
     $$\text{PlaintextValue} = \text{AES-GCM-Decrypt}(\text{DataKey}, \text{field.nonce}, \text{field.ct})$$
4. **Display**: Render the decrypted JSON attributes (`Degree Title: BSc Computer Science`, `Grade: Distinction`, etc.) in the QWallet UI.

---

## 4. Summary Table for Developers

| Task | Platform / Location | Tool / Library |
|---|---|---|
| **PQC Keygen & Decapsulation** | iOS & Android Devices | `liboqs` C static library via `dart:ffi` |
| **KDF & Symmetric Decryption** | Dart Runtime | `pointycastle` / `cryptography` Dart package (HKDF-SHA3-256 + AES-GCM) |
| **Private Key Custody** | Smartphone Hardware | iOS Keychain (Secure Enclave) / Android Keystore (TEE) |
| **Public Key Sync** | Network API | `POST /mobile/registerHolderKey` |
| **Backend State** | Cloud VM / Server | Zero-Knowledge (only handles ciphertext and public keys) |
