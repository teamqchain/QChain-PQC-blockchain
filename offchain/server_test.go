package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Test Guide for New Contributors
//
// Run all tests in this module:
//   go test ./...
//
// Run with detailed pass/fail output:
//   go test -v ./...
//
// Run only this file's tests:
//   go test -v -run 'Test(GetEnv|PathHelpers|LoadWalletIdentity|PQCSignVerifyRoundTrip|PQCDecodeFailures|WriteHelpers|DecodeBody|HandlersValidationAndHealth)$'
//
// Run one specific test:
//   go test -v -run TestHandlersValidationAndHealth
//
// Notes:
// - Most tests here are unit/validation tests and do not require Fabric or IPFS.
// - Cryptography tests rely on liboqs being available in the runtime environment.

// TestGetEnv verifies the environment override helper used by runtime config.
// New contributors can read this as: env value wins, otherwise fallback is used.
func TestGetEnv(t *testing.T) {
	const key = "QCHAIN_TEST_ENV_KEY"

	if err := os.Setenv(key, "configured"); err != nil {
		t.Fatalf("setup failed: could not set env var %q: %v", key, err)
	}
	defer os.Unsetenv(key)

	if got := getEnv(key, "fallback"); got != "configured" {
		t.Fatalf("getEnv should return configured value when env var exists. got=%q want=%q", got, "configured")
	}

	if err := os.Unsetenv(key); err != nil {
		t.Fatalf("setup failed: could not unset env var %q: %v", key, err)
	}

	if got := getEnv(key, "fallback"); got != "fallback" {
		t.Fatalf("getEnv should return fallback when env var is missing. got=%q want=%q", got, "fallback")
	}
}

// TestPathHelpers validates how filesystem paths are derived from networkRoot.
// These helpers are critical because most runtime failures come from wrong paths.
func TestPathHelpers(t *testing.T) {
	oldNetworkRoot := networkRoot
	networkRoot = "/tmp/qchain-network"
	defer func() { networkRoot = oldNetworkRoot }()

	if got := mspDir("government"); got != "/tmp/qchain-network/crypto-material/peerOrganizations/government.uae.com" {
		t.Fatalf("mspDir returned unexpected path. likely wrong org-domain mapping. got=%q", got)
	}

	if got := mspDir("customorg"); got != "/tmp/qchain-network/crypto-material/peerOrganizations/customorg.uae.com" {
		t.Fatalf("mspDir fallback domain logic seems broken for unknown org. got=%q", got)
	}

	if got := walletDir("general"); got != "/tmp/qchain-network/wallet/general" {
		t.Fatalf("walletDir returned unexpected path. likely wrong networkRoot usage. got=%q", got)
	}

	if got := connectionProfilePath("government"); got != "/tmp/qchain-network/connection/connection-gov.json" {
		t.Fatalf("connectionProfilePath returned unexpected gov profile path. got=%q", got)
	}

	if got := connectionProfilePath("general"); got != "/tmp/qchain-network/connection/connection-gen.json" {
		t.Fatalf("connectionProfilePath returned unexpected general profile path. got=%q", got)
	}
}

