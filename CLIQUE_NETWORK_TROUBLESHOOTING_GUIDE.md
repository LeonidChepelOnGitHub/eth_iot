# Clique PoA Network Setup & Troubleshooting Guide

## Overview

This guide documents the complete process for setting up a working Clique Proof-of-Authority Ethereum network with contract deployment capabilities using go-ethereum 1.13.

## Prerequisites

- Docker and Docker Compose
- Node.js and npm (for smart contracts)
- go-ethereum 1.13 source code
- Basic understanding of Ethereum and blockchain concepts

## Step-by-Step Setup Process

### 1. Project Structure

Ensure your project has the following structure:
```
eth_iot/
├── Dockerfile
├── docker-compose.yml
├── genesis.json
├── scripts/
│   ├── password.txt
│   ├── create-new-account.sh
│   └── account-info.txt
├── data/
│   ├── node1/keystore/
│   ├── node2/
│   ├── node3/
│   └── node4/
└── contracts/
    ├── package.json
    ├── deploy.js
    └── src/
```

### 2. Create Ethereum Account with Known Password

#### Script: `scripts/create-new-account.sh`

```bash
#!/bin/bash

echo "🔐 Creating new Ethereum account with geth"
echo "=========================================="

# Set password
PASSWORD="password123"
echo "$PASSWORD" > scripts/password.txt

# Remove old keystore if exists
sudo rm -f data/node1/keystore/* 2>/dev/null || true

echo "📁 Creating new account..."

# Create new account using geth in container
ACCOUNT_OUTPUT=$(docker run --rm -v $(pwd)/data/node1:/root/.ethereum -v $(pwd)/scripts:/root/scripts eth_iot-geth-node1 sh -c "
echo '$PASSWORD' | geth account new --datadir /root/.ethereum --password /dev/stdin
")

echo "Account creation output:"
echo "$ACCOUNT_OUTPUT"

# Extract address from output
ACCOUNT_ADDRESS=$(echo "$ACCOUNT_OUTPUT" | grep "Public address of the key:" | awk '{print $NF}')

if [ -z "$ACCOUNT_ADDRESS" ]; then
    echo "❌ Failed to create account"
    exit 1
fi

echo "✅ Account created successfully!"
echo "Address: $ACCOUNT_ADDRESS"
echo "Password: $PASSWORD"

# Save account info
cat > scripts/account-info.txt << EOL
# Ethereum Account Information
# Generated: $(date)

ADDRESS=$ACCOUNT_ADDRESS
PASSWORD=$PASSWORD

# Use this address in genesis.json extraData for Clique consensus
# Use this address for contract deployment
EOL

echo ""
echo "📝 Account information saved to scripts/account-info.txt"
echo ""
echo "Account Address: $ACCOUNT_ADDRESS"
echo "Password: $PASSWORD"
```

**Usage:**
```bash
chmod +x scripts/create-new-account.sh
./scripts/create-new-account.sh
```

### 3. Configure Genesis File

#### Critical Genesis.json Requirements

The genesis.json file must be configured correctly for Clique consensus:

```json
{
  "config": {
    "chainId": 1337,
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
    "clique": {
      "period": 5,
      "epoch": 30000
    }
  },
  "nonce": "0x0",
  "timestamp": "0x5ddf8f3e",
  "extraData": "0x0000000000000000000000000000000000000000000000000000000000000000[SIGNER_ADDRESSES_NO_0x]0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "gasLimit": "0x47b760",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "[account_address_lowercase_no_0x]": {
      "balance": "0x3635C9ADC5DEA00000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
```

#### Important Notes:

1. **extraData Format**: 
   - 32 bytes vanity data (zeros)
   - Signer addresses (20 bytes each, no 0x prefix, lowercase)
   - 65 bytes signature (zeros for genesis)

2. **alloc Format**:
   - Account addresses must be lowercase
   - No 0x prefix
   - Balance in hex format

### 4. Docker Compose Configuration

#### Key Requirements for docker-compose.yml:

```yaml
services:
  geth-node1:
    build: .
    container_name: geth-node1
    ports:
      - "8545:8545"
      - "30303:30303"
    networks:
      - eth-network
    volumes:
      - ./data/node1:/root/.ethereum
      - ./genesis.json:/root/genesis.json
      - ./scripts:/root/scripts
    command: >
      sh -c "
      if [ ! -d /root/.ethereum/geth ]; then
        geth --datadir /root/.ethereum init /root/genesis.json;
      fi;
      geth --datadir /root/.ethereum 
      --networkid 1337 
      --port 30303 
      --http 
      --http.addr 0.0.0.0 
      --http.port 8545 
      --http.api eth,net,web3,personal,miner,clique,admin,debug 
      --http.corsdomain '*' 
      --allow-insecure-unlock 
      --verbosity 4 
      --nodiscover
      "
```

### 5. Network Restart Procedure

When updating genesis.json or accounts, follow this complete restart procedure:

```bash
# 1. Stop all containers
docker-compose down

# 2. Remove all blockchain data (IMPORTANT!)
docker run --rm -v $(pwd)/data:/data alpine rm -rf /data/*/geth

# 3. Start network with fresh data
docker-compose up -d

# 4. Wait for network to initialize
sleep 15
```

### 6. Account Management and Mining Setup

#### Unlock Account for Transactions:

```bash
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["0x[ACCOUNT_ADDRESS]","password123",0],"id":1}' \
  http://127.0.0.1:8545
```

#### Set Mining Configuration:

```bash
# Set etherbase (mining reward recipient)
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"miner_setEtherbase","params":["0x[ACCOUNT_ADDRESS]"],"id":1}' \
  http://127.0.0.1:8545

# Start mining
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"miner_start","params":[],"id":1}' \
  http://127.0.0.1:8545
```

### 7. Contract Deployment Fixes

#### Fix BigInt Issues in deploy.js

The web3.js v4 returns BigInt values that need explicit conversion:

```javascript
// Fix gas estimate display
console.log(`Gas estimate: ${Number(gasEstimate)}`);

// Fix gas calculation
const deployedContract = await deployTx.send({
    from: fromAccount,
    gas: Math.min(Number(gasEstimate) * 2, CONFIG.gas.limit),
    gasPrice: CONFIG.gas.price
});

// Fix network info display
console.log(`Network ID: ${Number(networkId)}`);
console.log(`Current block: ${Number(blockNumber)}`);
console.log(`Gas price: ${Number(gasPrice)} wei`);
```

### 8. Verification Commands

#### Check Network Status:

```bash
# Check block number
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://127.0.0.1:8545

# Check account balance
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x[ACCOUNT_ADDRESS]","latest"],"id":1}' \
  http://127.0.0.1:8545

# List accounts
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' \
  http://127.0.0.1:8545

# Check Clique signers
curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"clique_getSigners","params":[],"id":1}' \
  http://127.0.0.1:8545
```

## Common Issues and Solutions

### Issue 1: Account Authentication Failed

**Error**: `Returned error: authentication needed: password or unlock`

**Solutions**:
1. Ensure account keystore exists in `data/node1/keystore/`
2. Verify password is correct in `scripts/password.txt`
3. Unlock account using personal_unlockAccount RPC call
4. Check account address matches exactly (case-sensitive)

### Issue 2: Insufficient Funds

**Error**: `insufficient funds for gas * price + value`

**Solutions**:
1. Verify account address in genesis.json alloc section (lowercase, no 0x)
2. Ensure balance is in hex format (e.g., "0x3635C9ADC5DEA00000")
3. Complete network restart to apply genesis changes
4. Check account balance with eth_getBalance

### Issue 3: BigInt Conversion Errors

**Error**: `Cannot mix BigInt and other types, use explicit conversions`

**Solution**: Convert BigInt values to Number:
```javascript
// Instead of: gasEstimate * 2
// Use: Number(gasEstimate) * 2
```

### Issue 4: Network Not Mining

**Symptoms**: Block number stays at 0

**Solutions**:
1. Ensure account is authorized in genesis.json extraData
2. Unlock the account
3. Set miner etherbase
4. Start mining explicitly
5. Check Clique signers list

### Issue 5: Genesis Not Applied

**Symptoms**: Wrong signer addresses or zero balances

**Solution**:
1. Stop all containers: `docker-compose down`
2. Remove blockchain data: `docker run --rm -v $(pwd)/data:/data alpine rm -rf /data/*/geth`
3. Restart: `docker-compose up -d`

## Complete Deployment Workflow

### 1. Initial Setup

```bash
# Create account
./scripts/create-new-account.sh

# Note the generated address and update genesis.json
# Update extraData and alloc sections with the new address
```

### 2. Network Initialization

```bash
# Complete restart with new genesis
docker-compose down
docker run --rm -v $(pwd)/data:/data alpine rm -rf /data/*/geth
docker-compose up -d
sleep 15
```

### 3. Account Activation

```bash
# Get account address from scripts/account-info.txt
ACCOUNT=$(grep "ADDRESS=" scripts/account-info.txt | cut -d'=' -f2)

# Unlock account
curl -X POST -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"personal_unlockAccount\",\"params\":[\"$ACCOUNT\",\"password123\",0],\"id\":1}" \
  http://127.0.0.1:8545

# Setup mining
curl -X POST -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"miner_setEtherbase\",\"params\":[\"$ACCOUNT\"],\"id\":1}" \
  http://127.0.0.1:8545

curl -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"miner_start","params":[],"id":1}' \
  http://127.0.0.1:8545
```

### 4. Contract Deployment

```bash
cd contracts
npm run deploy
```

## Success Indicators

1. **Network Health**: Block number > 0
2. **Account Status**: Balance > 0 ETH
3. **Mining Active**: New blocks being produced every 5 seconds
4. **Contract Deployment**: No authentication or insufficient funds errors

## File Locations

- **Account Info**: `scripts/account-info.txt`
- **Password**: `scripts/password.txt`
- **Keystore**: `data/node1/keystore/UTC--[timestamp]--[address]`
- **Genesis**: `genesis.json`
- **Docker Config**: `docker-compose.yml`
- **Deployment Scripts**: `contracts/deploy.js`

## Security Notes

⚠️ **WARNING**: This setup uses well-known passwords and is intended for development only. Never use these configurations on mainnet or with real funds.

- Default password: `password123`
- Accounts are unlocked indefinitely (`0` timeout)
- HTTP RPC allows all origins (`*`)
- Insecure unlock enabled

## Troubleshooting Checklist

Before reporting issues, verify:

- [ ] Account keystore file exists
- [ ] Genesis.json has correct address format (lowercase, no 0x in alloc)
- [ ] ExtraData contains the signer address
- [ ] Complete network restart performed after genesis changes
- [ ] Account is unlocked
- [ ] Mining is started
- [ ] Block production is active
- [ ] Account has sufficient balance

This guide provides a complete reference for setting up and troubleshooting the Clique PoA network with smart contract deployment capabilities.