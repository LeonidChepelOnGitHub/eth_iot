#!/bin/bash

# RPC Examples for interacting with Geth nodes
# This script provides examples of common RPC calls

# Default to node 1 if no argument provided
NODE_NUM=${1:-1}

# Set HTTP port based on node number
case $NODE_NUM in
    1) HTTP_PORT=8545 ;;
    2) HTTP_PORT=8546 ;;
    3) HTTP_PORT=8547 ;;
    #4) HTTP_PORT=8548 ;;
    *) 
        echo "Error: Invalid node number. Use 1-4"
        exit 1
        ;;
esac

BASE_URL="http://localhost:$HTTP_PORT"

echo "=== RPC Examples for Node $NODE_NUM (Port $HTTP_PORT) ==="
echo ""

# Function to make RPC call
rpc_call() {
    local method=$1
    local params=$2
    local id=${3:-1}
    
    if [ -z "$params" ]; then
        params="[]"
    fi
    
    echo "Method: $method"
    echo "Request:"
    echo "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":$id}"
    echo ""
    echo "Response:"
    curl -s -X POST \
         -H "Content-Type: application/json" \
         -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":$id}" \
         $BASE_URL | jq '.' 2>/dev/null || curl -s -X POST \
         -H "Content-Type: application/json" \
         -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":$id}" \
         $BASE_URL
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Interactive menu
echo "Choose an RPC example:"
echo "1)  eth_blockNumber - Get current block number"
echo "2)  eth_accounts - List accounts"
echo "3)  net_peerCount - Get peer count"
echo "4)  eth_mining - Check if mining"
echo "5)  eth_getBalance - Get account balance"
echo "6)  clique_getSigners - Get Clique signers"
echo "7)  admin_nodeInfo - Get node information"
echo "8)  eth_getBlockByNumber - Get block by number"
echo "9)  net_version - Get network version"
echo "10) eth_chainId - Get chain ID"
echo "11) Run all basic examples"
echo "12) Custom RPC call"
echo "13) Exit"
echo ""

read -p "Enter your choice (1-13): " choice

case $choice in
    1)
        rpc_call "eth_blockNumber"
        ;;
    2)
        rpc_call "eth_accounts"
        ;;
    3)
        rpc_call "net_peerCount"
        ;;
    4)
        rpc_call "eth_mining"
        ;;
    5)
        read -p "Enter account address (or press Enter for first account): " account
        if [ -z "$account" ]; then
            # Get first account
            first_account=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","method":"eth_accounts","params":[],"id":1}' \
                $BASE_URL | jq -r '.result[0]' 2>/dev/null)
            account=$first_account
        fi
        rpc_call "eth_getBalance" "[\"$account\", \"latest\"]"
        ;;
    6)
        rpc_call "clique_getSigners"
        ;;
    7)
        rpc_call "admin_nodeInfo"
        ;;
    8)
        read -p "Enter block number (or 'latest'): " block_num
        if [ -z "$block_num" ]; then
            block_num="latest"
        fi
        rpc_call "eth_getBlockByNumber" "[\"$block_num\", false]"
        ;;
    9)
        rpc_call "net_version"
        ;;
    10)
        rpc_call "eth_chainId"
        ;;
    11)
        echo "Running all basic examples..."
        echo ""
        rpc_call "eth_blockNumber"
        rpc_call "eth_accounts"
        rpc_call "net_peerCount"
        rpc_call "eth_mining"
        rpc_call "net_version"
        rpc_call "eth_chainId"
        rpc_call "clique_getSigners"
        ;;
    12)
        read -p "Enter RPC method: " method
        read -p "Enter parameters (JSON array, or press Enter for []): " params
        if [ -z "$params" ]; then
            params="[]"
        fi
        rpc_call "$method" "$params"
        ;;
    13)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

echo ""
echo "To run this script for a different node:"
echo "$0 [node_number]"
echo ""
echo "Examples:"
echo "$0 1    # Node 1 (port 8545)"
echo "$0 2    # Node 2 (port 8546)"
echo "$0 3    # Node 3 (port 8547)"
echo "$0 4    # Node 4 (port 8548)"