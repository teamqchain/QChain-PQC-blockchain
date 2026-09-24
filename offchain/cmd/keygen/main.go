// keygen generates a single ML-DSA-44 key pair for use as the organisation-level
// signing key in QChain. Run this ONCE on the VM, then copy the output into .env.
//
// It also has holder-side helpers used by tests/e2e_api_test.sh to play the
// wallet without a phone:
//
//	keygen                       issuer ML-DSA-44 key pair (.env lines)
//	keygen kem | dsa             holder ML-KEM-768 / ML-DSA-44 key pair
//	keygen sign <dsa_priv> <p>   ML-DSA-44 signature over SHA3-256(p) as hex
//	keygen decrypt <kem_priv>    decrypt a credential envelope read from stdin
//
// Usage:
//
//	go run offchain/cmd/keygen/main.go
package main

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/open-quantum-safe/liboqs-go/oqs"
	"golang.org/x/crypto/hkdf"
	"golang.org/x/crypto/sha3"
)

func sha3Hex(data string) string {
	digest := sha3.Sum256([]byte(data))
	return hex.EncodeToString(digest[:])
}

// decryptEnvelope opens a credential envelope as the holder. It is written
// independently of the server's envelope.go, mirroring QWallet's
// CryptoService.decryptEnvelope step by step, so the e2e test cross-checks the
// server's sealing against a second implementation.
func decryptEnvelope(envJSON []byte, kemPrivHex string) (map[string]any, error) {
	var env struct {
		KemAlg string `json:"kemAlg"`
		CredID string `json:"credId"`
		Wraps  []struct {
			Recipient string `json:"recipient"`
			KemCt     string `json:"kemCt"`
		} `json:"wraps"`
		Fields []struct {
			Key   string            `json:"key"`
			Nonce string            `json:"nonce"`
			Ct    string            `json:"ct"`
			Wrap  map[string]string `json:"wrap"`
		} `json:"fields"`
	}
	if err := json.Unmarshal(envJSON, &env); err != nil {
		return nil, fmt.Errorf("parse envelope: %w", err)
	}
	var kemCt []byte
	for _, w := range env.Wraps {
		if w.Recipient == "holder" {
			b, err := hex.DecodeString(w.KemCt)
			if err != nil {
				return nil, fmt.Errorf("decode kemCt: %w", err)
			}
			kemCt = b
		}
	}
	if kemCt == nil {
		return nil, fmt.Errorf("envelope has no holder wrap")
	}
	priv, err := hex.DecodeString(kemPrivHex)
	if err != nil {
		return nil, fmt.Errorf("decode KEM private key: %w", err)
	}
	kem := oqs.KeyEncapsulation{}
	defer kem.Clean()
	if err := kem.Init(env.KemAlg, priv); err != nil {
		return nil, fmt.Errorf("init %s: %w", env.KemAlg, err)
	}
	ss, err := kem.DecapSecret(kemCt)
	if err != nil {
		return nil, fmt.Errorf("KEM decapsulate: %w", err)
	}

	gcmFor := func(key []byte) (cipher.AEAD, error) {
		block, err := aes.NewCipher(key)
		if err != nil {
			return nil, err
		}
		return cipher.NewGCM(block)
	}
	out := map[string]any{}
	for _, f := range env.Fields {
		// Key-wrapping key: HKDF-SHA3-256(ss, info="qchain/trackB/v1|<credId>|<key>").
		kwk := make([]byte, 32)
		info := "qchain/trackB/v1|" + env.CredID + "|" + f.Key
		if _, err := io.ReadFull(hkdf.New(sha3.New256, ss, nil, []byte(info)), kwk); err != nil {
			return nil, err
		}
		wrapped, err := hex.DecodeString(f.Wrap["holder"])
		if err != nil {
			return nil, fmt.Errorf("field %q: decode wrap: %w", f.Key, err)
		}
		kwkAEAD, err := gcmFor(kwk)
		if err != nil {
			return nil, err
		}
		dataKey, err := kwkAEAD.Open(nil, make([]byte, 12), wrapped, nil)
		if err != nil {
			return nil, fmt.Errorf("field %q: unwrap data key: %w", f.Key, err)
		}
		nonce, err1 := hex.DecodeString(f.Nonce)
		ct, err2 := hex.DecodeString(f.Ct)
		if err1 != nil || err2 != nil {
			return nil, fmt.Errorf("field %q: bad nonce/ciphertext hex", f.Key)
		}
		dataAEAD, err := gcmFor(dataKey)
		if err != nil {
			return nil, err
		}
		plain, err := dataAEAD.Open(nil, nonce, ct, nil)
		if err != nil {
			return nil, fmt.Errorf("field %q: decrypt: %w", f.Key, err)
		}
		var v any
		if err := json.Unmarshal(plain, &v); err != nil {
			v = string(plain)
		}
		out[f.Key] = v
	}
	return out, nil
}

