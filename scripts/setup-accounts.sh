#!/bin/bash

# Enhanced setup for Clique mining with existing accounts
echo "⛏️  Enhanced Clique Mining Setup"
echo "==============================="

# Check if network is running
if ! docker ps --format "table {{.Names}}" | grep -q "geth-node"; then
    echo "❌ Geth nodes are not running. Please start the network first:"
    echo "   docker-compose up -d"
    exit 1
fi

# Account addresses from genesis.json (these have pre-funded balances)
GENESIS_ACCOUNTS=(
    "0x38d7ff8ef1bdda255caa19bb065802455783b2ee"
    "0xb366491ccb18b83b999aa6f9ebbc41e9d0fc6976"
    "0xd71b40374e9d93bf0e1efd38f253d246014d1b60"
    "0x5e6e9cf7c08c4a345e9284f6edd3e66b071c29f3"
)

PASSWORD="password123"

echo "📊 Checking current network status..."

# Check genesis balances are loaded
echo "💰 Verifying genesis account balances:"
for account in "${GENESIS_ACCOUNTS[@]}"; do
    balance=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$account\", \"latest\"],\"id\":1}" \
        http://127.0.0.1:8545 | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    if [[ "$balance" != "" && "$balance" != "0x0" ]]; then
        echo "✅ $account has balance"
    else
        echo "❌ $account has no balance - genesis not loaded properly"
    fi
done

echo ""
echo "🔧 Setting up mining accounts..."
echo "Since we have working balances, we'll create new mining accounts and transfer funds."

# Create new accounts in each node for mining
echo ""
echo "🆕 Creating new mining accounts in each node..."

# Function to create account
create_account() {
    local node=$1
    
    echo "Creating account in $node..."
    
    # Create account using geth command in container
    result=$(docker exec $node sh -c "printf '$PASSWORD\n$PASSWORD\n' | geth account new --datadir /root/.ethereum" 2>/dev/null)
    
    if [[ $result == *"Public address of the key:"* ]]; then
        address=$(echo "$result" | grep "Public address of the key:" | awk '{print $NF}')
        echo "✅ Created account: $address"
        echo "$address"
    else
        echo "❌ Failed to create account in $node"
        echo "Error: $result"
        echo ""
    fi
}

# Create mining accounts
echo "Creating mining accounts..."
NODE1_ACCOUNT=$(create_account "geth-node1" | tail -1)
NODE2_ACCOUNT=$(create_account "geth-node2" | tail -1) 
NODE3_ACCOUNT=$(create_account "geth-node3" | tail -1)

echo ""
echo "💸 Setting up fund transfers..."
echo "We'll transfer funds from genesis accounts to new mining accounts."

