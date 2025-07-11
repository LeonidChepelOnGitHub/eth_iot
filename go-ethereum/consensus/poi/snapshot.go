package poi

import (
	"bytes"
	"encoding/json"
	"sort"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/lru"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethdb"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"golang.org/x/exp/slices"
)

// Vote represents a single vote that an authorized signer made to modify the
// list of authorizations.
type Vote struct {
	Signer    common.Address `json:"signer"`    // Authorized signer that cast this vote
	Block     uint64         `json:"block"`     // Block number the vote was cast in (expire old votes)
	Address   common.Address `json:"address"`   // Account being voted on to change its authorization
	Authorize bool           `json:"authorize"` // Whether to authorize or deauthorize the voted account
}

// Tally is a simple vote tally to keep the current score of votes. Votes that
// go against the proposal aren't counted since it's equivalent to not voting.
type Tally struct {
	Authorize bool `json:"authorize"` // Whether the vote is about authorizing or kicking someone
	Votes     int  `json:"votes"`     // Number of votes until now wanting to pass the proposal
}

type sigLRU = lru.Cache[common.Hash, common.Address]

// SignerHealth represents the health status of a signer
type SignerHealth uint8

const (
	Healthy   SignerHealth = 0
	Unhealthy SignerHealth = 1
)

// Snapshot is the state of the authorization voting at a given point in time.
type Snapshot struct {
	config   *params.PoiConfig // Consensus engine parameters to fine tune behavior
	sigcache *sigLRU              // Cache of recent block signatures to speed up ecrecover

	Number      uint64                        `json:"number"`      // Block number where the snapshot was created
	Hash        common.Hash                   `json:"hash"`        // Block hash where the snapshot was created
	Signers     map[common.Address]struct{}   `json:"signers"`     // Set of authorized signers at this moment
	Recents     map[uint64]common.Address     `json:"recents"`     // Set of recent signers for spam protections
	Votes       []*Vote                       `json:"votes"`       // List of votes cast in chronological order
	Tally       map[common.Address]Tally      `json:"tally"`       // Current vote tally to avoid recalculating
	Health      map[common.Address]SignerHealth `json:"health"`      // Health status of each signer
	Performance map[common.Address]int64      `json:"performance"` // Performance metric for each signer
}

// newSnapshot creates a new snapshot with the specified startup parameters. This
// method does not initialize the set of recent signers, so only ever use if for
// the genesis block.
func newSnapshot(config *params.PoiConfig, sigcache *sigLRU, number uint64, hash common.Hash, signers []common.Address) *Snapshot {
	snap := &Snapshot{
		config:      config,
		sigcache:    sigcache,
		Number:      number,
		Hash:        hash,
		Signers:     make(map[common.Address]struct{}),
		Recents:     make(map[uint64]common.Address),
		Tally:       make(map[common.Address]Tally),
		Health:      make(map[common.Address]SignerHealth),
		Performance: make(map[common.Address]int64),
	}
	for _, signer := range signers {
		snap.Signers[signer] = struct{}{}
		snap.Health[signer] = Healthy        // Initialize all signers as healthy
		snap.Performance[signer] = 0          // Initialize performance to 0
	}
	return snap
}

// loadSnapshot loads an existing snapshot from the database.
func loadSnapshot(config *params.PoiConfig, sigcache *sigLRU, db ethdb.Database, hash common.Hash) (*Snapshot, error) {
	blob, err := db.Get(append(rawdb.PoiSnapshotPrefix, hash[:]...))
	if err != nil {
		return nil, err
	}
	snap := new(Snapshot)
	if err := json.Unmarshal(blob, snap); err != nil {
		return nil, err
	}
	snap.config = config
	snap.sigcache = sigcache

	return snap, nil
}

// store inserts the snapshot into the database.
func (s *Snapshot) store(db ethdb.Database) error {
	blob, err := json.Marshal(s)
	if err != nil {
		return err
	}
	return db.Put(append(rawdb.PoiSnapshotPrefix, s.Hash[:]...), blob)
}

// copy creates a deep copy of the snapshot, though not the individual votes.
func (s *Snapshot) copy() *Snapshot {
	cpy := &Snapshot{
		config:      s.config,
		sigcache:    s.sigcache,
		Number:      s.Number,
		Hash:        s.Hash,
		Signers:     make(map[common.Address]struct{}),
		Recents:     make(map[uint64]common.Address),
		Votes:       make([]*Vote, len(s.Votes)),
		Tally:       make(map[common.Address]Tally),
		Health:      make(map[common.Address]SignerHealth),
		Performance: make(map[common.Address]int64),
	}
	for signer := range s.Signers {
		cpy.Signers[signer] = struct{}{}
	}
	for block, signer := range s.Recents {
		cpy.Recents[block] = signer
	}
	for address, tally := range s.Tally {
		cpy.Tally[address] = tally
	}
	for address, health := range s.Health {
		cpy.Health[address] = health
	}
	for address, perf := range s.Performance {
		cpy.Performance[address] = perf
	}
	copy(cpy.Votes, s.Votes)

	return cpy
}

