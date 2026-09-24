package main

// verification_test.go — verifyPresentation with real ML-DSA-44 keys: the
// happy path, every tamper case, the trusted-issuer-key pin, lifecycle
// statuses and reason precedence. Needs liboqs (as in the Docker builder).

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

const (
	testDisplayID = "CRED-0007"
	testFabricID  = "CRED-4f1c2b"
)

var testPresentationNow = time.Date(2026, 9, 24, 6, 30, 0, 0, time.UTC)

// presentationFixture is one issued credential plus a holder able to present it.
type presentationFixture struct {
	t          *testing.T
	issuerPub  string
	issuerPriv string
	holderPub  string
	holderPriv string
	attrs      map[string]string
	salts      map[string]string
	cred       *ChainCredential
	holder     *ChainHolder
}

func newPresentationFixture(t *testing.T) *presentationFixture {
	t.Helper()
	f := &presentationFixture{t: t}
	f.issuerPub, f.issuerPriv = testDSAKeyPair(t)
	f.holderPub, f.holderPriv = testDSAKeyPair(t)
	f.attrs = map[string]string{
		"Degree Title": "Bachelors in Computer Science",
		"College":      "College of Computing & Informatics",
		"GPA":          "3.8",
	}
	salts, fieldHashes, err := commitAttributes(f.attrs)
	if err != nil {
		t.Fatal(err)
	}
	f.salts = salts
	f.cred = &ChainCredential{
		DocType:           "credential",
		CommitmentVersion: commitmentVersion,
		ID:                testFabricID,
		Holder:            "H-0001",
		IssuerOrgID:       "GeneralMSP",
		Status:            "active",
		CredentialType:    "BSc Computer Science",
		IssuedAt:          "2026-09-01T08:00:00Z",
		ExpiryDate:        "2030-06-30",
		CID:               "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
		FieldHashes:       fieldHashes,
	}
	f.resign(f.issuerPriv, f.issuerPub)
	f.holder = &ChainHolder{ID: "H-0001", FirstName: "Fatima", LastName: "Al Mansoori", KemPublicKey: "ab", DsaPublicKey: f.holderPub}
	return f
}

// resign signs the credential's current commitment with the given key.
func (f *presentationFixture) resign(priv, pub string) {
	f.t.Helper()
	hash, sig, err := signCommitment(commitmentFromChain(f.cred), priv)
	if err != nil {
		f.t.Fatal(err)
	}
	f.cred.CredentialHash, f.cred.Signature, f.cred.PublicKey = hash, sig, pub
}

// payload builds a presentation JSON the way the wallet does (sorted keys, no
// whitespace) and signs it with the given holder key.
func (f *presentationFixture) payload(credID string, disclosed, salts map[string]string, holderPriv string) (string, string) {
	f.t.Helper()
	raw, err := json.Marshal(map[string]any{
		"credentialID":    credID,
		"disclosedFields": disclosed,
		"salts":           salts,
		"timestamp":       "2026-09-24T06:29:00.000Z",
	})
	if err != nil {
		f.t.Fatal(err)
	}
	sig, err := pqcSign(sha3Hex(string(raw)), holderPriv)
	if err != nil {
		f.t.Fatal(err)
	}
	return string(raw), sig
}

// discloseAll presents every field with its salt.
func (f *presentationFixture) discloseAll() (map[string]string, map[string]string) {
	d, s := map[string]string{}, map[string]string{}
	for k, v := range f.attrs {
		d[k], s[k] = v, f.salts[k]
	}
	return d, s
}

func (f *presentationFixture) verify(rawPayload, holderSig string) VerifyOutcome {
	return verifyPresentation(VerifyInput{
		DisplayID:        testDisplayID,
		FabricID:         testFabricID,
		Cred:             f.cred,
		Holder:           f.holder,
		RawPayload:       rawPayload,
		HolderSignature:  holderSig,
		TrustedIssuerKey: f.issuerPub,
		Now:              testPresentationNow,
	})
}

func expectReason(t *testing.T, name string, got VerifyOutcome, reason string) {
	t.Helper()
	if got.Reason != reason || got.Verified != (reason == "") {
		t.Fatalf("%s: verified=%v reason=%q, want reason %q (outcome %+v)", name, got.Verified, got.Reason, reason, got)
	}
}