// TestLoadWalletIdentity covers parsing of wallet/<org>/<identity>.id files.
// Each subtest maps to a real-world failure mode seen during gateway setup.
func TestLoadWalletIdentity(t *testing.T) {
	oldNetworkRoot := networkRoot
	tempRoot := t.TempDir()
	networkRoot = tempRoot
	defer func() { networkRoot = oldNetworkRoot }()

	org := "government"
	identityName := "alice"
	idDir := filepath.Join(walletDir(org))
	if err := os.MkdirAll(idDir, 0o755); err != nil {
		t.Fatalf("setup failed: could not create wallet dir: %v", err)
	}

	// Happy path: a complete identity file returns certificate and private key.
	t.Run("success", func(t *testing.T) {
		idPath := filepath.Join(idDir, identityName+".id")
		content := `{"credentials":{"certificate":"CERT","privateKey":"KEY"},"mspId":"GovernmentMSP","type":"X.509","version":1}`
		if err := os.WriteFile(idPath, []byte(content), 0o644); err != nil {
			t.Fatalf("setup failed: could not write wallet identity file: %v", err)
		}

		certPEM, keyPEM, err := loadWalletIdentity(org, identityName)
		if err != nil {
			t.Fatalf("expected valid wallet identity to load; likely parser/path issue: %v", err)
		}
		if string(certPEM) != "CERT" || string(keyPEM) != "KEY" {
			t.Fatalf("wallet identity values mismatch. got cert=%q key=%q", string(certPEM), string(keyPEM))
		}
	})

	// Missing file should surface a clear "not found" style error for operators.
	t.Run("missing file", func(t *testing.T) {
		_, _, err := loadWalletIdentity(org, "missing-user")
		if err == nil {
			t.Fatalf("expected error for missing wallet file; got nil")
		}
		if !strings.Contains(err.Error(), "not found") {
			t.Fatalf("expected missing-file hint in error. got: %v", err)
		}
	})

	// Malformed JSON should fail early with a parse-focused error message.
	t.Run("invalid json", func(t *testing.T) {
		idPath := filepath.Join(idDir, "broken.id")
		if err := os.WriteFile(idPath, []byte("{not-json"), 0o644); err != nil {
			t.Fatalf("setup failed: could not write malformed identity file: %v", err)
		}

		_, _, err := loadWalletIdentity(org, "broken")
		if err == nil {
			t.Fatalf("expected JSON parsing error for malformed wallet file; got nil")
		}
		if !strings.Contains(err.Error(), "parsing wallet .id file") {
			t.Fatalf("error should mention parse failure for easier diagnosis. got: %v", err)
		}
	})

	// Certificate is mandatory for X.509 identity creation.
	t.Run("missing certificate", func(t *testing.T) {
		idPath := filepath.Join(idDir, "nocert.id")
		content := `{"credentials":{"certificate":"","privateKey":"KEY"},"mspId":"GovernmentMSP","type":"X.509","version":1}`
		if err := os.WriteFile(idPath, []byte(content), 0o644); err != nil {
			t.Fatalf("setup failed: could not write missing-cert identity file: %v", err)
		}

		_, _, err := loadWalletIdentity(org, "nocert")
		if err == nil {
			t.Fatalf("expected certificate validation error; got nil")
		}
		if !strings.Contains(err.Error(), "has no certificate") {
			t.Fatalf("error should indicate missing certificate. got: %v", err)
		}
	})

	// Private key is mandatory for request signing.
	t.Run("missing private key", func(t *testing.T) {
		idPath := filepath.Join(idDir, "nokey.id")
		content := `{"credentials":{"certificate":"CERT","privateKey":""},"mspId":"GovernmentMSP","type":"X.509","version":1}`
		if err := os.WriteFile(idPath, []byte(content), 0o644); err != nil {
			t.Fatalf("setup failed: could not write missing-key identity file: %v", err)
		}

		_, _, err := loadWalletIdentity(org, "nokey")
		if err == nil {
			t.Fatalf("expected private key validation error; got nil")
		}
		if !strings.Contains(err.Error(), "has no privateKey") {
			t.Fatalf("error should indicate missing privateKey. got: %v", err)
		}
	})
}

// TestPQCSignVerifyRoundTrip checks the cryptographic flow used by credentials:
// generate key pair -> sign -> verify, plus a tamper check.
func TestPQCSignVerifyRoundTrip(t *testing.T) {
	pub, priv, err := pqcGenKeyPair()
	if err != nil {
		t.Fatalf("PQC key generation failed; likely liboqs runtime or binding issue: %v", err)
	}

	message := "credential-payload"
	sig, err := pqcSign(message, priv)
	if err != nil {
		t.Fatalf("PQC signing failed; private key handling may be broken: %v", err)
	}

	valid, err := pqcVerify(message, sig, pub)
	if err != nil {
		t.Fatalf("PQC verification failed unexpectedly; verify path may be broken: %v", err)
	}
	if !valid {
		t.Fatalf("expected valid signature for original message; got invalid")
	}

	tamperedValid, err := pqcVerify(message+"-tampered", sig, pub)
	if err != nil {
		t.Fatalf("tampered-message verification returned error instead of false: %v", err)
	}
	if tamperedValid {
		t.Fatalf("tampered message incorrectly verified as valid; signature integrity check likely broken")
	}
}

// TestPQCDecodeFailures ensures invalid hex input fails fast with errors
// instead of silently producing incorrect cryptographic behavior.
func TestPQCDecodeFailures(t *testing.T) {
	if _, err := pqcSign("msg", "not-hex"); err == nil {
		t.Fatalf("expected hex decode error for invalid private key input")
	}

	if _, err := pqcVerify("msg", "not-hex", "also-not-hex"); err == nil {
		t.Fatalf("expected hex decode error for invalid signature/public key input")
	}
}

// TestWriteHelpers documents the API response contract used by handlers:
// JSON content type, expected status code, and predictable error envelope.
func TestWriteHelpers(t *testing.T) {
	rr := httptest.NewRecorder()
	writeJSON(rr, http.StatusCreated, map[string]string{"ok": "yes"})

	if rr.Code != http.StatusCreated {
		t.Fatalf("writeJSON should set provided HTTP status. got=%d want=%d", rr.Code, http.StatusCreated)
	}
	if got := rr.Header().Get("Content-Type"); got != "application/json" {
		t.Fatalf("writeJSON should set Content-Type to application/json. got=%q", got)
	}

	var payload map[string]string
	if err := json.Unmarshal(rr.Body.Bytes(), &payload); err != nil {
		t.Fatalf("writeJSON produced invalid JSON body: %v", err)
	}
	if payload["ok"] != "yes" {
		t.Fatalf("writeJSON body mismatch. got=%q want=%q", payload["ok"], "yes")
	}

	rr = httptest.NewRecorder()
	writeError(rr, http.StatusBadRequest, "problem")
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("writeError should preserve provided HTTP status. got=%d want=%d", rr.Code, http.StatusBadRequest)
	}

	var errPayload ErrorResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &errPayload); err != nil {
		t.Fatalf("writeError produced invalid JSON body: %v", err)
	}
	if errPayload.Error != "problem" {
		t.Fatalf("writeError body mismatch. got=%q want=%q", errPayload.Error, "problem")
	}
}