// validVote returns whether it makes sense to cast the specified vote in the
// given snapshot context (e.g. don't try to add an already authorized signer).
func (s *Snapshot) validVote(address common.Address, authorize bool) bool {
	_, signer := s.Signers[address]
	return (signer && !authorize) || (!signer && authorize)
}

// cast adds a new vote into the tally.
func (s *Snapshot) cast(address common.Address, authorize bool) bool {
	// Ensure the vote is meaningful
	if !s.validVote(address, authorize) {
		return false
	}
	// Cast the vote into an existing or new tally
	if old, ok := s.Tally[address]; ok {
		old.Votes++
		s.Tally[address] = old
	} else {
		s.Tally[address] = Tally{Authorize: authorize, Votes: 1}
	}
	return true
}

// uncast removes a previously cast vote from the tally.
func (s *Snapshot) uncast(address common.Address, authorize bool) bool {
	// If there's no tally, it's a dangling vote, just drop
	tally, ok := s.Tally[address]
	if !ok {
		return false
	}
	// Ensure we only revert counted votes
	if tally.Authorize != authorize {
		return false
	}
	// Otherwise revert the vote
	if tally.Votes > 1 {
		tally.Votes--
		s.Tally[address] = tally
	} else {
		delete(s.Tally, address)
	}
	return true
}

// apply creates a new authorization snapshot by applying the given headers to
// the original one.
func (s *Snapshot) apply(headers []*types.Header) (*Snapshot, error) {
	// Allow passing in no headers for cleaner code
	if len(headers) == 0 {
		return s, nil
	}
	// Sanity check that the headers can be applied
	for i := 0; i < len(headers)-1; i++ {
		if headers[i+1].Number.Uint64() != headers[i].Number.Uint64()+1 {
			return nil, errInvalidVotingChain
		}
	}
	if headers[0].Number.Uint64() != s.Number+1 {
		return nil, errInvalidVotingChain
	}
	// Iterate through the headers and create a new snapshot
	snap := s.copy()

	var (
		start  = time.Now()
		logged = time.Now()
	)
	for i, header := range headers {
		// Remove any votes on checkpoint blocks
		number := header.Number.Uint64()
		if number%s.config.Epoch == 0 {
			snap.Votes = nil
			snap.Tally = make(map[common.Address]Tally)
		}
		// Delete the oldest signer from the recent list to allow it signing again
		if limit := uint64(len(snap.Signers)/2 + 1); number >= limit {
			delete(snap.Recents, number-limit)
		}
		// Resolve the authorization key and check against signers
		signer, err := ecrecover(header, s.sigcache)
		if err != nil {
			return nil, err
		}
		if _, ok := snap.Signers[signer]; !ok {
			return nil, errUnauthorizedSigner
		}
		for _, recent := range snap.Recents {
			if recent == signer {
				return nil, errRecentlySigned
			}
		}
		snap.Recents[number] = signer

		// Header authorized, discard any previous votes from the signer
		for i, vote := range snap.Votes {
			if vote.Signer == signer && vote.Address == header.Coinbase {
				// Uncast the vote from the cached tally
				snap.uncast(vote.Address, vote.Authorize)

				// Uncast the vote from the chronological list
				snap.Votes = append(snap.Votes[:i], snap.Votes[i+1:]...)
				break // only one vote allowed
			}
		}
		// Tally up the new vote from the signer
		var authorize bool
		switch {
		case bytes.Equal(header.Nonce[:], nonceAuthVote):
			authorize = true
		case bytes.Equal(header.Nonce[:], nonceDropVote):
			authorize = false
		default:
			return nil, errInvalidVote
		}
		if snap.cast(header.Coinbase, authorize) {
			snap.Votes = append(snap.Votes, &Vote{
				Signer:    signer,
				Block:     number,
				Address:   header.Coinbase,
				Authorize: authorize,
			})
		}
		// If the vote passed, update the list of signers
		if tally := snap.Tally[header.Coinbase]; tally.Votes > len(snap.Signers)/2 {
			if tally.Authorize {
				snap.Signers[header.Coinbase] = struct{}{}
				snap.Health[header.Coinbase] = Healthy       // New signers start as healthy
				snap.Performance[header.Coinbase] = 0        // New signers start with 0 performance
			} else {
				delete(snap.Signers, header.Coinbase)
				delete(snap.Health, header.Coinbase)         // Remove health tracking
				delete(snap.Performance, header.Coinbase)    // Remove performance tracking

				// Signer list shrunk, delete any leftover recent caches
				if limit := uint64(len(snap.Signers)/2 + 1); number >= limit {
					delete(snap.Recents, number-limit)
				}
				// Discard any previous votes the deauthorized signer cast
				for i := 0; i < len(snap.Votes); i++ {
					if snap.Votes[i].Signer == header.Coinbase {
						// Uncast the vote from the cached tally
						snap.uncast(snap.Votes[i].Address, snap.Votes[i].Authorize)

						// Uncast the vote from the chronological list
						snap.Votes = append(snap.Votes[:i], snap.Votes[i+1:]...)

						i--
					}
				}
			}
			// Discard any previous votes around the just changed account
			for i := 0; i < len(snap.Votes); i++ {
				if snap.Votes[i].Address == header.Coinbase {
					snap.Votes = append(snap.Votes[:i], snap.Votes[i+1:]...)
					i--
				}
			}
			delete(snap.Tally, header.Coinbase)
		}
		// If we're taking too much time (ecrecover), notify the user once a while
		if time.Since(logged) > 8*time.Second {
			log.Info("Reconstructing voting history", "processed", i, "total", len(headers), "elapsed", common.PrettyDuration(time.Since(start)))
			logged = time.Now()
		}
	}
	if time.Since(start) > 8*time.Second {
		log.Info("Reconstructed voting history", "processed", len(headers), "elapsed", common.PrettyDuration(time.Since(start)))
	}
	snap.Number += uint64(len(headers))
	snap.Hash = headers[len(headers)-1].Hash()

	return snap, nil
}