func main() {
	if len(os.Args) >= 2 {
		cmd := os.Args[1]
		switch cmd {
		case "kem":
			name := "ML-KEM-768"
			probe := oqs.KeyEncapsulation{}
			if err := probe.Init(name, nil); err != nil {
				probe.Clean()
				name = "Kyber768"
			} else {
				probe.Clean()
			}
			kem := oqs.KeyEncapsulation{}
			defer kem.Clean()
			if err := kem.Init(name, nil); err != nil {
				log.Fatalf("init %s: %v", name, err)
			}
			pubKey, err := kem.GenerateKeyPair()
			if err != nil {
				log.Fatalf("generate KEM key pair: %v", err)
			}
			secKey := kem.ExportSecretKey()
			fmt.Printf("KEM_PUBLIC_KEY_HEX=%s\n", hex.EncodeToString(pubKey))
			fmt.Printf("KEM_PRIVATE_KEY_HEX=%s\n", hex.EncodeToString(secKey))
			return

		case "dsa":
			signer := oqs.Signature{}
			defer signer.Clean()
			if err := signer.Init("ML-DSA-44", nil); err != nil {
				log.Fatalf("init ML-DSA-44 signer: %v", err)
			}
			pubKey, err := signer.GenerateKeyPair()
			if err != nil {
				log.Fatalf("generate key pair: %v", err)
			}
			privKey := signer.ExportSecretKey()
			fmt.Printf("DSA_PUBLIC_KEY_HEX=%s\n", hex.EncodeToString(pubKey))
			fmt.Printf("DSA_PRIVATE_KEY_HEX=%s\n", hex.EncodeToString(privKey))
			return

		case "sign":
			if len(os.Args) < 4 {
				log.Fatal("usage: keygen sign <private_key_hex> <payload>")
			}
			privKeyHex := os.Args[2]
			payload := os.Args[3]

			privKeyBytes, err := hex.DecodeString(privKeyHex)
			if err != nil {
				log.Fatalf("decode private key hex: %v", err)
			}
			signer := oqs.Signature{}
			defer signer.Clean()
			if err := signer.Init("ML-DSA-44", privKeyBytes); err != nil {
				log.Fatalf("init signer: %v", err)
			}
			payloadHash := sha3Hex(payload)
			sig, err := signer.Sign([]byte(payloadHash))
			if err != nil {
				log.Fatalf("sign error: %v", err)
			}
			fmt.Println(hex.EncodeToString(sig))
			return

		case "decrypt":
			if len(os.Args) < 3 {
				log.Fatal("usage: keygen decrypt <kem_private_key_hex> < envelope.json")
			}
			envJSON, err := io.ReadAll(os.Stdin)
			if err != nil {
				log.Fatalf("read envelope from stdin: %v", err)
			}
			attrs, err := decryptEnvelope(envJSON, os.Args[2])
			if err != nil {
				log.Fatalf("decrypt: %v", err)
			}
			enc := json.NewEncoder(os.Stdout)
			enc.SetEscapeHTML(false)
			if err := enc.Encode(attrs); err != nil {
				log.Fatalf("encode: %v", err)
			}
			return
		}
	}

	const sigName = "ML-DSA-44"

	signer := oqs.Signature{}
	defer signer.Clean()

	if err := signer.Init(sigName, nil); err != nil {
		log.Fatalf("init ML-DSA-44 signer: %v", err)
	}

	pubKey, err := signer.GenerateKeyPair()
	if err != nil {
		log.Fatalf("generate key pair: %v", err)
	}
	privKey := signer.ExportSecretKey()

	pubHex := hex.EncodeToString(pubKey)
	privHex := hex.EncodeToString(privKey)

	fmt.Println("# ─── ML-DSA-44 Organisation Key Pair ───────────────────────────────────────")
	fmt.Println("# Copy these lines into your .env file. Keep .env in .gitignore — NEVER commit.")
	fmt.Println("#")
	fmt.Printf("ISSUER_PRIVATE_KEY_HEX=%s\n", privHex)
	fmt.Printf("ISSUER_PUBLIC_KEY_HEX=%s\n", pubHex)
	fmt.Println("ISSUER_ORG_ID=GeneralMSP")
	fmt.Println("ISSUER_ORG=general")
	fmt.Println("ISSUER_IDENTITY=issuer1")
	fmt.Println("VERIFIER_ORG=general")
	fmt.Println("VERIFIER_IDENTITY=verifier1")
	fmt.Println("#")
	fmt.Println("# Also set:")
	fmt.Println("# MYSQL_DSN=qchain_user:password@tcp(127.0.0.1:3306)/qchain_db")
	fmt.Println("# NETWORK_ROOT=/path/to/qchain-network")
}