func TestVerifyPresentationValid(t *testing.T) {
	f := newPresentationFixture(t)
	d, s := f.discloseAll()
	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)
	out := f.verify(raw, sig)
	expectReason(t, "valid", out, "")
	if !(out.ExistsOnChain && out.NotRevoked && out.SignatureValid && out.HashMatches && out.FieldHashesValid && out.HolderSignatureValid) {
		t.Fatalf("all checks should pass: %+v", out)
	}
	if out.Status != "active" || out.Disclosed["GPA"] != "3.8" {
		t.Fatalf("status %q disclosed %v", out.Status, out.Disclosed)
	}
}

func TestVerifyPresentationSelectiveDisclosure(t *testing.T) {
	f := newPresentationFixture(t)
	raw, sig := f.payload(testDisplayID,
		map[string]string{"College": f.attrs["College"]},
		map[string]string{"College": f.salts["College"]}, f.holderPriv)
	out := f.verify(raw, sig)
	expectReason(t, "one field", out, "")
	if _, leaked := out.Disclosed["GPA"]; leaked {
		t.Fatal("undisclosed field appeared in the outcome")
	}
}

func TestVerifyPresentationFabricIDBinding(t *testing.T) {
	f := newPresentationFixture(t)
	d, s := f.discloseAll()
	raw, sig := f.payload(testFabricID, d, s, f.holderPriv)
	expectReason(t, "fabric id", f.verify(raw, sig), "")
}

func TestVerifyPresentationHolderSideTampering(t *testing.T) {
	f := newPresentationFixture(t)

	// The holder re-signs a payload with an inflated GPA: their signature is
	// fine, but the value no longer matches the issuer's field hash.
	d, s := f.discloseAll()
	d["GPA"] = "4.0"
	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)
	out := f.verify(raw, sig)
	expectReason(t, "inflated value", out, reasonFieldHashesInvalid)
	if !out.HolderSignatureValid || !out.SignatureValid {
		t.Fatalf("only the field check should fail: %+v", out)
	}

	d, s = f.discloseAll()
	s["GPA"] = testSaltA
	raw, sig = f.payload(testDisplayID, d, s, f.holderPriv)
	expectReason(t, "wrong salt", f.verify(raw, sig), reasonFieldHashesInvalid)

	d, s = f.discloseAll()
	delete(s, "GPA")
	raw, sig = f.payload(testDisplayID, d, s, f.holderPriv)
	expectReason(t, "missing salt", f.verify(raw, sig), reasonFieldHashesInvalid)

	d, s = map[string]string{"College": f.attrs["College"]}, map[string]string{"College": f.salts["College"], "GPA": f.salts["GPA"]}
	raw, sig = f.payload(testDisplayID, d, s, f.holderPriv)
	expectReason(t, "salt for hidden field", f.verify(raw, sig), reasonFieldHashesInvalid)

	d, s = map[string]string{"Honours": "First Class"}, map[string]string{"Honours": testSaltA}
	raw, sig = f.payload(testDisplayID, d, s, f.holderPriv)
	expectReason(t, "invented field", f.verify(raw, sig), reasonFieldHashesInvalid)
}

func TestVerifyPresentationHolderSignature(t *testing.T) {
	f := newPresentationFixture(t)
	d, s := f.discloseAll()

	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)
	edited := strings.Replace(raw, `"3.8"`, `"3.9"`, 1)
	out := f.verify(edited, sig)
	if out.HolderSignatureValid {
		t.Fatal("a payload edited after signing must not verify")
	}
	expectReason(t, "edited after signing", out, reasonFieldHashesInvalid) // the edited value also breaks its field hash

	// Same bytes, but only the signature is wrong.
	_, otherPriv := testDSAKeyPair(t)
	raw, sig = f.payload(testDisplayID, d, s, otherPriv)
	expectReason(t, "someone else's key", f.verify(raw, sig), reasonHolderSignatureInvalid)

	raw, sig = f.payload("CRED-0008", d, s, f.holderPriv)
	expectReason(t, "presentation for another credential", f.verify(raw, sig), reasonHolderSignatureInvalid)

	raw, _ = f.payload(testDisplayID, d, s, f.holderPriv)
	expectReason(t, "no signature", f.verify(raw, ""), reasonHolderSignatureInvalid)

	f.holder = nil
	raw, sig = f.payload(testDisplayID, d, s, f.holderPriv)
	expectReason(t, "holder missing on-chain", f.verify(raw, sig), reasonHolderSignatureInvalid)
}

