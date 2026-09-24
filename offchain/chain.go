package main

// chain.go — typed access to the ledger, the source of truth for every field
// it holds.
//
// Read rule used by all handlers: MySQL supplies the set of IDs to show plus the
// fields that exist nowhere else (email, Emirates ID, display IDs, favourites…);
// every field the chain holds (type, status, holder name, dates, keys, CID) is
// read from the chain in ONE batch call and merged in Go. There is no "try the
// chain, fall back to MySQL" path: if the chain is unreachable the request fails,
// and a row whose chain record is missing is dropped (and logged), never
// back-filled from MySQL's cached copy.
//
// Writes go through chainSubmit as the issuer identity; reads use the verifier
// identity (the ledger's read transactions are not role-gated).

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/hyperledger/fabric-gateway/pkg/client"
)

// errChainNotFound is returned when a requested record is not on the ledger.
var errChainNotFound = errors.New("not found on chain")

// Views understood by the chaincode's batch reads. "summary" omits the heavy
// fields (signature, keys, hashes) that list screens never show.
const (
	viewFull    = "full"
	viewSummary = "summary"
)

// chainBatchSize keeps each batch read well under the chaincode's 1000-ID cap.
const chainBatchSize = 500

// ChainCredential mirrors the chaincode's credential record (v2, no body).
type ChainCredential struct {
	DocType           string            `json:"DocType"`
	CommitmentVersion int               `json:"CommitmentVersion"`
	ID                string            `json:"ID"`
	Holder            string            `json:"Holder"`
	Issuer            string            `json:"Issuer"`
	IssuerOrgID       string            `json:"IssuerOrgID"`
	Status            string            `json:"Status"`
	CredentialType    string            `json:"CredentialType"`
	IssuedAt          string            `json:"IssuedAt"`
	ExpiryDate        string            `json:"ExpiryDate"`
	CID               string            `json:"CID"`
	FieldHashes       map[string]string `json:"FieldHashes,omitempty"`
	CredentialHash    string            `json:"CredentialHash,omitempty"`
	Signature         string            `json:"Signature,omitempty"`
	PublicKey         string            `json:"PublicKey,omitempty"`
	RevokedAt         string            `json:"RevokedAt,omitempty"`
	SuspendedAt       string            `json:"SuspendedAt,omitempty"`
	SuspendedReason   string            `json:"SuspendedReason,omitempty"`
	RestoredAt        string            `json:"RestoredAt,omitempty"`
	ExpiryUpdatedAt   string            `json:"ExpiryUpdatedAt,omitempty"`
}

// ChainHolder mirrors the chaincode's holder record. The summary view replaces
// the two public keys with the KemBound / DsaBound flags.
type ChainHolder struct {
	DocType      string `json:"DocType"`
	ID           string `json:"ID"`
	FirstName    string `json:"FirstName"`
	LastName     string `json:"LastName"`
	KemPublicKey string `json:"KemPublicKey,omitempty"`
	DsaPublicKey string `json:"DsaPublicKey,omitempty"`
	KemBound     bool   `json:"KemBound,omitempty"`
	DsaBound     bool   `json:"DsaBound,omitempty"`
}

// FullName is "First Last" as registered on-chain.
func (h *ChainHolder) FullName() string {
	if h == nil {
		return ""
	}
	return strings.TrimSpace(h.FirstName + " " + h.LastName)
}

// HasKemKey / HasDsaKey work for both the full and the summary view.
func (h *ChainHolder) HasKemKey() bool { return h != nil && (h.KemPublicKey != "" || h.KemBound) }
func (h *ChainHolder) HasDsaKey() bool { return h != nil && (h.DsaPublicKey != "" || h.DsaBound) }

// WalletActivated is true once the holder's wallet has bound both public keys.
func (h *ChainHolder) WalletActivated() bool { return h.HasKemKey() && h.HasDsaKey() }

// ChainSnapshot is the result of one batch credential read: the requested
// credentials (missing IDs are simply absent) plus the holders they reference.
type ChainSnapshot struct {
	Credentials map[string]*ChainCredential `json:"credentials"`
	Holders     map[string]*ChainHolder     `json:"holders"`
}

// holderOf returns the on-chain holder record of a credential (nil if absent).
func (s *ChainSnapshot) holderOf(c *ChainCredential) *ChainHolder {
	if s == nil || c == nil {
		return nil
	}
	return s.Holders[c.Holder]
}

// ─────────────────────────────────────────────
//  CONNECTION HELPERS
// ─────────────────────────────────────────────

// withContract opens one gateway connection, runs fn, and always closes it.
func withContract(orgName, identityName string, fn func(*client.Contract) error) error {
	contract, gw, conn, err := getContract(orgName, identityName)
	if err != nil {
		return fmt.Errorf("blockchain gateway: %w", err)
	}
	defer conn.Close()
	defer gw.Close()
	return fn(contract)
}

// chainEvaluate runs a read-only chaincode query as the reader identity.
func chainEvaluate(fn string, args ...string) ([]byte, error) {
	var out []byte
	err := withContract(verifierOrgName, verifierIdentity, func(c *client.Contract) error {
		res, err := c.EvaluateTransaction(fn, args...)
		if err != nil {
			return fmt.Errorf("chaincode %s: %s", fn, formatFabricError(err))
		}
		out = res
		return nil
	})
	return out, err
}

// chainSubmit endorses and commits a chaincode transaction as the issuer. The
// v2 chaincode throws on every failure, so an error here means nothing was
// written to the ledger.
func chainSubmit(fn string, args ...string) ([]byte, error) {
	var out []byte
	err := withContract(issuerOrgName, issuerIdentity, func(c *client.Contract) error {
		res, err := c.SubmitTransaction(fn, args...)
		if err != nil {
			return fmt.Errorf("chaincode %s: %s", fn, formatFabricError(err))
		}
		out = res
		return nil
	})
	return out, err
}