// signers retrieves the list of authorized signers in ascending order.
func (s *Snapshot) signers() []common.Address {
	sigs := make([]common.Address, 0, len(s.Signers))
	for sig := range s.Signers {
		sigs = append(sigs, sig)
	}
	slices.SortFunc(sigs, common.Address.Cmp)
	return sigs
}

// inturn returns if a signer at a given block height is in-turn or not.
func (s *Snapshot) inturn(number uint64, signer common.Address) bool {
	signers, offset := s.GetActiveSigners(), 0
	for offset < len(signers) && signers[offset] != signer {
		offset++
	}
	return (number % uint64(len(signers))) == uint64(offset)
}

// MarkHealthy marks a signer as healthy
func (s *Snapshot) MarkHealthy(signer common.Address) {
	if _, ok := s.Signers[signer]; ok {
		s.Health[signer] = Healthy
	}
}

// MarkUnhealthy marks a signer as unhealthy
func (s *Snapshot) MarkUnhealthy(signer common.Address) {
	if _, ok := s.Signers[signer]; ok {
		s.Health[signer] = Unhealthy
	}
}

// IsHealthy checks if a signer is healthy
func (s *Snapshot) IsHealthy(signer common.Address) bool {
	health, exists := s.Health[signer]
	return exists && health == Healthy
}

// SetPerformance sets the performance metric for a signer
func (s *Snapshot) SetPerformance(signer common.Address, performance int64) error {
	if _, ok := s.Signers[signer]; !ok {
		return errUnauthorizedSigner
	}
	if performance < 0 {
		return errInvalidPerformance
	}
	s.Performance[signer] = performance
	return nil
}

// GetPerformance returns the performance metric for a signer
func (s *Snapshot) GetPerformance(signer common.Address) int64 {
	return s.Performance[signer]
}

// SignerInfo holds signer address and performance for sorting
type SignerInfo struct {
	Address     common.Address
	Performance int64
}

// GetActiveSigners returns a list of healthy signers sorted by performance (desc) and address (asc)
func (s *Snapshot) GetActiveSigners() []common.Address {
	// Collect healthy signers with their performance
	var signerInfos []SignerInfo
	for signer := range s.Signers {
		if s.IsHealthy(signer) {
			signerInfos = append(signerInfos, SignerInfo{
				Address:     signer,
				Performance: s.GetPerformance(signer),
			})
		}
	}

	// Sort by performance (desc), then by address (asc)
	sort.Slice(signerInfos, func(i, j int) bool {
		if signerInfos[i].Performance != signerInfos[j].Performance {
			return signerInfos[i].Performance > signerInfos[j].Performance
		}
		return bytes.Compare(signerInfos[i].Address[:], signerInfos[j].Address[:]) < 0
	})

	// Extract sorted addresses
	result := make([]common.Address, len(signerInfos))
	for i, info := range signerInfos {
		result[i] = info.Address
	}
	return result
}

// GetBackupSigner returns the next backup signer for the given block number
// based on the sorted active signers pool. If the in-turn signer is not available,
// this method returns the next healthy signer in the sorted list.
func (s *Snapshot) GetBackupSigner(number uint64, inTurnSigner common.Address) (common.Address, bool) {
	activeSigners := s.GetActiveSigners()
	if len(activeSigners) == 0 {
		return common.Address{}, false
	}

	// Find the position of the in-turn signer in the active list
	inTurnIndex := -1
	for i, signer := range activeSigners {
		if signer == inTurnSigner {
			inTurnIndex = i
			break
		}
	}

	// If in-turn signer is not in active list (unhealthy), start from beginning
	if inTurnIndex == -1 {
		return activeSigners[0], true
	}

	// Return the next signer in the sorted list (wrap around if needed)
	nextIndex := (inTurnIndex + 1) % len(activeSigners)
	return activeSigners[nextIndex], true
}