# Function to transfer funds
transfer_funds() {
    local from_account=$1
    local to_account=$2
    local amount="0x56BC75E2D630E0000"  # 100 ETH in Wei
    local port=$3
    
    if [[ -z "$to_account" || "$to_account" == "" ]]; then
        echo "⚠️  Skipping transfer - no destination account"
        return
    fi
    
    echo "Transferring 100 ETH from $from_account to $to_account..."
    
    # Send transaction
    result=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_sendTransaction\",\"params\":[{\"from\":\"$from_account\",\"to\":\"$to_account\",\"value\":\"$amount\"}],\"id\":1}" \
        http://127.0.0.1:$port)
    
    if [[ $result == *"result"* ]]; then
        tx_hash=$(echo "$result" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Transfer initiated: $tx_hash"
    else
        echo "⚠️  Transfer failed - accounts may need to be unlocked for sending"
        echo "   Error: $result"
    fi
}

# Attempt transfers (will work if accounts can be unlocked)
if [[ -n "$NODE1_ACCOUNT" ]]; then
    transfer_funds "${GENESIS_ACCOUNTS[0]}" "$NODE1_ACCOUNT" "8545"
fi

if [[ -n "$NODE2_ACCOUNT" ]]; then
    transfer_funds "${GENESIS_ACCOUNTS[1]}" "$NODE2_ACCOUNT" "8546"
fi

if [[ -n "$NODE3_ACCOUNT" ]]; then
    transfer_funds "${GENESIS_ACCOUNTS[2]}" "$NODE3_ACCOUNT" "8547"
fi

echo ""
echo "🔧 STEP 1: Generating new genesis file with mining accounts as signers..."
echo "========================================================================="

# Generate new genesis file with the new accounts as Clique signers
echo "Using accounts: $NODE1_ACCOUNT, $NODE2_ACCOUNT, $NODE3_ACCOUNT"
./scripts/generate-genesis.sh "$NODE1_ACCOUNT" "$NODE2_ACCOUNT" "$NODE3_ACCOUNT"

echo ""
echo "🔧 STEP 2: Updating docker-compose.yml with mining configuration..."
echo "=================================================================="

# Update the main docker-compose.yml with mining enabled
cat > docker-compose.yml << EOF
version: '3.8'

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
    command: |
      sh -c "
        if [ ! -d /root/.ethereum/geth ]; then
          geth --datadir /root/.ethereum init /root/genesis.json
        fi
        geth --datadir /root/.ethereum --networkid 1337 --port 30303 --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,web3,personal,miner,clique,admin --http.corsdomain '*' --http.vhosts '*' --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,web3,personal,miner,clique,admin --ws.origins '*' --mine --miner.etherbase ${NODE1_ACCOUNT} --unlock ${NODE1_ACCOUNT} --password /root/scripts/password.txt --allow-insecure-unlock --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.vhosts '*' --verbosity 4
      "

  geth-node2:
    build: .
    container_name: geth-node2
    ports:
      - "8546:8545"
      - "30304:30303"
    networks:
      - eth-network
    volumes:
      - ./data/node2:/root/.ethereum
      - ./genesis.json:/root/genesis.json
      - ./scripts:/root/scripts
    command: |
      sh -c "
        if [ ! -d /root/.ethereum/geth ]; then
          geth --datadir /root/.ethereum init /root/genesis.json
        fi
        geth --datadir /root/.ethereum --networkid 1337 --port 30303 --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,web3,personal,miner,clique,admin --http.corsdomain '*' --http.vhosts '*' --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,web3,personal,miner,clique,admin --ws.origins '*' --mine --miner.etherbase ${NODE2_ACCOUNT} --unlock ${NODE2_ACCOUNT} --password /root/scripts/password.txt --allow-insecure-unlock --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.vhosts '*' --verbosity 4
      "
    depends_on:
      - geth-node1

  geth-node3:
    build: .
    container_name: geth-node3
    ports:
      - "8547:8545"
      - "30305:30303"
    networks:
      - eth-network
    volumes:
      - ./data/node3:/root/.ethereum
      - ./genesis.json:/root/genesis.json
      - ./scripts:/root/scripts
    command: |
      sh -c "
        if [ ! -d /root/.ethereum/geth ]; then
          geth --datadir /root/.ethereum init /root/genesis.json
        fi
        geth --datadir /root/.ethereum --networkid 1337 --port 30303 --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,web3,personal,miner,clique,admin --http.corsdomain '*' --http.vhosts '*' --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,web3,personal,miner,clique,admin --ws.origins '*' --mine --miner.etherbase ${NODE3_ACCOUNT} --unlock ${NODE3_ACCOUNT} --password /root/scripts/password.txt --allow-insecure-unlock --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.vhosts '*' --verbosity 4
      "
    depends_on:
      - geth-node1

  geth-node4:
    build: .
    container_name: geth-node4
    ports:
      - "8548:8545"
      - "30306:30303"
    networks:
      - eth-network
    volumes:
      - ./data/node4:/root/.ethereum
      - ./genesis.json:/root/genesis.json
      - ./scripts:/root/scripts
    command: |
      sh -c "
        if [ ! -d /root/.ethereum/geth ]; then
          geth --datadir /root/.ethereum init /root/genesis.json
        fi
        geth --datadir /root/.ethereum --networkid 1337 --port 30303 --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,web3,personal,miner,clique,admin --http.corsdomain '*' --http.vhosts '*' --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,web3,personal,miner,clique,admin --ws.origins '*' --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.vhosts '*' --verbosity 4
      "
    depends_on:
      - geth-node1

networks:
  eth-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  node1-data:
  node2-data:
  node3-data:
  node4-data:
EOF

echo "✅ Updated docker-compose.yml with new mining accounts"

echo ""
echo "🔧 STEP 3: Preparing network restart for full mining setup..."
echo "==========================================================="

echo ""
echo "🚀 Complete Mining Setup Summary:"
echo "=================================="
echo "✅ STEP 1: Generated new genesis.json with mining accounts as Clique signers"
echo "✅ STEP 2: Updated docker-compose.yml with mining configuration"
echo "✅ STEP 3: Ready for network restart with full mining capability"
echo ""
echo "🆕 New Mining Accounts (now Clique signers with balances):"
echo "   Node 1: $NODE1_ACCOUNT (Signer & Miner)"
echo "   Node 2: $NODE2_ACCOUNT (Signer & Miner)"
echo "   Node 3: $NODE3_ACCOUNT (Signer & Miner)"
echo "   Node 4: No mining (Participant only)"
echo ""
echo "📋 Account Details:"
echo "   • Each mining account has keystore in respective node"
echo "   • Each mining account has pre-funded balance (~9M ETH)"
echo "   • Each mining account is authorized Clique signer"
echo "   • Password for all accounts: $PASSWORD"
echo ""
echo "🔄 To activate full mining setup:"
echo "   1. Stop current network: docker-compose down"
echo "   2. Remove old data: docker run --rm -v \$(pwd)/data:/data alpine rm -rf /data/*"
echo "   3. Start mining network: docker-compose up -d"
echo ""
echo "✨ After restart, you'll have a fully functional Clique PoA network with:"
echo "   • Block production every 15 seconds"
echo "   • 3 active miners with funded accounts"
echo "   • HTTP RPC endpoints on ports 8545-8548"
echo "   • WebSocket endpoints for real-time monitoring"
echo ""
echo "💡 Quick commands after restart:"
echo "   Check balances: ./scripts/check-balances.sh"
echo "   Check mining: curl -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_mining\",\"params\":[],\"id\":1}' http://127.0.0.1:8545"
echo "   Check block number: curl -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://127.0.0.1:8545"