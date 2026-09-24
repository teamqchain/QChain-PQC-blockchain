package main

// bootstrap.go — one-shot migration that re-creates holders on a freshly
// reset ledger from MySQL's cached copy.
//
// After the v2.0 full ledger reset the chain is empty, but MySQL still holds
// every registered holder with the name and wallet public keys it cached. Run
// once, before starting the server normally:
//
//	RUN_CHAIN_BOOTSTRAP=1 <your normal backend start command>
//
// For each holder it calls registerHolder when the holder is not on-chain, and
// bindHolderKeys when MySQL has both keys and the chain does not yet have
// those exact keys. It is idempotent: re-running it skips work already done.
// This is the ONLY code that reads names/keys from MySQL, and only to seed the
// chain; every normal read path uses the chain.

import (
	"errors"
	"log"
)

func runChainBootstrap() {
	seeds, err := listHolderSeeds()
	if err != nil {
		log.Fatalf("bootstrap: read holders from MySQL: %v", err)
	}
	log.Printf("bootstrap: %d holder(s) in MySQL", len(seeds))

	var registered, bound, skipped, failed int
	for _, s := range seeds {
		holder, err := chainReadHolder(s.FabricHolderID, viewFull)
		switch {
		case errors.Is(err, errChainNotFound):
			if s.FirstName == "" || s.LastName == "" {
				log.Printf("bootstrap: %s: skipped — MySQL has no first/last name to register", s.FabricHolderID)
				failed++
				continue
			}
			if _, err := chainSubmit("registerHolder", s.FabricHolderID, s.FirstName, s.LastName); err != nil {
				log.Printf("bootstrap: %s: registerHolder failed: %v", s.FabricHolderID, err)
				failed++
				continue
			}
			registered++
			holder = &ChainHolder{ID: s.FabricHolderID}
		case err != nil:
			log.Fatalf("bootstrap: chain read for %s failed (is Fabric up?): %v", s.FabricHolderID, err)
		}

		if s.KemPublicKey == "" || s.DsaPublicKey == "" {
			skipped++ // wallet never activated — the holder registers keys from QWallet later
			continue
		}
		if holder.KemPublicKey == s.KemPublicKey && holder.DsaPublicKey == s.DsaPublicKey {
			skipped++
			continue
		}
		if _, err := chainSubmit("bindHolderKeys", s.FabricHolderID, s.KemPublicKey, s.DsaPublicKey); err != nil {
			log.Printf("bootstrap: %s: bindHolderKeys failed: %v", s.FabricHolderID, err)
			failed++
			continue
		}
		bound++
	}
	log.Printf("bootstrap: done. registered=%d keysBound=%d unchanged/no-keys=%d failed=%d",
		registered, bound, skipped, failed)
	if failed > 0 {
		log.Fatalf("bootstrap: %d holder(s) failed — fix the errors above and re-run (it is safe to repeat)", failed)
	}
}
