package main

// commitment_test.go — the signed commitment, salted field hashes, disclosure
// rules and issuance input normalisation. Pure Go; no liboqs needed except
// where a test signs.

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

var (
	testHashA = strings.Repeat("a", 64)
	testHashB = strings.Repeat("b", 64)
	testSaltA = "0123456789abcdef0123456789abcdef"
	testSaltB = "fedcba9876543210fedcba9876543210"
)

func goldenCommitment() CredentialCommitment {
	return CredentialCommitment{
		HolderID:       "H-0001",
		CredentialType: "BSc Computer Science & AI <Hons>",
		IssuedAt:       "2026-09-24T06:15:30Z",
		IssuerOrgID:    "GeneralMSP",
		ExpiryDate:     "2030-06-30",
		CID:            "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
		FieldHashes:    map[string]string{"GPA": testHashA, "College": testHashB},
	}
}

// The canonical form is part of the signature format: changing it invalidates
// every issued credential, so this golden string must only change on purpose.
func TestCommitmentCanonicalJSONGolden(t *testing.T) {
	got, err := commitmentCanonicalJSON(goldenCommitment())
	if err != nil {
		t.Fatal(err)
	}
	want := `{"cid":"QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",` +
		`"credentialType":"BSc Computer Science & AI <Hons>",` +
		`"expiryDate":"2030-06-30",` +
		`"fieldHashes":{"College":"` + testHashB + `","GPA":"` + testHashA + `"},` +
		`"holderID":"H-0001","issuedAt":"2026-09-24T06:15:30Z","issuerOrgID":"GeneralMSP","v":2}`
	if got != want {
		t.Fatalf("canonical commitment changed:\n got  %s\n want %s", got, want)
	}
	hash, err := commitmentHash(goldenCommitment())
	if err != nil || hash != sha3Hex(want) {
		t.Fatalf("commitmentHash = %s, want sha3Hex(canonical) %s (err %v)", hash, sha3Hex(want), err)
	}
}

func TestCommitmentEmptyExpiryIsCommitted(t *testing.T) {
	c := goldenCommitment()
	c.ExpiryDate = ""
	got, _ := commitmentCanonicalJSON(c)
	if !strings.Contains(got, `"expiryDate":""`) {
		t.Fatalf("an empty expiry must still be present in the commitment: %s", got)
	}
}

func TestCommitmentAnyFieldChangeChangesHash(t *testing.T) {
	base, _ := commitmentHash(goldenCommitment())
	mutations := map[string]func(*CredentialCommitment){
		"holderID":       func(c *CredentialCommitment) { c.HolderID = "H-0002" },
		"credentialType": func(c *CredentialCommitment) { c.CredentialType = "MSc Computer Science" },
		"issuedAt":       func(c *CredentialCommitment) { c.IssuedAt = "2026-09-24T06:15:31Z" },
		"issuerOrgID":    func(c *CredentialCommitment) { c.IssuerOrgID = "GovernmentMSP" },
		"expiryDate":     func(c *CredentialCommitment) { c.ExpiryDate = "2031-06-30" },
		"expiry cleared": func(c *CredentialCommitment) { c.ExpiryDate = "" },
		"cid":            func(c *CredentialCommitment) { c.CID = "QmTzQ1JRkWErjk39mryYw2WVaphAZNAREyMchXzYQ7c15n" },
		"field hash": func(c *CredentialCommitment) {
			c.FieldHashes = map[string]string{"GPA": testHashB, "College": testHashB}
		},
		"field added": func(c *CredentialCommitment) {
			c.FieldHashes = map[string]string{"GPA": testHashA, "College": testHashB, "Honours": testHashA}
		},
		"field removed": func(c *CredentialCommitment) { c.FieldHashes = map[string]string{"GPA": testHashA} },
	}
	for name, mutate := range mutations {
		c := goldenCommitment()
		mutate(&c)
		if h, _ := commitmentHash(c); h == base {
			t.Errorf("changing %s did not change the commitment hash", name)
		}
	}
}

func TestCommitmentFromChainRoundTrip(t *testing.T) {
	c := goldenCommitment()
	cred := &ChainCredential{
		Holder: c.HolderID, CredentialType: c.CredentialType, IssuedAt: c.IssuedAt,
		IssuerOrgID: c.IssuerOrgID, ExpiryDate: c.ExpiryDate, CID: c.CID, FieldHashes: c.FieldHashes,
	}
	a, _ := commitmentHash(c)
	b, _ := commitmentHash(commitmentFromChain(cred))
	if a != b {
		t.Fatal("commitmentFromChain does not reproduce the issued commitment")
	}
}

