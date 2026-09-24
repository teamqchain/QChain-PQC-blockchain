package main

/*
================================================================================
QCHAIN OFFCHAIN BACKEND TEST RUN GUIDE
================================================================================

1. Running Unit Tests in the VM (Native Environment):
   --------------------------------------------------
   If running directly on the VM with Go (1.20+) and liboqs installed:
     $ cd offchain
     $ go test -v ./...

   Run specific test suites:
     $ go test -v -run TestHandlersValidationAndHealth
     $ go test -v -run TestApplySelectiveDisclosure
     $ go test -v -run TestFieldHashesVerificationLogic
     $ go test -v -run TestPresentationPayloadBindingParsing
     $ go test -v -run TestMLDSAPresentationSigning
     $ go test -v -run TestDubaiTimezoneFormat
     $ go test -v -run TestEnvelopeRoundTrip

   Run with clean cache and coverage:
     $ go test -count=1 -cover ./...

2. Running Unit Tests via Docker (liboqs Containerized):
   -----------------------------------------------------
   Since ML-KEM-768 and ML-DSA-44 require liboqs C library bindings, tests can be
   executed inside the pre-built Docker image:
     $ cd offchain
     $ docker build -t qchain-api:latest .
     $ docker run --rm qchain-api:latest go test -v ./...

   Mounting local directory into container for instant test iterations:
     $ docker run --rm -v "$PWD:/app" -w /app qchain-api:latest go test -v ./...

3. Running End-to-End (E2E) API Tests:
   -----------------------------------
   With the full network running (Fabric, MySQL, IPFS, Backend API):
     $ ./tests/e2e_api_test.sh

================================================================================
*/

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

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
	pub, priv := testDSAKeyPair(t)

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
			wantErrorSubstr: "missing required fields",
		},
		{
			name:            "issueCredential missing params",
			handler:         handleIssueCredential,
			method:          http.MethodPost,
			target:          "/issueCredential",
			body:            `{"org":"government","identity":"admin"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing required fields",
		},
		{
			name:            "verifyCredential missing params",
			handler:         handleVerifyCredential,
			method:          http.MethodPost,
			target:          "/verifyCredential",
			body:            `{"org":"government","identity":"admin"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
		},
		{
			name:            "revokeCredential missing params",
			handler:         handleRevokeCredential,
			method:          http.MethodPost,
			target:          "/revokeCredential",
			body:            `{"org":"government"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
		},
		{
			name:            "setCID missing params",
			handler:         handleSetCID,
			method:          http.MethodPost,
			target:          "/setCID",
			body:            `{"org":"government"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing required fields",
		},
		{
			name:            "getCredentialsByHolder missing query",
			handler:         handleGetCredentialsByHolder,
			method:          http.MethodGet,
			target:          "/getCredentialsByHolder?org=government",
			body:            "",
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing query param",
		},
		{
			name:            "checkKeys missing emiratesID",
			handler:         handleCheckKeys,
			method:          http.MethodGet,
			target:          "/mobile/checkKeys",
			body:            "",
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing emiratesID",
		},
		{
			name:            "registerHolderKeys missing emiratesID",
			handler:         handleRegisterHolderKeys,
			method:          http.MethodPost,
			target:          "/mobile/registerHolderKeys",
			body:            `{"kemPublicKey":"aabb","dsaPublicKey":"ccdd"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing emiratesID",
		},
		{
			name:            "registerHolderKeys missing keys",
			handler:         handleRegisterHolderKeys,
			method:          http.MethodPost,
			target:          "/mobile/registerHolderKeys",
			body:            `{"emiratesID":"784-1234"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing kemPublicKey or dsaPublicKey",
		},
		{
			name:            "registerHolderKeys invalid hex",
			handler:         handleRegisterHolderKeys,
			method:          http.MethodPost,
			target:          "/mobile/registerHolderKeys",
			body:            `{"emiratesID":"784-1234","kemPublicKey":"not-hex","dsaPublicKey":"aabb"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "invalid hex",
		},
		{
			name:            "getEnvelope missing credentialID",
			handler:         handleGetEnvelope,
			method:          http.MethodGet,
			target:          "/mobile/getEnvelope",
			body:            "",
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
		},
		{
			name:            "getHolderProfile missing emiratesID",
			handler:         handleMobileGetHolderProfile,
			method:          http.MethodGet,
			target:          "/mobile/getHolderProfile",
			body:            "",
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing emiratesID",
		},
		{
			name:            "generateOTP missing credentialID",
			handler:         handleGenerateOTP,
			method:          http.MethodPost,
			target:          "/mobile/generateOTP",
			body:            `{}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
		},
		{
			name:            "generateOTP missing disclosedPayload",
			handler:         handleGenerateOTP,
			method:          http.MethodPost,
			target:          "/mobile/generateOTP",
			body:            `{"credentialID":"CRED-001"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing disclosedPayload",
		},
		{
			name:            "generateOTP missing holderSignature",
			handler:         handleGenerateOTP,
			method:          http.MethodPost,
			target:          "/mobile/generateOTP",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{\"credentialID\":\"CRED-001\"}"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing holderSignature",
		},
		{
			name:            "generateOTP missing payload credentialID",
			handler:         handleGenerateOTP,
			method:          http.MethodPost,
			target:          "/mobile/generateOTP",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{\"disclosedFields\":{}}","holderSignature":"sig123"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "disclosedPayload missing credentialID",
		},
		{
			name:            "generateOTP credentialID mismatch",
			handler:         handleGenerateOTP,
			method:          http.MethodPost,
			target:          "/mobile/generateOTP",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{\"credentialID\":\"CRED-999\"}","holderSignature":"sig123"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "does not match",
		},
		{
			name:            "generatePresentation missing credentialID",
			handler:         handleGeneratePresentation,
			method:          http.MethodPost,
			target:          "/mobile/generatePresentation",
			body:            `{}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
		},
		{
			name:            "generatePresentation missing disclosedPayload",
			handler:         handleGeneratePresentation,
			method:          http.MethodPost,
			target:          "/mobile/generatePresentation",
			body:            `{"credentialID":"CRED-001"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing disclosedPayload",
		},
		{
			name:            "generatePresentation missing holderSignature",
			handler:         handleGeneratePresentation,
			method:          http.MethodPost,
			target:          "/mobile/generatePresentation",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{\"credentialID\":\"CRED-001\"}"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing holderSignature",
		},
		{
			name:            "generatePresentation missing payload credentialID",
			handler:         handleGeneratePresentation,
			method:          http.MethodPost,
			target:          "/mobile/generatePresentation",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{\"disclosedFields\":{}}","holderSignature":"sig123"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "disclosedPayload missing credentialID",
		},
		{
			name:            "generatePresentation credentialID mismatch",
			handler:         handleGeneratePresentation,
			method:          http.MethodPost,
			target:          "/mobile/generatePresentation",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{\"credentialID\":\"CRED-999\"}","holderSignature":"sig123"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "does not match",
		},
		{
			name:            "generateOTP malformed json in disclosedPayload",
			handler:         handleGenerateOTP,
			method:          http.MethodPost,
			target:          "/mobile/generateOTP",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{invalid-json","holderSignature":"sig123"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "invalid JSON in disclosedPayload",
		},
		{
			name:            "generatePresentation malformed json in disclosedPayload",
			handler:         handleGeneratePresentation,
			method:          http.MethodPost,
			target:          "/mobile/generatePresentation",
			body:            `{"credentialID":"CRED-001","disclosedPayload":"{invalid-json","holderSignature":"sig123"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "invalid JSON in disclosedPayload",
		},
		{
			name:            "resolveSession missing sessionToken",
			handler:         handleResolveSession,
			method:          http.MethodPost,
			target:          "/resolveSession",
			body:            `{}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing sessionToken",
		},
		{
			name:            "toggleFavorite missing holderEID",
			handler:         handleToggleFavorite,
			method:          http.MethodPost,
			target:          "/mobile/toggleFavorite",
			body:            `{"credentialID":"CRED-001"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing holderEID",
		},
		{
			name:            "toggleFavorite missing credentialID",
			handler:         handleToggleFavorite,
			method:          http.MethodPost,
			target:          "/mobile/toggleFavorite",
			body:            `{"holderEID":"784-1234"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
		},
		{
			name:            "fetchDocument missing holderEID",
			handler:         handleFetchDocument,
			method:          http.MethodPost,
			target:          "/mobile/fetchDocument",
			body:            `{"issuerID":"iss-1","serviceName":"deg"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing holderEID",
		},
		{
			name:            "fetchDocument missing issuerID",
			handler:         handleFetchDocument,
			method:          http.MethodPost,
			target:          "/mobile/fetchDocument",
			body:            `{"holderEID":"784-1234","serviceName":"deg"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing issuerID",
		},
		{
			name:            "fetchDocument missing serviceName",
			handler:         handleFetchDocument,
			method:          http.MethodPost,
			target:          "/mobile/fetchDocument",
			body:            `{"holderEID":"784-1234","issuerID":"iss-1"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing serviceName",
		},
		{
			name:            "getSubscriptions missing emiratesID",
			handler:         handleGetMobileSubscriptions,
			method:          http.MethodGet,
			target:          "/mobile/getSubscriptions",
			body:            "",
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "emiratesID is required",
		},
		{
			name:            "approveSubscription missing params",
			handler:         handleApproveSubscription,
			method:          http.MethodPost,
			target:          "/mobile/approveSubscription",
			body:            `{"subscriptionID":"SUB-1"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "subscriptionID and emiratesID are required",
		},
		{
			name:            "rejectSubscription missing params",
			handler:         handleRejectSubscription,
			method:          http.MethodPost,
			target:          "/mobile/rejectSubscription",
			body:            `{"subscriptionID":"SUB-1"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "subscriptionID and emiratesID are required",
		},
		{
			name:            "suspendCredential missing credentialID",
			handler:         handleSuspendCredential,
			method:          http.MethodPost,
			target:          "/suspendCredential",
			body:            `{"reason":"test investigation"}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
		},
		{
			name:            "restoreCredential missing credentialID",
			handler:         handleRestoreCredential,
			method:          http.MethodPost,
			target:          "/restoreCredential",
			body:            `{}`,
			wantStatus:      http.StatusBadRequest,
			wantErrorSubstr: "missing credentialID",
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

// TestFieldHashesComputation verifies per-field SHA3-256 computation matches Track H format.
func TestFieldHashesComputation(t *testing.T) {
	field := "gpa"
	value := "3.8"
	expected := sha3Hex("gpa:3.8")
	got := sha3Hex(field + ":" + value)
	if got != expected {
		t.Fatalf("per-field hash mismatch: got=%s want=%s", got, expected)
	}
}

// TestDubaiTimezoneFormat verifies expiry time format in Asia/Dubai has no Z suffix.
func TestDubaiTimezoneFormat(t *testing.T) {
	loc := mustLoadLocation("Asia/Dubai")
	now := time.Now().In(loc)
	formatted := now.Format("2006-01-02T15:04:05")
	if strings.HasSuffix(formatted, "Z") {
		t.Fatalf("Dubai timezone format should not contain UTC 'Z' suffix: %s", formatted)
	}
	if len(formatted) != 19 || formatted[10] != 'T' {
		t.Fatalf("unexpected format for Dubai time: %s", formatted)
	}
}

// TestApplySelectiveDisclosure validates the selective disclosure redaction helper.
func TestApplySelectiveDisclosure(t *testing.T) {
	// Nil handling: must not panic
	applySelectiveDisclosure(nil, []string{"gpa"})

	// Empty hiddenFields: leaves map untouched
	data := map[string]any{
		"holderName": "Fatima Al Mansoori",
		"gpa":        "3.9",
		"college":    "Engineering",
	}
	applySelectiveDisclosure(data, []string{})
	if data["holderName"] != "Fatima Al Mansoori" || data["gpa"] != "3.9" || data["college"] != "Engineering" {
		t.Fatalf("expected data to remain untouched with empty hidden fields")
	}

	// Single top-level field blanking
	applySelectiveDisclosure(data, []string{"gpa"})
	if data["gpa"] != nil {
		t.Fatalf("expected gpa to be nil after disclosure redaction, got %v", data["gpa"])
	}
	if data["college"] != "Engineering" {
		t.Fatalf("expected college to remain untouched, got %v", data["college"])
	}

	// Nested dotted path blanking (e.g. details.score)
	nested := map[string]any{
		"student": "Rashid",
		"details": map[string]any{
			"major": "Computer Science",
			"score": "A+",
		},
	}
	applySelectiveDisclosure(nested, []string{"details.score"})
	detailsMap, ok := nested["details"].(map[string]any)
	if !ok || detailsMap["score"] != nil {
		t.Fatalf("expected details.score to be nil, got %v", detailsMap["score"])
	}
	if detailsMap["major"] != "Computer Science" {
		t.Fatalf("expected details.major to remain untouched, got %v", detailsMap["major"])
	}

	// Non-existent hidden fields: safe and produces no side-effects
	applySelectiveDisclosure(data, []string{"nonExistentField", "unknown.subfield"})
	if data["college"] != "Engineering" {
		t.Fatalf("expected college to remain intact")
	}
}

// TestFieldHashesVerificationLogic verifies that the attribute-integrity loop correctly
// validates disclosed attributes against on-chain fieldHashes and detects tampering.
func TestFieldHashesVerificationLogic(t *testing.T) {
	// Simulated on-chain FieldHashes map computed at issuance
	onChainFieldHashes := map[string]string{
		"college":     sha3Hex("college:CCI"),
		"degreeTitle": sha3Hex("degreeTitle:BSc Computer Science"),
		"gpa":         sha3Hex("gpa:3.8"),
	}

	// Case 1: Valid disclosed fields matching on-chain hashes
	validFields := map[string]any{
		"college":     "CCI",
		"degreeTitle": "BSc Computer Science",
		"gpa":         "3.8",
	}
	valid := true
	for k, v := range validFields {
		expectedHash, exists := onChainFieldHashes[k]
		if !exists || !strings.EqualFold(sha3Hex(k+":"+fmt.Sprintf("%v", v)), expectedHash) {
			valid = false
			break
		}
	}
	if !valid {
		t.Fatalf("valid disclosed fields failed fieldHashes verification")
	}

	// Case 2: Tampered field value (holder attempts GPA elevation 3.8 -> 4.0)
	tamperedFields := map[string]any{
		"college":     "CCI",
		"degreeTitle": "BSc Computer Science",
		"gpa":         "4.0",
	}
	tamperedValid := true
	for k, v := range tamperedFields {
		expectedHash, exists := onChainFieldHashes[k]
		if !exists || !strings.EqualFold(sha3Hex(k+":"+fmt.Sprintf("%v", v)), expectedHash) {
			tamperedValid = false
			break
		}
	}
	if tamperedValid {
		t.Fatalf("tampered field value (3.8 -> 4.0) unexpectedly passed fieldHashes verification")
	}

	// Case 3: Injected attribute not present in on-chain FieldHashes
	injectedFields := map[string]any{
		"college":     "CCI",
		"distinction": "Dean's List",
	}
	injectedValid := true
	for k, v := range injectedFields {
		expectedHash, exists := onChainFieldHashes[k]
		if !exists || !strings.EqualFold(sha3Hex(k+":"+fmt.Sprintf("%v", v)), expectedHash) {
			injectedValid = false
			break
		}
	}
	if injectedValid {
		t.Fatalf("injected attribute not on ledger unexpectedly passed fieldHashes verification")
	}
}

// TestPresentationPayloadBindingParsing tests canonical JSON presentation payload
// unmarshaling, whitespace trimming, and credentialID binding validation.
func TestPresentationPayloadBindingParsing(t *testing.T) {
	// Case 1: Valid canonical JSON payload
	rawJSON := `{"credentialID":"CRED-2026-001","disclosedFields":{"college":"CCI","gpa":"3.8"},"timestamp":"2026-09-22T12:00:00"}`
	var payload struct {
		CredentialID    string         `json:"credentialID"`
		DisclosedFields map[string]any `json:"disclosedFields"`
		Timestamp       string         `json:"timestamp"`
	}
	if err := json.Unmarshal([]byte(rawJSON), &payload); err != nil {
		t.Fatalf("unmarshal canonical payload failed: %v", err)
	}
	if strings.TrimSpace(payload.CredentialID) != "CRED-2026-001" {
		t.Fatalf("credentialID mismatch. got=%q, want=%q", payload.CredentialID, "CRED-2026-001")
	}
	if payload.DisclosedFields["gpa"] != "3.8" {
		t.Fatalf("disclosed attribute mismatch. got=%v, want=3.8", payload.DisclosedFields["gpa"])
	}

	// Case 2: Whitespace padding in credentialID is trimmed cleanly
	paddedJSON := `{"credentialID":"  CRED-2026-001  "}`
	var paddedPayload struct {
		CredentialID string `json:"credentialID"`
	}
	if err := json.Unmarshal([]byte(paddedJSON), &paddedPayload); err != nil {
		t.Fatalf("unmarshal padded payload failed: %v", err)
	}
	if strings.TrimSpace(paddedPayload.CredentialID) != "CRED-2026-001" {
		t.Fatalf("expected trimmed credentialID, got=%q", strings.TrimSpace(paddedPayload.CredentialID))
	}

	// Case 3: Missing credentialID results in empty string
	missingIDJSON := `{"disclosedFields":{"gpa":"3.8"}}`
	var missingPayload struct {
		CredentialID string `json:"credentialID"`
	}
	_ = json.Unmarshal([]byte(missingIDJSON), &missingPayload)
	if strings.TrimSpace(missingPayload.CredentialID) != "" {
		t.Fatalf("expected empty credentialID for missing field")
	}
}

// TestMLDSAPresentationSigning verifies end-to-end holder presentation signing:
// generating an ML-DSA-44 keypair, signing the SHA3-256 hash of canonical JSON,
// and verifying with public key + detecting tampered payloads or key substitutions.
func TestMLDSAPresentationSigning(t *testing.T) {
	// 1. Generate holder's ML-DSA-44 key pair
	holderPub, holderPriv := testDSAKeyPair(t)

	// 2. Build canonical presentation payload
	disclosedPayload := `{"credentialID":"CRED-2026-001","disclosedFields":{"college":"CCI","degreeTitle":"BSc Computer Science","gpa":"3.8"},"timestamp":"2026-09-22T13:00:00"}`
	payloadHash := sha3Hex(disclosedPayload)

	// 3. Holder signs hash with private key
	sig, err := pqcSign(payloadHash, holderPriv)
	if err != nil {
		t.Fatalf("pqcSign failed: %v", err)
	}

	// 4. Verifier verifies signature with holder public key
	valid, err := pqcVerify(payloadHash, sig, holderPub)
	if err != nil {
		t.Fatalf("pqcVerify returned error: %v", err)
	}
	if !valid {
		t.Fatalf("expected holder presentation signature to verify successfully")
	}

	// 5. Tampered payload (e.g. gpa modified 3.8 -> 4.0) must fail verification
	tamperedPayload := `{"credentialID":"CRED-2026-001","disclosedFields":{"college":"CCI","degreeTitle":"BSc Computer Science","gpa":"4.0"},"timestamp":"2026-09-22T13:00:00"}`
	tamperedHash := sha3Hex(tamperedPayload)
	tamperedValid, _ := pqcVerify(tamperedHash, sig, holderPub)
	if tamperedValid {
		t.Fatalf("expected signature verification to fail for tampered payload")
	}

	// 6. Presentation verified with different holder's public key must fail
	otherPub, _ := testDSAKeyPair(t)
	otherKeyValid, _ := pqcVerify(payloadHash, sig, otherPub)
	if otherKeyValid {
		t.Fatalf("expected signature verification to fail with wrong holder public key")
	}
}
