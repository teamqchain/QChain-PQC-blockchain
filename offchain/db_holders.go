package main

// db_holders.go — all MySQL access for the `holders` table: look up by Emirates
// ID, insert, fetch display name/contact info, and the searchable holder list.

import (
	"database/sql"
	"fmt"
	"strings"
)

// HolderRow is the projection used by /getHolders responses.
type HolderRow struct {
	HolderID   string
	FullName   string
	Email      string
	EmiratesID string
	HolderType string
	College    string
}

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

// insertHolder saves a new holder row into MySQL.
// Called by handleRegisterHolder (setup script path).
func insertHolder(holderID, emiratesID, firstName, lastName string) error {
	if db == nil {
		return fmt.Errorf("database not configured")
	}
	_, err := db.Exec(
		`INSERT INTO holders (holder_id, emirates_id, first_name, last_name, fabric_holder_id, is_wallet_activated)
		 VALUES (?, ?, ?, ?, ?, FALSE)
		 ON DUPLICATE KEY UPDATE first_name = VALUES(first_name), last_name = VALUES(last_name)`,
		holderID, emiratesID, firstName, lastName, holderID,
	)
	return err
}

// holderNameByID returns "FirstName LastName" for the given holder_id.
func holderNameByID(holderID string) (string, error) {
	if db == nil || holderID == "" {
		return holderID, nil
	}
	var first, last string
	row := db.QueryRow(`SELECT first_name, last_name FROM holders WHERE holder_id = ?`, holderID)
	if err := row.Scan(&first, &last); err != nil {
		return holderID, err
	}
	return fmt.Sprintf("%s %s", first, last), nil
}

// holderInfoByID returns the holder's full name, email, and Emirates ID.
// Used to enrich verifyCredential responses with display fields.
func holderInfoByID(holderID string) (fullName, email, emiratesID string, err error) {
	if db == nil || holderID == "" {
		return "", "", "", nil
	}
	var first, last, em, eid sql.NullString
	row := db.QueryRow(
		`SELECT first_name, last_name, email, emirates_id FROM holders WHERE holder_id = ?`,
		holderID,
	)
	if err = row.Scan(&first, &last, &em, &eid); err != nil {
		return "", "", "", err
	}
	fullName = strings.TrimSpace(first.String + " " + last.String)
	email = em.String
	emiratesID = eid.String
	return
}

// searchHolders runs a LIKE search against full_name/emirates_id/email with optional type filter.
// `typeFilterDB` is the raw DB ENUM value (bachelor_student, etc.) — caller maps from camelCase.
func searchHolders(searchQuery, typeFilterDB string) ([]HolderRow, error) {
	if db == nil {
		return nil, fmt.Errorf("database not configured")
	}
	query := `
		SELECT holder_id,
		       CONCAT_WS(' ', first_name, last_name) AS full_name,
		       COALESCE(email, '') AS email,
		       emirates_id,
		       COALESCE(holder_type, '') AS holder_type,
		       COALESCE(college, '') AS college
		  FROM holders`
	conds := []string{}
	args := []any{}

	if searchQuery != "" {
		conds = append(conds, `(CONCAT_WS(' ', first_name, last_name) LIKE ?
		                       OR emirates_id LIKE ?
		                       OR email LIKE ?)`)
		like := "%" + searchQuery + "%"
		args = append(args, like, like, like)
	}
	if typeFilterDB != "" {
		conds = append(conds, `holder_type = ?`)
		args = append(args, typeFilterDB)
	}
	if len(conds) > 0 {
		query += ` WHERE ` + conds[0]
		for _, c := range conds[1:] {
			query += ` AND ` + c
		}
	}
	query += ` ORDER BY first_name, last_name ASC`

	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []HolderRow{}
	for rows.Next() {
		var r HolderRow
		if err := rows.Scan(&r.HolderID, &r.FullName, &r.Email, &r.EmiratesID, &r.HolderType, &r.College); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