// TestDecodeBody is a focused parser test for request body JSON decoding.
// It confirms good JSON is accepted and malformed JSON is rejected.
func TestDecodeBody(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(`{"org":"government"}`))
	var payload map[string]string
	if err := decodeBody(req, &payload); err != nil {
		t.Fatalf("decodeBody failed on valid JSON; request parser may be broken: %v", err)
	}
	if payload["org"] != "government" {
		t.Fatalf("decodeBody parsed unexpected payload value. got=%q", payload["org"])
	}

	badReq := httptest.NewRequest(http.MethodPost, "/", strings.NewReader("not-json"))
	if err := decodeBody(badReq, &payload); err == nil {
		t.Fatalf("expected decodeBody to fail on malformed JSON")
	}
}

// TestHandlersValidationAndHealth intentionally targets endpoint guard rails
// (input validation and health reporting) without requiring external services
// such as Fabric peers, wallet material, or IPFS.
func TestHandlersValidationAndHealth(t *testing.T) {
	// Table-driven style keeps endpoint validation checks compact and consistent.
	tests := []struct {
		name            string
		handler         http.HandlerFunc
		method          string
		target          string
		body            string
		wantStatus      int
		wantErrorSubstr string
	}{
		{
			name:            "registerHolder invalid json",
			handler:         handleRegisterHolder,
			method:          http.MethodPost,
			target:          "/registerHolder",
			body:            "{",
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "invalid JSON body",
		},
		{
			name:            "registerHolder missing params",
			handler:         handleRegisterHolder,
			method:          http.MethodPost,
			target:          "/registerHolder",
			body:            `{"org":"government"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing parameters",
		},
		{
			name:            "issueCredential missing params",
			handler:         handleIssueCredential,
			method:          http.MethodPost,
			target:          "/issueCredential",
			body:            `{"org":"government","identity":"admin"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing parameters",
		},
		{
			name:            "verifyCredential missing params",
			handler:         handleVerifyCredential,
			method:          http.MethodPost,
			target:          "/verifyCredential",
			body:            `{"org":"government","identity":"admin"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing parameters",
		},
		{
			name:            "revokeCredential missing params",
			handler:         handleRevokeCredential,
			method:          http.MethodPost,
			target:          "/revokeCredential",
			body:            `{"org":"government"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing parameters",
		},
		{
			name:            "setCID missing params",
			handler:         handleSetCID,
			method:          http.MethodPost,
			target:          "/setCID",
			body:            `{"org":"government"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing parameters",
		},
		{
			name:            "getCredentialsByHolder missing query",
			handler:         handleGetCredentialsByHolder,
			method:          http.MethodGet,
			target:          "/getCredentialsByHolder?org=government",
			body:            "",
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing query params",
		},
		{
			name:            "uploadDocument missing params",
			handler:         handleUploadDocument,
			method:          http.MethodPost,
			target:          "/uploadDocument",
			body:            `{"credID":"c1"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing parameters",
		},
	}

	// Each case must return the expected HTTP code and an actionable error hint.
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, tt.target, strings.NewReader(tt.body))
			rr := httptest.NewRecorder()
			tt.handler(rr, req)

			if rr.Code != tt.wantStatus {
				t.Fatalf("%s failed: unexpected HTTP status. got=%d want=%d. response=%s", tt.name, rr.Code, tt.wantStatus, rr.Body.String())
			}

			var er ErrorResponse
			if err := json.Unmarshal(rr.Body.Bytes(), &er); err != nil {
				t.Fatalf("%s failed: response is not valid ErrorResponse JSON: %v. raw=%s", tt.name, err, rr.Body.String())
			}

			if !strings.Contains(er.Error, tt.wantErrorSubstr) {
				t.Fatalf("%s failed: error message missing expected hint. got=%q want-substring=%q", tt.name, er.Error, tt.wantErrorSubstr)
			}
		})
	}

	// Health check is kept independent and simple: service should report status=ok.
	t.Run("health endpoint", func(t *testing.T) {
		mux := http.NewServeMux()
		mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		})

		req := httptest.NewRequest(http.MethodGet, "/health", nil)
		rr := httptest.NewRecorder()
		mux.ServeHTTP(rr, req)

		if rr.Code != http.StatusOK {
			t.Fatalf("health endpoint should return 200. got=%d body=%s", rr.Code, rr.Body.String())
		}

		var body map[string]string
		if err := json.Unmarshal(rr.Body.Bytes(), &body); err != nil {
			t.Fatalf("health endpoint returned malformed JSON: %v", err)
		}
		if body["status"] != "ok" {
			t.Fatalf("health endpoint payload mismatch. got status=%q", body["status"])
		}
	})
}