func TestVerifyPresentationLedgerTampering(t *testing.T) {
	cases := map[string]func(c *ChainCredential){
		"expiry extended":  func(c *ChainCredential) { c.ExpiryDate = "2035-06-30" },
		"type changed":     func(c *ChainCredential) { c.CredentialType = "PhD Computer Science" },
		"holder changed":   func(c *ChainCredential) { c.Holder = "H-0002" },
		"cid swapped":      func(c *ChainCredential) { c.CID = "QmTzQ1JRkWErjk39mryYw2WVaphAZNAREyMchXzYQ7c15n" },
		"issued changed":   func(c *ChainCredential) { c.IssuedAt = "2020-01-01T00:00:00Z" },
		"org changed":      func(c *ChainCredential) { c.IssuerOrgID = "GovernmentMSP" },
		"field hash added": func(c *ChainCredential) { c.FieldHashes["Honours"] = testHashA },
	}
	for name, mutate := range cases {
		f := newPresentationFixture(t)
		d, s := f.discloseAll()
		raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)
		mutate(f.cred)
		out := f.verify(raw, sig)
		expectReason(t, name, out, reasonSignatureInvalid)
		if out.HashMatches {
			t.Fatalf("%s: stored hash should no longer match the recomputed commitment", name)
		}
	}
}

func TestVerifyPresentationFieldHashSwapAndUpdate(t *testing.T) {
	// Replacing a field hash with one for a value the attacker chose also
	// breaks the issuer signature, even though the disclosed field then matches.
	f := newPresentationFixture(t)
	f.cred.FieldHashes["GPA"] = saltedFieldHash(testSaltA, "GPA", "4.0")
	raw, sig := f.payload(testDisplayID, map[string]string{"GPA": "4.0"}, map[string]string{"GPA": testSaltA}, f.holderPriv)
	out := f.verify(raw, sig)
	expectReason(t, "forged field hash", out, reasonSignatureInvalid)
	if !out.FieldHashesValid {
		t.Fatal("the forged value matches the forged hash; only the signature catches it")
	}
}

func TestVerifyPresentationUntrustedIssuerKey(t *testing.T) {
	// An attacker re-signs a modified commitment with their own key and puts
	// their public key on the record: the signature is internally consistent,
	// but the key is not the trusted issuer key.
	f := newPresentationFixture(t)
	d, s := f.discloseAll()
	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)
	attackerPub, attackerPriv := testDSAKeyPair(t)
	f.cred.ExpiryDate = "2040-01-01"
	f.resign(attackerPriv, attackerPub)
	out := f.verify(raw, sig)
	expectReason(t, "self-signed", out, reasonSignatureInvalid)
	if !out.HashMatches {
		t.Fatal("the attacker's stored hash is consistent; only the key pin catches it")
	}

	f = newPresentationFixture(t)
	raw, sig = f.payload(testDisplayID, d, s, f.holderPriv)
	out = verifyPresentation(VerifyInput{
		DisplayID: testDisplayID, FabricID: testFabricID, Cred: f.cred, Holder: f.holder,
		RawPayload: raw, HolderSignature: sig, TrustedIssuerKey: "", Now: testPresentationNow,
	})
	expectReason(t, "no trusted key configured", out, reasonSignatureInvalid)
}

func TestVerifyPresentationStoredHashOnly(t *testing.T) {
	f := newPresentationFixture(t)
	d, s := f.discloseAll()
	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)
	f.cred.CredentialHash = testHashA
	out := f.verify(raw, sig)
	expectReason(t, "stored hash altered", out, reasonHashMismatch)
	if !out.SignatureValid {
		t.Fatal("the signature is checked over the recomputed commitment, not the stored hash")
	}
}

