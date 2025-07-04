#!/bin/bash

# Check account balances across all nodes
echo "🔍 Checking Account Balances"
echo "================================"

# Pre-funded accounts from genesis
ACCOUNTS=(
    "0x7df9a875a174b3bc565e6424a0050ebc1b2d1d82"
    "0xf17f52151EbEF6C7334FAD080c5704D77216b732",
    "0xd41aa69ee1bf7c0008b00574d1b1e86c33019fdb",
    "0x0f94b280babe816b9de18f2164a82b8315d94419"
 
)

NODE_PORT=${1:-8545}

echo "📡 Checking on node port: $NODE_PORT"
echo ""

for account in "${ACCOUNTS[@]}"; do
    echo "Account: $account"
    
    # Get balance via HTTP RPC
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$account\", \"latest\"],\"id\":1}" \
        http://127.0.0.1:$NODE_PORT)
    
    # Extract result without jq
    balance=$(echo "$response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    if [[ "$balance" != "null" && "$balance" != "" ]]; then
        # Convert hex to decimal and then to ether
        balance_dec=$(printf "%d" $balance)
        balance_eth=$(echo "scale=6; $balance_dec / 1000000000000000000" | bc -l)
        echo "Balance: $balance_eth ETH"
    else
        echo "Balance: Unable to retrieve"
    fi
    echo "---"
done

echo ""
echo "💡 To add balance to a new account:"
echo "1. Add to genesis.json alloc section (requires network restart)"
echo "2. Transfer from existing account using manage-accounts.js"
echo "3. Use geth console commands"