func TestSignCommitmentVerifies(t *testing.T) {
	pub, priv := testDSAKeyPair(t)
	hash, sig, err := signCommitment(goldenCommitment(), priv)
	if err != nil {
		t.Fatal(err)
	}
	if ok, _ := pqcVerify(hash, sig, pub); !ok {
		t.Fatal("signature over the commitment hash does not verify")
	}
}

func TestSaltedFieldHash(t *testing.T) {
	if got, want := saltedFieldHash(testSaltA, "College", "CCI"), sha3Hex(testSaltA+":College:CCI"); got != want {
		t.Fatalf("saltedFieldHash = %s, want %s", got, want)
	}
	if saltedFieldHash(testSaltA, "College", "CCI") == saltedFieldHash(testSaltB, "College", "CCI") {
		t.Fatal("different salts must give different hashes")
	}
}

func TestCommitAttributes(t *testing.T) {
	attrs := map[string]string{"College": "CCI", "GPA": "3.8"}
	salts, hashes, err := commitAttributes(attrs)
	if err != nil {
		t.Fatal(err)
	}
	if len(salts) != 2 || len(hashes) != 2 {
		t.Fatalf("want 2 salts and 2 hashes, got %d / %d", len(salts), len(hashes))
	}
	for key, value := range attrs {
		if !isFieldSalt(salts[key]) {
			t.Fatalf("salt for %q is not 32 lowercase hex: %q", key, salts[key])
		}
		if hashes[key] != saltedFieldHash(salts[key], key, value) {
			t.Fatalf("hash for %q does not match its salt", key)
		}
	}
	if salts["College"] == salts["GPA"] {
		t.Fatal("every field needs its own salt")
	}
}

func TestIsFieldSalt(t *testing.T) {
	cases := map[string]bool{
		testSaltA:                  true,
		strings.ToUpper(testSaltA): false,
		testSaltA[:30]:             false,
		testSaltA + "00":           false,
		strings.Repeat("g", 32):    false,
		"":                         false,
	}
	for in, want := range cases {
		if got := isFieldSalt(in); got != want {
			t.Errorf("isFieldSalt(%q) = %v, want %v", in, got, want)
		}
	}
}

func TestValidateDisclosureSalts(t *testing.T) {
	disclosed := map[string]string{"College": "CCI", "GPA": "3.8"}
	cases := []struct {
		name      string
		disclosed map[string]string
		salts     map[string]string
		wantErr   string
	}{
		{"ok", disclosed, map[string]string{"College": testSaltA, "GPA": testSaltB}, ""},
		{"nothing disclosed", map[string]string{}, map[string]string{}, "at least one field"},
		{"missing salt", disclosed, map[string]string{"College": testSaltA}, `salts missing for field "GPA"`},
		{"salt for hidden field", map[string]string{"College": "CCI"},
			map[string]string{"College": testSaltA, "GPA": testSaltB}, `salt provided for undisclosed field "GPA"`},
		{"bad salt", disclosed, map[string]string{"College": testSaltA, "GPA": "xyz"}, `invalid salt for field "GPA"`},
	}
	for _, tc := range cases {
		err := validateDisclosureSalts(tc.disclosed, tc.salts)
		if tc.wantErr == "" {
			if err != nil {
				t.Errorf("%s: unexpected error %v", tc.name, err)
			}
			continue
		}
		if err == nil || !strings.Contains(err.Error(), tc.wantErr) {
			t.Errorf("%s: error = %v, want it to contain %q", tc.name, err, tc.wantErr)
		}
	}
}