func TestVerifyPresentationLifecycle(t *testing.T) {
	f := newPresentationFixture(t)
	d, s := f.discloseAll()
	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)

	f.cred.Status = "suspended"
	out := f.verify(raw, sig)
	expectReason(t, "suspended", out, reasonSuspended)
	if out.NotRevoked || !out.SignatureValid || out.Status != "suspended" {
		t.Fatalf("suspended: %+v", out)
	}

	f.cred.Status = "revoked"
	out = f.verify(raw, sig)
	expectReason(t, "revoked", out, reasonRevoked)
	if out.NotRevoked || !out.FieldHashesValid {
		t.Fatalf("revoked: all other checks still run: %+v", out)
	}

	// Revoked outranks any crypto failure.
	f.cred.CredentialType = "tampered"
	expectReason(t, "revoked and tampered", f.verify(raw, sig), reasonRevoked)
}

func TestVerifyPresentationExpiry(t *testing.T) {
	f := newPresentationFixture(t)
	d, s := f.discloseAll()
	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)

	// A properly re-signed past expiry → EXPIRED, not a signature failure.
	f.cred.ExpiryDate = "2020-01-01"
	f.resign(f.issuerPriv, f.issuerPub)
	out := f.verify(raw, sig)
	expectReason(t, "expired", out, reasonExpired)
	if !out.NotRevoked || !out.SignatureValid || out.Status != "expired" {
		t.Fatalf("expired: %+v", out)
	}

	// Re-signed back to a future expiry → valid again.
	f.cred.ExpiryDate = "2031-12-31"
	f.resign(f.issuerPriv, f.issuerPub)
	expectReason(t, "re-signed expiry", f.verify(raw, sig), "")

	// Old signature with a new expiry → invalid.
	oldHash, oldSig := f.cred.CredentialHash, f.cred.Signature
	f.cred.ExpiryDate = "2032-12-31"
	f.cred.CredentialHash, f.cred.Signature = oldHash, oldSig
	expectReason(t, "expiry changed without re-signing", f.verify(raw, sig), reasonSignatureInvalid)
}

func TestVerifyPresentationNotFound(t *testing.T) {
	f := newPresentationFixture(t)
	d, s := f.discloseAll()
	raw, sig := f.payload(testDisplayID, d, s, f.holderPriv)
	out := verifyPresentation(VerifyInput{
		DisplayID: testDisplayID, FabricID: testFabricID, Cred: nil,
		RawPayload: raw, HolderSignature: sig, TrustedIssuerKey: f.issuerPub, Now: testPresentationNow,
	})
	expectReason(t, "not found", out, reasonNotFound)
	if out.ExistsOnChain || out.SignatureValid || out.Status != "" {
		t.Fatalf("not found: %+v", out)
	}
}

func TestVerifyPresentationMalformedPayload(t *testing.T) {
	f := newPresentationFixture(t)
	out := f.verify(`{"credentialID":"CRED-0007","disclosedFields":{"GPA":3.8}}`, "00")
	expectReason(t, "malformed", out, reasonFieldHashesInvalid)
	if out.HolderSignatureValid || out.Disclosed != nil {
		t.Fatalf("malformed payload: %+v", out)
	}
}

func TestParseDisclosedPayload(t *testing.T) {
	p, err := parseDisclosedPayload(`{"credentialID":"CRED-0007","disclosedFields":{"College":"CCI"},"salts":{"College":"` + testSaltA + `"},"timestamp":"2026-09-24T06:15:30.123Z"}`)
	if err != nil {
		t.Fatal(err)
	}
	if p.CredentialID != "CRED-0007" || p.DisclosedFields["College"] != "CCI" || p.Salts["College"] != testSaltA {
		t.Fatalf("parsed %+v", p)
	}
	for in, want := range map[string]string{
		`{invalid`: "invalid JSON in disclosedPayload",
		`{"credentialID":"C","disclosedFields":{"GPA":3.8}}`:          `disclosedFields["GPA"] must be a string`,
		`{"credentialID":"C","disclosedFields":{"GPA":null}}`:         `disclosedFields["GPA"] must be a string`,
		`{"credentialID":"C","disclosedFields":{},"salts":{"GPA":1}}`: `salts["GPA"] must be a string`,
	} {
		if _, err := parseDisclosedPayload(in); err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("parseDisclosedPayload(%s) error = %v, want %q", in, err, want)
		}
	}
}
