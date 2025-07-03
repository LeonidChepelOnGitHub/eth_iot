# Clique PoA Network Setup Documentation

This documentation explains how to configure and run a 4-node Ethereum Clique Proof-of-Authority network using Go-Ethereum 1.13.

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Network Architecture](#network-architecture)
4. [Genesis Configuration](#genesis-configuration)
5. [Docker Configuration](#docker-configuration)
6. [Clique Consensus Specifics](#clique-consensus-specifics)
7. [Network Deployment](#network-deployment)
8. [Verification and Testing](#verification-and-testing)
9. [Troubleshooting](#troubleshooting)

## Overview

This setup creates a private Ethereum network using Clique Proof-of-Authority consensus with:
- 4 nodes total
- 3 signing/sealing nodes (authorities)
- 1 non-signing participant node
- HTTP RPC and WebSocket endpoints on all nodes
- Edgeshark network monitoring integration

## Prerequisites

- Docker and Docker Compose
- Go-Ethereum 1.13 source code
- Basic understanding of Ethereum and blockchain concepts

## Network Architecture

### Node Configuration
| Node | Container | HTTP Port | P2P Port | Role | Etherbase |
|------|-----------|-----------|----------|------|-----------|
| geth-node1 | geth-node1 | 8545 | 30303 | Signer/Miner | 0x38d7ff8ef1bdda255caa19bb065802455783b2ee |
| geth-node2 | geth-node2 | 8546 | 30304 | Signer/Miner | 0xb366491ccb18b83b999aa6f9ebbc41e9d0fc6976 |
| geth-node3 | geth-node3 | 8547 | 30305 | Signer/Miner | 0xd71b40374e9d93bf0e1efd38f253d246014d1b60 |
| geth-node4 | geth-node4 | 8548 | 30306 | Participant | Non-mining |

### Network Settings
- **Network ID**: 1337
- **Chain ID**: 1337
- **Block Period**: 15 seconds
- **Epoch Length**: 30000 blocks
- **Subnet**: 172.20.0.0/16

## Genesis Configuration

### Key Components of genesis.json

```json
{
  "config": {
    "chainId": 1337,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "clique": {
      "period": 15,
      "epoch": 30000
    }
  },
  "extraData": "0x000000000000000000000000000000000000000000000000000000000000000038d7ff8ef1bdda255caa19bb065802455783b2eeb366491ccb18b83b999aa6f9ebbc41e9d0fc6976d71b40374e9d93bf0e1efd38f253d246014d1b6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "alloc": {
    "38d7ff8ef1bdda255caa19bb065802455783b2ee": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
    "b366491ccb18b83b999aa6f9ebbc41e9d0fc6976": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
    "d71b40374e9d93bf0e1efd38f253d246014d1b60": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
```

### ExtraData Format for Clique

The `extraData` field in Clique has a specific format:
```
0x + 32_bytes_vanity + N*20_bytes_addresses + 65_bytes_signature
```

Breaking down our extraData:
- **Vanity (32 bytes)**: `000000000000000000000000000000000000000000000000000000000000000`
- **Signers (3 × 20 bytes)**:
  - `38d7ff8ef1bdda255caa19bb065802455783b2ee` (node1)
  - `b366491ccb18b83b999aa6f9ebbc41e9d0fc6976` (node2)  
  - `d71b40374e9d93bf0e1efd38f253d246014d1b60` (node3)
- **Signature (65 bytes)**: `000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000`

**Important**: The total length must be even (valid hex string).

## Docker Configuration

### Dockerfile
The Dockerfile builds geth from Go-Ethereum 1.13 source:

```dockerfile
FROM golang:1.20-alpine AS builder
RUN apk add --no-cache make gcc musl-dev linux-headers git
WORKDIR /app
COPY go-ethereum .
RUN make all

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/build/bin/geth /usr/local/bin/
COPY --from=builder /app/build/bin/bootnode /usr/local/bin/
```

### Key Docker Compose Configuration

#### Node 1 (Bootstrap Node)
```yaml
geth-node1:
  build: .
  container_name: geth-node1
  ports:
    - "8545:8545"
    - "30303:30303"
  command: |
    sh -c "
      if [ ! -d /root/.ethereum/geth ]; then
        geth --datadir /root/.ethereum init /root/genesis.json
      fi
      geth --datadir /root/.ethereum 
      --networkid 1337 
      --port 30303 
      --http 
      --http.addr 0.0.0.0 
      --http.port 8545 
      --http.api eth,net,web3,personal,miner,clique,admin 
      --http.corsdomain '*' 
      --http.vhosts '*' 
      --ws 
      --ws.addr 0.0.0.0 
      --ws.port 8546 
      --ws.api eth,net,web3,personal,miner,clique,admin 
      --ws.origins '*' 
      --mine 
      --miner.etherbase 0x38d7ff8ef1bdda255caa19bb065802455783b2ee 
      --authrpc.addr 0.0.0.0 
      --authrpc.port 8551 
      --authrpc.vhosts '*' 
      --verbosity 4
    "
```

#### Peer Nodes (2-4)
Similar configuration with:
- Different port mappings
- `--bootnodes` flag pointing to node1
- Different `--miner.etherbase` addresses
- Node 4 without `--mine` flag

## Clique Consensus Specifics

### Authority Management

**Initial Authorities**: Defined in genesis extraData
- Node 1: `0x38d7ff8ef1bdda255caa19bb065802455783b2ee`
- Node 2: `0xb366491ccb18b83b999aa6f9ebbc41e9d0fc6976`
- Node 3: `0xd71b40374e9d93bf0e1efd38f253d246014d1b60`

**Adding/Removing Authorities**: Use clique API calls
```javascript
// Add authority
clique.propose("0xnewauthorityaddress", true)

// Remove authority  
clique.propose("0xauthoritytoremove", false)
```

### Block Signing Rules

1. **Round-robin signing**: Authorities take turns signing blocks
2. **Signing frequency**: Each authority can sign 1 out of every `floor(signers/2) + 1` blocks
3. **Consecutive signing**: An authority cannot sign two consecutive blocks
4. **Block period**: New block every 15 seconds (configurable)

### Network Security

**Byzantine Fault Tolerance**: 
- Can tolerate up to `floor((N-1)/2)` malicious authorities
- With 3 authorities: can tolerate 1 malicious node
- Minimum 1 honest authority needed for progress

**Attack Resistance**:
- **51% Attack**: Not applicable (PoA consensus)
- **Long-range Attack**: Mitigated by checkpointing
- **Nothing-at-stake**: Not applicable (selected authorities)

## Network Deployment

### Step 1: Build and Start
```bash
# Build the Docker images and start the network
docker-compose up -d

# Check all nodes are running
docker ps
```

### Step 2: Verify Network Status
```bash
# Check node 1 status
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:8545

# Check peer connections
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://127.0.0.1:8545
```

### Step 3: Verify Clique Status
```bash
# Connect to geth console
docker exec -it geth-node1 geth attach /root/.ethereum/geth.ipc

# Check clique status
> clique.status()
> clique.getSigners()
> admin.peers
```

## Verification and Testing

### RPC Endpoint Testing
```bash
# Test all HTTP RPC endpoints
for port in 8545 8546 8547 8548; do
  echo "Testing port $port:"
  curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://127.0.0.1:$port
  echo
done
```

### WebSocket Testing
```bash
# Test WebSocket connection (using wscat if available)
wscat -c ws://localhost:8546
```

### Network Health Checks
```bash
# Check mining activity
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' \
  http://127.0.0.1:8545

# Check block production
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  http://127.0.0.1:8545
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Nodes Not Starting
**Symptoms**: Containers exit immediately
**Causes**: 
- Invalid geth flags
- Genesis configuration errors
- Port conflicts

**Solutions**:
```bash
# Check container logs
docker logs geth-node1

# Common flag issues in geth 1.13:
# - Remove --miner.threads (deprecated)
# - Use --verbosity instead of --log.level
# - Ensure extraData has even length hex string
```

#### 2. HTTP RPC Not Accessible
**Symptoms**: Connection refused on RPC ports
**Causes**:
- Incorrect HTTP configuration
- Command syntax errors

**Solutions**:
```bash
# Verify HTTP server is starting
docker logs geth-node1 | grep "HTTP server started"

# Check correct flag format:
--http
--http.addr 0.0.0.0
--http.port 8545
```

#### 3. Nodes Not Connecting
**Symptoms**: Zero peers, no block synchronization
**Causes**:
- Incorrect bootnode configuration
- Network connectivity issues
- Different genesis configurations

**Solutions**:
```bash
# Check peer connections
docker exec geth-node1 geth attach --exec "admin.peers" /root/.ethereum/geth.ipc

# Verify enode addresses
docker exec geth-node1 geth attach --exec "admin.nodeInfo.enode" /root/.ethereum/geth.ipc
```

#### 4. Mining Not Working
**Symptoms**: Block number stays at 0
**Causes**:
- Accounts not unlocked
- Invalid miner configuration
- Insufficient authorities

**Solutions**:
```bash
# Check mining status
docker exec geth-node1 geth attach --exec "eth.mining" /root/.ethereum/geth.ipc

# For PoA, ensure signers are properly configured:
docker exec geth-node1 geth attach --exec "clique.getSigners()" /root/.ethereum/geth.ipc
```

### Log Analysis

#### Successful Startup Indicators
```
INFO [timestamp] HTTP server started    endpoint=[::]:8545 auth=false
INFO [timestamp] WebSocket enabled      url=ws://127.0.0.1:8546
INFO [timestamp] Started P2P networking self=enode://...
```

#### Clique-Specific Logs
```
INFO [timestamp] Consensus: Clique (proof-of-authority)
INFO [timestamp] Looking for peers     peercount=N
```

### Performance Tuning

#### Optimizing Block Time
```javascript
// Adjust in genesis.json
"clique": {
  "period": 15,    // Seconds between blocks
  "epoch": 30000   // Blocks between authority votes
}
```

#### Resource Allocation
```yaml
# In docker-compose.yml, add resource limits
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
```

## Advanced Configuration

### Adding Monitoring
Integration with Edgeshark for network monitoring:
```bash
# Start Edgeshark monitoring
cd edgeshark && docker-compose up -d

# Access web interface
open http://localhost:5001
```

### Custom Network Parameters
Modify `genesis.json` for different network characteristics:
- **Chain ID**: Change for network isolation
- **Block time**: Adjust clique.period
- **Initial balances**: Modify alloc section
- **Hard fork blocks**: Set activation blocks

### Smart Contract Deployment
Ready for IoT smart contract deployment:
```javascript
// Example deployment
const contract = await web3.eth.contract(abi).new(
  constructorArgs,
  { from: account, gas: 3000000 }
);
```

## Security Considerations

1. **Private Keys**: Never expose private keys in production
2. **Network Access**: Restrict RPC access in production environments
3. **Authority Management**: Carefully manage authority addition/removal
4. **Monitoring**: Implement comprehensive logging and monitoring
5. **Updates**: Keep geth version updated for security patches

This documentation provides a complete guide for setting up and managing the 4-node Clique PoA network for IoT blockchain applications.