func TestVerifyDisclosedFields(t *testing.T) {
	onChain := map[string]string{
		"College": saltedFieldHash(testSaltA, "College", "CCI"),
		"GPA":     saltedFieldHash(testSaltB, "GPA", "3.8"),
	}
	check := func(name string, disclosed, salts map[string]string, wantOK bool) {
		t.Helper()
		if err := verifyDisclosedFields(disclosed, salts, onChain); (err == nil) != wantOK {
			t.Errorf("%s: err = %v, want ok=%v", name, err, wantOK)
		}
	}
	check("all fields", map[string]string{"College": "CCI", "GPA": "3.8"},
		map[string]string{"College": testSaltA, "GPA": testSaltB}, true)
	check("one field", map[string]string{"GPA": "3.8"}, map[string]string{"GPA": testSaltB}, true)
	check("wrong value", map[string]string{"GPA": "4.0"}, map[string]string{"GPA": testSaltB}, false)
	check("wrong salt", map[string]string{"GPA": "3.8"}, map[string]string{"GPA": testSaltA}, false)
	check("unknown field", map[string]string{"Honours": "Yes"}, map[string]string{"Honours": testSaltA}, false)
	check("missing salt", map[string]string{"GPA": "3.8"}, map[string]string{}, false)
}

func TestParseExpiryDate(t *testing.T) {
	cases := map[string]string{
		"":                          "",
		"   ":                       "",
		"30 Jun 2030":               "2030-06-30",
		"2 Jan 2031":                "2031-01-02",
		"02 Jan 2031":               "2031-01-02",
		"2030-06-30":                "2030-06-30",
		"2030-06-30T00:00:00":       "2030-06-30",
		"2030-06-30T00:00:00.000":   "2030-06-30",
		"2030-06-30 13:45:00":       "2030-06-30",
		"2030-06-29T21:00:00Z":      "2030-06-30", // 01:00 on the 30th in Dubai
		"2030-06-30T19:59:59Z":      "2030-06-30", // 23:59:59 in Dubai
		"2030-06-30T23:30:00+04:00": "2030-06-30",
	}
	for in, want := range cases {
		got, err := parseExpiryDate(in)
		if err != nil || got != want {
			t.Errorf("parseExpiryDate(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"soon", "2030-02-30", "31 Feb 2030", "30/06/2030", "2030-6-30"} {
		if got, err := parseExpiryDate(bad); err == nil {
			t.Errorf("parseExpiryDate(%q) = %q, want an error", bad, got)
		}
	}
}

func TestNormalizeIssueAttributes(t *testing.T) {
	attrs, expiry, err := normalizeIssueAttributes(`{"College":"CCI","Degree Title":"BSc","Notes":"","expiryDate":"30 Jun 2030"}`)
	if err != nil {
		t.Fatal(err)
	}
	if expiry != "2030-06-30" {
		t.Fatalf("expiry = %q, want 2030-06-30", expiry)
	}
	if _, ok := attrs["expiryDate"]; ok {
		t.Fatal("expiryDate must be lifted out of the attributes")
	}
	if len(attrs) != 3 || attrs["College"] != "CCI" || attrs["Notes"] != "" {
		t.Fatalf("unexpected attrs %v", attrs)
	}

	if _, expiry, err := normalizeIssueAttributes(`{"College":"CCI","expiryDate":""}`); err != nil || expiry != "" {
		t.Fatalf("empty expiry means no expiry: %q %v", expiry, err)
	}

	tooMany := map[string]string{}
	for i := 0; i <= maxCredentialFields; i++ {
		tooMany[fmt.Sprintf("f%02d", i)] = "x"
	}
	bad := map[string]string{
		`["College"]`:                           "JSON object",
		`not json`:                              "JSON object",
		`null`:                                  "JSON object",
		`{"GPA":3.8}`:                           `field "GPA" must be a string`,
		`{"GPA":null}`:                          `field "GPA" must be a string`,
		`{"Info":{"a":"b"}}`:                    `field "Info" must be a string`,
		`{"_salts":"x"}`:                        "reserved",
		`{"_secret":"x"}`:                       "reserved",
		`{"holderName":"Fatima"}`:               "reserved for credential metadata",
		`{"status":"active"}`:                   "reserved for credential metadata",
		`{" ":"x"}`:                             "must not be empty",
		`{"expiryDate":"30 Jun 2030"}`:          "at least one credential field",
		`{}`:                                    "at least one credential field",
		`{"College":"CCI","expiryDate":7}`:      `field "expiryDate" must be a string`,
		`{"College":"CCI","expiryDate":"soon"}`: "invalid expiryDate",
	}
	raw, _ := json.Marshal(tooMany)
	bad[string(raw)] = "too many fields"
	for in, want := range bad {
		if _, _, err := normalizeIssueAttributes(in); err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("normalizeIssueAttributes(%.60s) error = %v, want it to contain %q", in, err, want)
		}
	}
}
