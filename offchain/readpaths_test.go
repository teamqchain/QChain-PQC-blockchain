package main

// readpaths_test.go — the Go-side logic that replaced SQL on chain data:
// dashboard statistics and the fetchDocument LIKE matcher.

import (
	"testing"
	"time"
)

func TestCredentialStatsFromSnapshot(t *testing.T) {
	// 2026-09-24 10:30 in Dubai (a Thursday).
	now := time.Date(2026, 9, 24, 6, 30, 0, 0, time.UTC)
	cred := func(status, issuedAt, expiry, holder string) *ChainCredential {
		return &ChainCredential{Status: status, IssuedAt: issuedAt, ExpiryDate: expiry, Holder: holder, CredentialType: "BSc " + holder}
	}
	snap := &ChainSnapshot{
		Credentials: map[string]*ChainCredential{
			"a": cred("active", "2026-09-24T05:00:00Z", "2026-10-10", "H-1"),  // today; expiring in 16 days
			"b": cred("active", "2026-09-23T21:00:00Z", "2026-09-24", "H-2"),  // 01:00 today in Dubai; expires today
			"c": cred("active", "2026-09-23T19:00:00Z", "2020-01-01", "H-1"),  // 23:00 yesterday in Dubai; expired
			"d": cred("revoked", "2026-09-10T08:00:00Z", "2026-09-30", "H-2"), // revoked, not a warning
			"e": cred("suspended", "2026-09-17T08:00:00Z", "", "H-1"),         // exactly 7 days before today's midnight
			"f": cred("active", "2026-09-16T19:59:59Z", "2027-01-01", "H-2"),  // just before the 7-day window
			"g": cred("active", "2026-08-01T08:00:00Z", "2026-10-24", "H-1"),  // expiring in exactly 30 days
			"h": cred("active", "2026-08-01T08:00:00Z", "2026-10-25", "H-2"),  // 31 days — not a warning
		},
		Holders: map[string]*ChainHolder{
			"H-1": {FirstName: "Fatima", LastName: "Al Mansoori"},
			"H-2": {FirstName: "Rashid", LastName: "Khan"},
		},
	}
	s := credentialStatsFromSnapshot(snap, now)

	if s.TotalIssued != 8 || s.TotalRevoked != 1 || s.TotalSuspended != 1 || s.TotalExpired != 1 {
		t.Fatalf("counts: %+v", s)
	}
	if s.IssuedToday != 2 {
		t.Fatalf("issuedToday = %d, want 2 (a, b)", s.IssuedToday)
	}
	if s.ExpiringSoon != 3 || len(s.ExpiryWarnings) != 3 {
		t.Fatalf("expiringSoon = %d warnings = %+v", s.ExpiringSoon, s.ExpiryWarnings)
	}
	first := s.ExpiryWarnings[0]
	if first.Name != "Rashid Khan" || first.DaysLeft != 0 || first.Credential != "BSc H-2" {
		t.Fatalf("soonest warning = %+v", first)
	}
	if s.ExpiryWarnings[2].DaysLeft != 30 {
		t.Fatalf("last warning = %+v", s.ExpiryWarnings[2])
	}
	// Window = midnight 7 days before today (Thu 17 Sep 00:00 Dubai) → now.
	// Thu: a, b (today) and e (17 Sep); Wed: c (23 Sep 23:00 Dubai);
	// f (16 Sep 23:59:59 Dubai) falls just outside.
	if s.DailyIssued["Thu"] != 3 || s.DailyIssued["Wed"] != 1 || len(s.DailyIssued) != 2 {
		t.Fatalf("dailyIssued = %v", s.DailyIssued)
	}
}

func TestLikePattern(t *testing.T) {
	cases := []struct {
		pattern, value string
		want           bool
	}{
		{"%Bachelor%", "Bachelor of Science in Computer Science", true},
		{"%bachelor%", "BACHELOR OF ARTS", true},
		{"Bachelor%", "BSc Bachelor", false},
		{"%Master%", "Bachelor of Science", false},
		{"PhD _omputing", "PhD Computing", true},
		{"PhD _omputing", "PhD Coomputing", false},
		{"100\\% Scholarship", "100% Scholarship", true},
		{"100\\% Scholarship", "1000 Scholarship", false},
		{"%(Hons)%", "BSc (Hons) Computing", true},
		{"%", "", true},
	}
	for _, tc := range cases {
		re, err := likePattern(tc.pattern)
		if err != nil {
			t.Fatalf("likePattern(%q): %v", tc.pattern, err)
		}
		if got := re.MatchString(tc.value); got != tc.want {
			t.Errorf("LIKE %q on %q = %v, want %v", tc.pattern, tc.value, got, tc.want)
		}
	}
}
