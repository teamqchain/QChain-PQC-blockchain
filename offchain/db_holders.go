package main

// db_holders.go — MySQL access for the `holders` table.
//
// A holder's name and public keys live on-chain (see chain.go); MySQL supplies
// what the chain does not have: the Emirates ID → holder mapping, email, holder
// type and college. first_name/last_name/kem_public_key/dsa_public_key are
// still written as a cache copy but never read back, except by the one-shot
// chain bootstrap (bootstrap.go).

import (
	"database/sql"
	"fmt"
)

// holderByEmiratesID looks up a holder by their UAE Emirates ID.
// Returns the MySQL display holder_id and the fabric_holder_id (blockchain key).
func holderByEmiratesID(emiratesID string) (holderID, fabricHolderID string, err error) {
	if db == nil {
		return "", "", fmt.Errorf("database not configured — set MYSQL_DSN")
	}
	row := db.QueryRow(
		`SELECT holder_id, fabric_holder_id FROM holders WHERE emirates_id = ?`,
		emiratesID,
	)
	err = row.Scan(&holderID, &fabricHolderID)
	if err == sql.ErrNoRows {
		return "", "", fmt.Errorf("Emirates ID %q not registered", emiratesID)
	}
	return
}

// HolderRef is the MySQL-only side of a holder.
type HolderRef struct {
	HolderID       string
	FabricHolderID string
	Email          string
	EmiratesID     string
	HolderType     string // raw DB enum (bachelor_student, …) or ""
	College        string
}

const holderRefSelect = `
	SELECT holder_id, fabric_holder_id,
	       COALESCE(email, '') AS email,
	       emirates_id,
	       COALESCE(holder_type, '') AS holder_type,
	       COALESCE(college, '') AS college
	  FROM holders`

func scanHolderRef(sc interface{ Scan(...any) error }) (HolderRef, error) {
	var r HolderRef
	err := sc.Scan(&r.HolderID, &r.FabricHolderID, &r.Email, &r.EmiratesID, &r.HolderType, &r.College)
	return r, err
}

// holderRefByEmiratesID returns one holder's MySQL-only details. The error
// mentions "not registered" when the Emirates ID is unknown.
func holderRefByEmiratesID(emiratesID string) (HolderRef, error) {
	if db == nil {
		return HolderRef{}, fmt.Errorf("database not configured — set MYSQL_DSN")
	}
	r, err := scanHolderRef(db.QueryRow(holderRefSelect+` WHERE emirates_id = ?`, emiratesID))
	if err == sql.ErrNoRows {
		return r, fmt.Errorf("Emirates ID %q not registered", emiratesID)
	}
	return r, err
}

// listHolderRefs returns every holder, optionally filtered by the raw DB
// holder_type. Name search and ordering happen in Go on the on-chain names.
func listHolderRefs(typeFilterDB string) ([]HolderRef, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	query := holderRefSelect
	args := []any{}
	if typeFilterDB != "" {
		query += ` WHERE holder_type = ?`
		args = append(args, typeFilterDB)
	}
	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []HolderRef{}
	for rows.Next() {
		r, err := scanHolderRef(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// holderContactByFabricID returns the email and Emirates ID of the holder with
// the given on-chain ID (both are MySQL-only). Missing holder → empty strings.
func holderContactByFabricID(fabricHolderID string) (email, emiratesID string, err error) {
	if db == nil || fabricHolderID == "" {
		return "", "", nil
	}
	var em, eid sql.NullString
	err = db.QueryRow(
		`SELECT email, emirates_id FROM holders WHERE fabric_holder_id = ?`, fabricHolderID,
	).Scan(&em, &eid)
	if err == sql.ErrNoRows {
		return "", "", nil
	}
	return em.String, eid.String, err
}

// insertHolder saves a new holder row into MySQL.
// Called by handleRegisterHolder (setup script path). holderID is always
// server-generated, so a plain INSERT is correct — a collision here would be
// a real bug (not a legitimate re-registration) and should fail loudly rather
// than silently overwrite an existing holder's identity.
func insertHolder(holderID, emiratesID, firstName, lastName string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`INSERT INTO holders (holder_id, emirates_id, first_name, last_name, fabric_holder_id, is_wallet_activated)
		 VALUES (?, ?, ?, ?, ?, FALSE)`,
		holderID, emiratesID, firstName, lastName, holderID,
	)
	return err
}

// updateHolderKeys caches the holder's public keys (the chain copy is the one
// that is read) and marks the wallet activated.
func updateHolderKeys(holderID, kemPublicKey, dsaPublicKey string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`UPDATE holders
		    SET kem_public_key = ?, dsa_public_key = ?, is_wallet_activated = TRUE
		  WHERE holder_id = ?`,
		kemPublicKey, dsaPublicKey, holderID,
	)
	return err
}

// HolderSeedRow is what the one-shot chain bootstrap copies from MySQL.
type HolderSeedRow struct {
	FabricHolderID string
	FirstName      string
	LastName       string
	KemPublicKey   string
	DsaPublicKey   string
}

// listHolderSeeds returns every holder's cached name and keys. Used only by
// runChainBootstrap to re-create holders on a freshly reset ledger.
func listHolderSeeds() ([]HolderSeedRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	rows, err := db.Query(`
		SELECT fabric_holder_id,
		       COALESCE(first_name, ''), COALESCE(last_name, ''),
		       COALESCE(kem_public_key, ''), COALESCE(dsa_public_key, '')
		  FROM holders
		 ORDER BY holder_id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []HolderSeedRow{}
	for rows.Next() {
		var r HolderSeedRow
		if err := rows.Scan(&r.FabricHolderID, &r.FirstName, &r.LastName, &r.KemPublicKey, &r.DsaPublicKey); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
