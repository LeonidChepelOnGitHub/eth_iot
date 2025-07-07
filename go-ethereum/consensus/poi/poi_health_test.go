package poi

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/params"
)

// TestSignerHealth tests the health status management of signers
func TestSignerHealth(t *testing.T) {
	// Create a new snapshot with test signers
	signers := []common.Address{
		common.HexToAddress("0x1111111111111111111111111111111111111111"),
		common.HexToAddress("0x2222222222222222222222222222222222222222"),
		common.HexToAddress("0x3333333333333333333333333333333333333333"),
	}
	
	config := &params.PoiConfig{
		Period: 15,
		Epoch:  30000,
	}
	
	snap := newSnapshot(config, nil, 0, common.Hash{}, signers)
	
	// Test initial health status
	for _, signer := range signers {
		if !snap.IsHealthy(signer) {
			t.Errorf("Signer %v should be healthy initially", signer)
		}
	}
	
	// Test marking unhealthy
	snap.MarkUnhealthy(signers[0])
	if snap.IsHealthy(signers[0]) {
		t.Errorf("Signer %v should be unhealthy after marking", signers[0])
	}
	
	// Test marking healthy again
	snap.MarkHealthy(signers[0])
	if !snap.IsHealthy(signers[0]) {
		t.Errorf("Signer %v should be healthy after marking", signers[0])
	}
	
	// Test non-existent signer
	nonSigner := common.HexToAddress("0x4444444444444444444444444444444444444444")
	if snap.IsHealthy(nonSigner) {
		t.Errorf("Non-signer %v should not be healthy", nonSigner)
	}
}

// TestSignerPerformance tests the performance metric management
func TestSignerPerformance(t *testing.T) {
	signers := []common.Address{
		common.HexToAddress("0x1111111111111111111111111111111111111111"),
		common.HexToAddress("0x2222222222222222222222222222222222222222"),
	}
	
	config := &params.PoiConfig{
		Period: 15,
		Epoch:  30000,
	}
	
	snap := newSnapshot(config, nil, 0, common.Hash{}, signers)
	
	// Test initial performance
	for _, signer := range signers {
		if perf := snap.GetPerformance(signer); perf != 0 {
			t.Errorf("Initial performance should be 0, got %d", perf)
		}
	}
	
	// Test setting performance
	err := snap.SetPerformance(signers[0], 100)
	if err != nil {
		t.Errorf("Failed to set performance: %v", err)
	}
	
	if perf := snap.GetPerformance(signers[0]); perf != 100 {
		t.Errorf("Performance should be 100, got %d", perf)
	}
	
	// Test negative performance
	err = snap.SetPerformance(signers[0], -10)
	if err == nil {
		t.Errorf("Should not allow negative performance")
	}
	
	// Test unauthorized signer
	nonSigner := common.HexToAddress("0x4444444444444444444444444444444444444444")
	err = snap.SetPerformance(nonSigner, 50)
	if err == nil {
		t.Errorf("Should not allow setting performance for non-signer")
	}
}

// TestGetActiveSigners tests the sorted active signers functionality
func TestGetActiveSigners(t *testing.T) {
	signers := []common.Address{
		common.HexToAddress("0x1111111111111111111111111111111111111111"),
		common.HexToAddress("0x2222222222222222222222222222222222222222"),
		common.HexToAddress("0x3333333333333333333333333333333333333333"),
		common.HexToAddress("0x4444444444444444444444444444444444444444"),
	}
	
	config := &params.PoiConfig{
		Period: 15,
		Epoch:  30000,
	}
	
	snap := newSnapshot(config, nil, 0, common.Hash{}, signers)
	
	// Set different performance values
	snap.SetPerformance(signers[0], 50)
	snap.SetPerformance(signers[1], 100)
	snap.SetPerformance(signers[2], 100)
	snap.SetPerformance(signers[3], 25)
	
	// Mark one as unhealthy
	snap.MarkUnhealthy(signers[3])
	
	// Get active signers
	active := snap.GetActiveSigners()
	
	// Should have 3 active signers (4 - 1 unhealthy)
	if len(active) != 3 {
		t.Errorf("Expected 3 active signers, got %d", len(active))
	}
	
	// Check sorting: should be sorted by performance desc, then address asc
	// signers[1] and signers[2] both have performance 100, so they should be sorted by address
	expectedOrder := []common.Address{signers[1], signers[2], signers[0]}
	if signers[2].Hex() < signers[1].Hex() {
		expectedOrder = []common.Address{signers[2], signers[1], signers[0]}
	}
	
	for i, expected := range expectedOrder {
		if active[i] != expected {
			t.Errorf("Active signer at position %d: expected %v, got %v", i, expected, active[i])
		}
	}
}

// TestGetBackupSigner tests the backup signer selection
func TestGetBackupSigner(t *testing.T) {
	signers := []common.Address{
		common.HexToAddress("0x1111111111111111111111111111111111111111"),
		common.HexToAddress("0x2222222222222222222222222222222222222222"),
		common.HexToAddress("0x3333333333333333333333333333333333333333"),
	}
	
	config := &params.PoiConfig{
		Period: 15,
		Epoch:  30000,
	}
	
	snap := newSnapshot(config, nil, 0, common.Hash{}, signers)
	
	// Set performance to ensure order
	snap.SetPerformance(signers[0], 100)
	snap.SetPerformance(signers[1], 50)
	snap.SetPerformance(signers[2], 25)
	
	// Test backup signer when in-turn is healthy
	backup, found := snap.GetBackupSigner(1, signers[0])
	if !found {
		t.Error("Should find backup signer")
	}
	if backup != signers[1] {
		t.Errorf("Expected backup signer %v, got %v", signers[1], backup)
	}
	
	// Test backup signer when in-turn is unhealthy
	snap.MarkUnhealthy(signers[0])
	backup, found = snap.GetBackupSigner(1, signers[0])
	if !found {
		t.Error("Should find backup signer")
	}
	// Should return first healthy signer (signers[1])
	if backup != signers[1] {
		t.Errorf("Expected backup signer %v, got %v", signers[1], backup)
	}
	
	// Test with all signers unhealthy
	snap.MarkUnhealthy(signers[1])
	snap.MarkUnhealthy(signers[2])
	_, found = snap.GetBackupSigner(1, signers[0])
	if found {
		t.Error("Should not find backup signer when all are unhealthy")
	}
}