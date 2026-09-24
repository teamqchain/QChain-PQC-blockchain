package main

// chain_test.go — ledger record decoding, effective status / expiry rules, and
// the batch helpers. No Fabric connection needed.

import (
	"encoding/json"
	"fmt"
	"testing"
	"time"
)

func mustUTC(t *testing.T, s string) time.Time {
	t.Helper()
	tm, err := time.Parse(time.RFC3339, s)
	if err != nil {
		t.Fatal(err)
	}
	return tm
}

// A credential is valid through the END of its expiry day, UAE time (UTC+4).
func TestIsExpiredDubaiBoundary(t *testing.T) {
	cases := []struct {
		expiry string
		now    string
		want   bool
	}{
		{"", "2099-01-01T00:00:00Z", false},
		{"2030-06-30", "2030-06-29T12:00:00Z", false},
		{"2030-06-30", "2030-06-30T19:59:59Z", false}, // 23:59:59 in Dubai
		{"2030-06-30", "2030-06-30T20:00:00Z", true},  // 00:00 on 1 July in Dubai
		{"2030-06-30", "2030-07-02T00:00:00Z", true},
		{"2020-01-01", "2026-09-24T06:00:00Z", true},
	}
	for _, tc := range cases {
		if got := isExpired(tc.expiry, mustUTC(t, tc.now)); got != tc.want {
			t.Errorf("isExpired(%q, %s) = %v, want %v", tc.expiry, tc.now, got, tc.want)
		}
	}
}

func TestEffectiveStatusPrecedence(t *testing.T) {
	now := mustUTC(t, "2026-09-24T06:00:00Z")
	cases := []struct {
		stored, expiry, want string
	}{
		{"active", "", "active"},
		{"active", "2030-06-30", "active"},
		{"active", "2020-01-01", "expired"},
		{"suspended", "2020-01-01", "suspended"},
		{"revoked", "2020-01-01", "revoked"},
		{"revoked", "", "revoked"},
	}
	for _, tc := range cases {
		c := &ChainCredential{Status: tc.stored, ExpiryDate: tc.expiry}
		if got := effectiveStatus(c, now); got != tc.want {
			t.Errorf("effectiveStatus(%s, expiry %q) = %s, want %s", tc.stored, tc.expiry, got, tc.want)
		}
	}
}

func TestChainHolderViews(t *testing.T) {
	full := &ChainHolder{FirstName: "Fatima", LastName: "Al Mansoori", KemPublicKey: "ab", DsaPublicKey: "cd"}
	if full.FullName() != "Fatima Al Mansoori" || !full.WalletActivated() {
		t.Fatalf("full view: name %q activated %v", full.FullName(), full.WalletActivated())
	}
	summary := &ChainHolder{FirstName: "Rashid", LastName: "Khan", KemBound: true}
	if !summary.HasKemKey() || summary.HasDsaKey() || summary.WalletActivated() {
		t.Fatal("summary view flags not honoured")
	}
	var missing *ChainHolder
	if missing.FullName() != "" || missing.WalletActivated() {
		t.Fatal("a nil holder must read as empty / not activated")
	}
}

// The JSON below is exactly what QChaincode v2 getCredentials returns.
func TestChainSnapshotDecodesChaincodeJSON(t *testing.T) {
	raw := `{"credentials":{"CRED-tx1":{"CID":"QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",` +
		`"CommitmentVersion":2,"CredentialHash":"` + testHashA + `","CredentialType":"BSc",` +
		`"DocType":"credential","ExpiryDate":"2030-06-30","FieldHashes":{"College":"` + testHashB + `"},` +
		`"Holder":"H-0001","ID":"CRED-tx1","IssuedAt":"2026-09-24T06:00:00Z",` +
		`"Issuer":"x509::/CN=issuer1","IssuerOrgID":"GeneralMSP","PublicKey":"cd","Signature":"ef",` +
		`"Status":"suspended","SuspendedAt":"2026-09-25T08:30:00Z","SuspendedReason":"check"}},` +
		`"holders":{"H-0001":{"DocType":"holder","DsaBound":true,"FirstName":"Fatima","ID":"H-0001",` +
		`"KemBound":true,"LastName":"Al Mansoori"}}}`
	var snap ChainSnapshot
	if err := json.Unmarshal([]byte(raw), &snap); err != nil {
		t.Fatal(err)
	}
	c := snap.Credentials["CRED-tx1"]
	if c == nil || c.CommitmentVersion != 2 || c.FieldHashes["College"] != testHashB || c.SuspendedReason != "check" {
		t.Fatalf("credential decoded wrongly: %+v", c)
	}
	h := snap.holderOf(c)
	if h.FullName() != "Fatima Al Mansoori" || !h.WalletActivated() {
		t.Fatalf("holder decoded wrongly: %+v", h)
	}
	if issued, ok := formatChainTime(c.IssuedAt); !ok || FormatISO(issued) != "2026-09-24T10:00:00" {
		t.Fatalf("IssuedAt in Dubai time = %v (ok %v)", issued, ok)
	}
}

func TestBatchHelpers(t *testing.T) {
	ids := uniqueNonEmpty([]string{"a", "", "b", "a", "c", ""})
	if fmt.Sprint(ids) != "[a b c]" {
		t.Fatalf("uniqueNonEmpty = %v", ids)
	}
	many := make([]string, 1001)
	for i := range many {
		many[i] = fmt.Sprintf("CRED-%d", i)
	}
	chunks := chunkIDs(many)
	if len(chunks) != 3 || len(chunks[0]) != 500 || len(chunks[2]) != 1 {
		t.Fatalf("chunkIDs sizes wrong: %d chunks", len(chunks))
	}
	if len(chunkIDs(nil)) != 0 {
		t.Fatal("no ids must mean no chain calls")
	}
	// An empty id list must not touch the chain at all.
	snap, err := chainReadCredentials(nil, viewSummary)
	if err != nil || len(snap.Credentials) != 0 {
		t.Fatalf("chainReadCredentials(nil) = %v, %v", snap, err)
	}
}

func TestExpiryAsTime(t *testing.T) {
	if _, ok := expiryAsTime(""); ok {
		t.Fatal("no expiry must not produce a time")
	}
	tm, ok := expiryAsTime("2030-06-30")
	if !ok || tm.Format(time.RFC3339) != "2030-06-30T00:00:00+04:00" {
		t.Fatalf("expiryAsTime = %v", tm)
	}
}
