# Complete Manual: Creating a New Consensus Protocol Based on Clique

This manual provides step-by-step instructions for creating a new Proof-of-Authority consensus protocol in go-ethereum based on the Clique implementation, using the PoI (Proof of Interest) implementation as a reference.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step-by-Step Implementation](#step-by-step-implementation)
4. [Configuration and Integration](#configuration-and-integration)
5. [Testing and Deployment](#testing-and-deployment)
6. [Troubleshooting](#troubleshooting)

## Overview

Creating a new consensus protocol in go-ethereum involves:
- Copying and modifying the Clique consensus implementation
- Integrating the new consensus at multiple layers (core, backend, RPC, etc.)
- Updating configuration files and parameters
- Testing the implementation thoroughly

The approach is a systematic copy-and-modify strategy that ensures all integration points are properly handled.

## Prerequisites

- Go-ethereum source code
- Understanding of Proof-of-Authority consensus mechanisms
- Basic Go programming knowledge
- Docker for testing (optional but recommended)

## Step-by-Step Implementation

### Step 1: Create the Core Consensus Files

#### 1.1 Copy Clique Directory
```bash
# Copy the entire Clique consensus directory
cp -r consensus/clique/ consensus/mynewconsensus/
```

#### 1.2 Rename Package and Update Files

**File: `consensus/mynewconsensus/mynewconsensus.go`** (renamed from `clique.go`)
```go
package mynewconsensus

// Update all imports and references
import (
    // ... existing imports
)

// Change main struct name
type MyNewConsensus struct {
    config *params.MyNewConsensusConfig // Updated config type
    db     ethdb.Database
    // ... rest of the fields remain similar to Clique
}

// Update constructor
func New(config *params.MyNewConsensusConfig, db ethdb.Database) *MyNewConsensus {
    // Copy Clique's New() implementation and update types
}

// Update all method receivers
func (c *MyNewConsensus) Author(header *types.Header) (common.Address, error) {
    // Implementation remains same as Clique
}

// Continue for all methods: VerifyHeader, Prepare, Seal, etc.
```

#### 1.3 Update API File

**File: `consensus/mynewconsensus/api.go`**
```go
package mynewconsensus

type API struct {
    chain           consensus.ChainHeaderReader
    mynewconsensus  *MyNewConsensus  // Updated reference
}

// Update all API methods to use new consensus reference
func (api *API) GetSnapshot(number *rpc.BlockNumber) (*Snapshot, error) {
    // Implementation similar to Clique API
}

// Add consensus-specific API methods if needed
```

#### 1.4 Update Snapshot Management

**File: `consensus/mynewconsensus/snapshot.go`**
```go
package mynewconsensus

// Keep most of the snapshot logic from Clique
// Update any consensus-specific voting or validation rules here
```

### Step 2: Add Configuration Parameters

#### 2.1 Update Chain Configuration

**File: `params/config.go`**
```go
// Add your consensus config to ChainConfig struct
type ChainConfig struct {
    ChainID *big.Int `json:"chainId"`
    // ... existing fields
    Clique           *CliqueConfig           `json:"clique,omitempty"`
    MyNewConsensus   *MyNewConsensusConfig   `json:"mynewconsensus,omitempty"`
}

// Define your consensus configuration
type MyNewConsensusConfig struct {
    Period uint64 `json:"period"` // Time between blocks
    Epoch  uint64 `json:"epoch"`  // Epoch length for checkpoints
    // Add any custom parameters for your consensus
}

// Add test configuration
var (
    // ... existing test configs
    AllMyNewConsensusProtocolChanges = &ChainConfig{
        ChainID:        big.NewInt(1337),
        HomesteadBlock: big.NewInt(0),
        EIP150Block:    big.NewInt(0),
        EIP155Block:    big.NewInt(0),
        EIP158Block:    big.NewInt(0),
        ByzantiumBlock: big.NewInt(0),
        ConstantinopleBlock: big.NewInt(0),
        PetersburgBlock:     big.NewInt(0),
        IstanbulBlock:       big.NewInt(0),
        BerlinBlock:         big.NewInt(0),
        LondonBlock:         big.NewInt(0),
        MyNewConsensus: &MyNewConsensusConfig{
            Period: 5,
            Epoch:  30000,
        },
    }
)
```

### Step 3: Database Integration

#### 3.1 Add Database Schema

**File: `core/rawdb/schema.go`**
```go
var (
    // ... existing prefixes
    CliqueSnapshotPrefix      = []byte("clique-")
    MyNewConsensusSnapshotPrefix = []byte("mynewconsensus-")
)
```

### Step 4: Cryptographic Integration

#### 4.1 Add MIME Type

**File: `accounts/accounts.go`**
```go
const (
    MimetypeDataWithValidator = "data/validator"
    MimetypeTypedData         = "data/typed"
    MimetypeClique            = "application/x-clique-header"
    MimetypeMyNewConsensus    = "application/x-mynewconsensus-header"
    MimetypeTextPlain         = "text/plain"
)
```

#### 4.2 Update Consensus Engine Signing

**In your consensus implementation, update the signing calls:**
```go
// In your Seal() method
sighash, err := signFn(accounts.Account{Address: signer}, accounts.MimetypeMyNewConsensus, MyNewConsensusRLP(header))
```

### Step 5: Engine Creation and Integration

#### 5.1 Update Engine Factory

**File: `eth/ethconfig/config.go`**
```go
// Add import
import (
    "github.com/ethereum/go-ethereum/consensus/mynewconsensus"
)

// Update CreateConsensusEngine function
func CreateConsensusEngine(config *params.ChainConfig, db ethdb.Database) (consensus.Engine, error) {
    // ... existing engines
    if config.Clique != nil {
        return beacon.New(clique.New(config.Clique, db)), nil
    }
    if config.MyNewConsensus != nil {
        return beacon.New(mynewconsensus.New(config.MyNewConsensus, db)), nil
    }
    // ... other engines
}
```

#### 5.2 Backend Integration

**File: `eth/backend.go`**
```go
// Add import
import (
    "github.com/ethereum/go-ethereum/consensus/mynewconsensus"
)

// In StartMining() function, add engine detection and authorization
func (s *Ethereum) StartMining() error {
    // ... existing code
    
    var cli *clique.Clique
    var myNewConsensusEngine *mynewconsensus.MyNewConsensus
    
    if c, ok := s.engine.(*clique.Clique); ok {
        cli = c
    } else if m, ok := s.engine.(*mynewconsensus.MyNewConsensus); ok {
        myNewConsensusEngine = m
    } else if cl, ok := s.engine.(*beacon.Beacon); ok {
        if c, ok := cl.InnerEngine().(*clique.Clique); ok {
            cli = c
        } else if m, ok := cl.InnerEngine().(*mynewconsensus.MyNewConsensus); ok {
            myNewConsensusEngine = m
        }
    }
    
    // Authorization for your consensus
    if myNewConsensusEngine != nil {
        wallet, err := s.accountManager.Find(accounts.Account{Address: eb})
        if wallet == nil || err != nil {
            log.Error("Etherbase account unavailable locally", "err", err)
            return fmt.Errorf("signer missing: %v", err)
        }
        myNewConsensusEngine.Authorize(eb, wallet.SignData)
    }
    
    // ... rest of the function
}

// Add deadlock prevention logic in shouldPreserve()
func (s *Ethereum) shouldPreserve(header *types.Header) bool {
    // ... existing checks
    if _, ok := s.engine.(*mynewconsensus.MyNewConsensus); ok {
        return false  // Prevent deadlock similar to Clique
    }
    return s.isLocalBlock(header)
}
```

### Step 6: RPC API Integration

#### 6.1 Web3 JavaScript Extensions

**File: `internal/web3ext/web3ext.go`**
```go
// Add JavaScript extension
const MyNewConsensusJs = `
web3._extend({
    property: 'mynewconsensus',
    methods: [
        new web3._extend.Method({
            name: 'getSnapshot',
            call: 'mynewconsensus_getSnapshot',
            params: 1,
            inputFormatter: [web3._extend.formatters.inputBlockNumberFormatter]
        }),
        new web3._extend.Method({
            name: 'getSnapshotAtHash',
            call: 'mynewconsensus_getSnapshotAtHash',
            params: 1
        }),
        new web3._extend.Method({
            name: 'getSigners',
            call: 'mynewconsensus_getSigners',
            params: 1,
            inputFormatter: [web3._extend.formatters.inputBlockNumberFormatter]
        }),
        new web3._extend.Method({
            name: 'getSignersAtHash',
            call: 'mynewconsensus_getSignersAtHash',
            params: 1
        }),
        new web3._extend.Method({
            name: 'propose',
            call: 'mynewconsensus_propose',
            params: 2
        }),
        new web3._extend.Method({
            name: 'discard',
            call: 'mynewconsensus_discard',
            params: 1
        }),
        new web3._extend.Method({
            name: 'getSigner',
            call: 'mynewconsensus_getSigner',
            params: 1,
            inputFormatter: [null]
        }),
        new web3._extend.Method({
            name: 'status',
            call: 'mynewconsensus_status',
            params: 0
        }),
    ],
    properties: [
        new web3._extend.Property({
            name: 'proposals',
            getter: 'mynewconsensus_proposals'
        }),
    ]
});
`

// Update Modules map
var Modules = map[string]string{
    "admin":    AdminJs,
    "chequebook": ChequebookJs,
    "clique":   CliqueJs,
    "mynewconsensus": MyNewConsensusJs,  // Add your consensus
    "debug":    DebugJs,
    "eth":      EthJs,
    "miner":    MinerJs,
    "net":      NetJs,
    "personal": PersonalJs,
    "rpc":      RpcJs,
    "txpool":   TxpoolJs,
    "les":      LESJs,
    "vflux":    VfluxJs,
}
```

### Step 7: Genesis File Configuration

#### 7.1 Create Genesis File

**File: `genesis_mynewconsensus.json`**
```json
{
  "config": {
    "chainId": 1339,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "mynewconsensus": {
      "period": 5,
      "epoch": 30000
    }
  },
  "nonce": "0x0",
  "timestamp": "0x5ddf8f3e",
  "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000[SIGNER_ADDRESSES_HERE]0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "gasLimit": "0x47b760",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "address1": {
      "balance": "0x3635C9ADC5DEA00000"
    },
    "address2": {
      "balance": "0x3635C9ADC5DEA00000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
```

### Step 8: Docker Configuration

#### 8.1 Docker Compose Setup

**File: `docker-compose.yml`**
```yaml
geth-mynewconsensus-node1:
  build: .
  container_name: geth-mynewconsensus-node1
  ports:
    - "9545:8545"
    - "9549:8546"
    - "40303:30303"
  networks:
    - eth-network-mynewconsensus
  volumes:
    - ./data_mynewconsensus/node1:/root/.ethereum
    - ./keystore:/root/.ethereum/keystore
    - ./genesis_mynewconsensus.json:/root/genesis.json
    - ./scripts:/root/scripts
  command: >
    sh -c "
    if [ ! -d /root/.ethereum/geth ]; then
      geth --datadir /root/.ethereum init /root/genesis.json;
    fi;
    geth --datadir /root/.ethereum 
    --networkid 1339 
    --port 30303 
    --http 
    --http.addr 0.0.0.0 
    --http.port 8545 
    --http.api eth,net,web3,personal,miner,mynewconsensus,admin,debug 
    --http.corsdomain '*' 
    --http.vhosts '*' 
    --ws 
    --ws.addr 0.0.0.0 
    --ws.port 8546 
    --ws.api eth,net,web3,personal,mynewconsensus,admin,debug 
    --ws.origins '*' 
    --allow-insecure-unlock 
    --mine 
    --miner.etherbase 0xYOUR_SIGNER_ADDRESS 
    --unlock 0xYOUR_SIGNER_ADDRESS 
    --password /root/scripts/password.txt 
    --verbosity 4
    "
```

## Configuration and Integration

### Consensus-Specific Customizations

You can customize your consensus algorithm by modifying these key areas:

#### 1. Block Validation Rules
```go
// In verifyHeader() method
func (c *MyNewConsensus) verifyHeader(chain consensus.ChainHeaderReader, header *types.Header, parents []*types.Header) error {
    // Add custom validation logic here
    // Example: Custom timestamp validation
    // Example: Custom difficulty rules
    // Example: Custom extra data validation
}
```

#### 2. Difficulty Calculation
```go
// In CalcDifficulty() method
func (c *MyNewConsensus) CalcDifficulty(chain consensus.ChainHeaderReader, time uint64, parent *types.Header) *big.Int {
    // Implement custom difficulty calculation
    // Could be based on:
    // - Validator reputation
    // - Network conditions
    // - Custom algorithms
}
```

#### 3. Signer Selection Algorithm
```go
// In Prepare() and Seal() methods
func (c *MyNewConsensus) Prepare(chain consensus.ChainHeaderReader, header *types.Header) error {
    // Custom signer selection logic
    // Could implement:
    // - Round-robin with custom rules
    // - Weighted selection
    // - Reputation-based selection
}
```

#### 4. Voting Mechanisms
```go
// In snapshot.go, modify voting logic
func (snap *Snapshot) apply(headers []*types.Header) (*Snapshot, error) {
    // Custom voting rules
    // Could implement:
    // - Different voting thresholds
    // - Time-based voting
    // - Stake-based voting
}
```

## Testing and Deployment

### Testing Steps

1. **Unit Tests**
   ```bash
   go test ./consensus/mynewconsensus/...
   ```

2. **Integration Tests**
   ```bash
   # Test with Docker
   docker-compose up -d geth-mynewconsensus-node1
   
   # Test console access
   docker exec -it geth-mynewconsensus-node1 geth attach /root/.ethereum/geth.ipc
   ```

3. **API Testing**
   ```javascript
   // In Geth console
   mynewconsensus.getSigners()
   mynewconsensus.status()
   mynewconsensus.getSnapshot()
   ```

### Deployment Considerations

1. **Network ID**: Use unique network ID for your consensus
2. **Chain ID**: Use unique chain ID in genesis file
3. **Initial Validators**: Properly configure initial signers in extraData
4. **Port Configuration**: Avoid conflicts with existing networks
5. **Monitoring**: Set up logging and monitoring for your nodes

## Troubleshooting

### Common Issues

1. **API Not Available in Console**
   - Check if consensus engine is properly configured in genesis
   - Verify API is listed in --http.api and --ws.api flags
   - Ensure JavaScript extension is properly registered

2. **Nodes Not Connecting**
   - Check bootnode configuration
   - Verify network IDs match
   - Check firewall and Docker network settings

3. **Blocks Not Being Produced**
   - Verify signer authorization in backend.go
   - Check if accounts are properly unlocked
   - Ensure consensus engine is active and mining

4. **Compilation Errors**
   - Check all import statements are updated
   - Verify all type references are consistent
   - Ensure all files are renamed and updated

### Debugging Tips

1. **Enable Verbose Logging**
   ```bash
   --verbosity 5 --vmodule consensus/*=6
   ```

2. **Check Engine Status**
   ```javascript
   admin.nodeInfo
   eth.getBlock("latest")
   miner.mining
   ```

3. **Monitor Logs**
   ```bash
   docker logs -f geth-mynewconsensus-node1
   ```

## Conclusion

This manual provides a comprehensive guide for creating a new consensus protocol based on Clique. The key to success is systematic copying and updating of all integration points while maintaining consistency across the entire codebase.

Remember to thoroughly test your implementation and consider the consensus-specific logic that makes your protocol unique. The modular architecture of go-ethereum makes it relatively straightforward to implement new consensus mechanisms following this approach.