// ─────────────────────────────────────────────
//  BATCH READS
// ─────────────────────────────────────────────

// uniqueNonEmpty de-duplicates ids, dropping empty strings, keeping order.
func uniqueNonEmpty(ids []string) []string {
	seen := make(map[string]bool, len(ids))
	out := make([]string, 0, len(ids))
	for _, id := range ids {
		if id == "" || seen[id] {
			continue
		}
		seen[id] = true
		out = append(out, id)
	}
	return out
}

// chunkIDs splits ids into slices of at most chainBatchSize.
func chunkIDs(ids []string) [][]string {
	var chunks [][]string
	for start := 0; start < len(ids); start += chainBatchSize {
		end := start + chainBatchSize
		if end > len(ids) {
			end = len(ids)
		}
		chunks = append(chunks, ids[start:end])
	}
	return chunks
}

// chainReadCredentials fetches many credentials (and their holders) using as
// few chaincode calls as possible. An empty id list costs no chain call.
func chainReadCredentials(ids []string, view string) (*ChainSnapshot, error) {
	snap := &ChainSnapshot{
		Credentials: map[string]*ChainCredential{},
		Holders:     map[string]*ChainHolder{},
	}
	for _, chunk := range chunkIDs(uniqueNonEmpty(ids)) {
		idsJSON, err := json.Marshal(chunk)
		if err != nil {
			return nil, err
		}
		res, err := chainEvaluate("getCredentials", string(idsJSON), view)
		if err != nil {
			return nil, err
		}
		var part ChainSnapshot
		if err := json.Unmarshal(res, &part); err != nil {
			return nil, fmt.Errorf("decode getCredentials response: %w", err)
		}
		for id, c := range part.Credentials {
			snap.Credentials[id] = c
		}
		for id, h := range part.Holders {
			snap.Holders[id] = h
		}
	}
	return snap, nil
}

// chainReadCredential fetches one credential and its holder in a single call.
// Returns errChainNotFound if the credential is not on the ledger.
func chainReadCredential(id, view string) (*ChainCredential, *ChainHolder, error) {
	snap, err := chainReadCredentials([]string{id}, view)
	if err != nil {
		return nil, nil, err
	}
	cred := snap.Credentials[id]
	if cred == nil {
		return nil, nil, errChainNotFound
	}
	return cred, snap.holderOf(cred), nil
}

// chainReadHolders fetches many holder records; missing IDs are absent.
func chainReadHolders(ids []string, view string) (map[string]*ChainHolder, error) {
	out := map[string]*ChainHolder{}
	for _, chunk := range chunkIDs(uniqueNonEmpty(ids)) {
		idsJSON, err := json.Marshal(chunk)
		if err != nil {
			return nil, err
		}
		res, err := chainEvaluate("getHolders", string(idsJSON), view)
		if err != nil {
			return nil, err
		}
		var part struct {
			Holders map[string]*ChainHolder `json:"holders"`
		}
		if err := json.Unmarshal(res, &part); err != nil {
			return nil, fmt.Errorf("decode getHolders response: %w", err)
		}
		for id, h := range part.Holders {
			out[id] = h
		}
	}
	return out, nil
}

// chainReadHolder fetches one holder record, or errChainNotFound.
func chainReadHolder(id, view string) (*ChainHolder, error) {
	holders, err := chainReadHolders([]string{id}, view)
	if err != nil {
		return nil, err
	}
	h := holders[id]
	if h == nil {
		return nil, errChainNotFound
	}
	return h, nil
}

// logMissingOnChain records IDs that MySQL knows about but the ledger does not.
// Such rows are left out of responses (never filled in from MySQL).
func logMissingOnChain(where string, ids []string) {
	if len(ids) > 0 {
		log.Printf("WARNING: %s: %d record(s) in MySQL are missing on-chain and were skipped: %v", where, len(ids), ids)
	}
}

// ─────────────────────────────────────────────
//  STATUS & TIME
// ─────────────────────────────────────────────

// dubaiDate formats t as the UAE calendar date (YYYY-MM-DD).
func dubaiDate(t time.Time) string {
	return t.In(mustLoadLocation("Asia/Dubai")).Format("2006-01-02")
}

// isExpired reports whether a YYYY-MM-DD expiry has passed. A credential is
// valid through the END of its expiry day, UAE time.
func isExpired(expiry string, now time.Time) bool {
	return expiry != "" && dubaiDate(now) > expiry
}

// effectiveStatus is the status every API reports: the stored on-chain status,
// except that an active credential past its expiry is "expired". Precedence:
// revoked > suspended > expired > active.
func effectiveStatus(c *ChainCredential, now time.Time) string {
	switch c.Status {
	case "revoked", "suspended":
		return c.Status
	}
	if isExpired(c.ExpiryDate, now) {
		return "expired"
	}
	return c.Status
}

// formatChainTime parses an on-chain RFC3339 timestamp into UAE local time.
func formatChainTime(s string) (time.Time, bool) {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Time{}, false
	}
	return t.In(mustLoadLocation("Asia/Dubai")), true
}

// expiryAsTime parses a YYYY-MM-DD expiry as midnight UAE time.
func expiryAsTime(expiry string) (time.Time, bool) {
	if expiry == "" {
		return time.Time{}, false
	}
	t, err := time.ParseInLocation("2006-01-02", expiry, mustLoadLocation("Asia/Dubai"))
	if err != nil {
		return time.Time{}, false
	}
	return t, true
}
