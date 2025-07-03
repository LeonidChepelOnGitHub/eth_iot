#!/bin/bash

# Script to connect to specific Geth instances
# Usage: ./connect-geth.sh [node_number]
# Example: ./connect-geth.sh 1

# Function to display usage
show_usage() {
    echo "Usage: $0 [node_number]"
    echo "Connect to a specific Geth node instance"
    echo ""
    echo "Arguments:"
    echo "  node_number    Node number (1-4), defaults to 1"
    echo ""
    echo "Examples:"
    echo "  $0 1          # Connect to geth-node1"
    echo "  $0 2          # Connect to geth-node2"
    echo "  $0 3          # Connect to geth-node3"
    echo "  $0 4          # Connect to geth-node4"
    echo ""
    echo "Available methods:"
    echo "  - IPC: Connect via IPC socket (recommended)"
    echo "  - HTTP: Connect via HTTP RPC"
    echo "  - Interactive: Open interactive console"
    echo ""
}

# Check if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Default to node 1 if no argument provided
NODE_NUM=${1:-1}

# Validate node number
if [ "$NODE_NUM" -lt 1 ] || [ "$NODE_NUM" -gt 4 ]; then
    echo "Error: Node number must be between 1 and 4"
    show_usage
    exit 1
fi

# Set container name and ports based on node number
CONTAINER_NAME="geth-node$NODE_NUM"
case $NODE_NUM in
    1)
        HTTP_PORT=8545
        WS_PORT=8546
        ;;
    2)
        HTTP_PORT=8546
        WS_PORT=8547
        ;;
    3)
        HTTP_PORT=8547
        WS_PORT=8548
        ;;
    4)
        HTTP_PORT=8548
        WS_PORT=8549
        ;;
esac

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Error: Container $CONTAINER_NAME is not running"
    echo "Start the network first: docker-compose up -d"
    exit 1
fi

echo "==================== Geth Node $NODE_NUM Connection ===================="
echo "Container: $CONTAINER_NAME"
echo "HTTP RPC: http://localhost:$HTTP_PORT"
echo "WebSocket: ws://localhost:$WS_PORT"
echo "======================================================================"
echo ""

# Interactive menu
echo "Choose connection method:"
echo "1) Interactive Console (IPC)"
echo "2) Single Command via IPC"
echo "3) Single Command via HTTP RPC"
echo "4) Show Connection Info"
echo "5) Check Node Status"
echo "6) Exit"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo "Opening interactive console for $CONTAINER_NAME..."
        echo "Type 'exit' to leave the console"
        docker exec -it "$CONTAINER_NAME" geth --datadir /root/.ethereum attach
        ;;
    2)
        read -p "Enter Geth command (e.g., eth.blockNumber): " cmd
        echo "Executing: $cmd"
        docker exec "$CONTAINER_NAME" geth --datadir /root/.ethereum --exec "$cmd" attach
        ;;
    3)
        read -p "Enter JSON-RPC method (e.g., eth_blockNumber): " method
        echo "Executing HTTP RPC call..."
        curl -X POST \
             -H "Content-Type: application/json" \
             -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":[],\"id\":1}" \
             http://localhost:$HTTP_PORT
        echo ""
        ;;
    4)
        echo "Connection Information for Node $NODE_NUM:"
        echo "=================================="
        echo "Container Name: $CONTAINER_NAME"
        echo "HTTP RPC: http://localhost:$HTTP_PORT"
        echo "WebSocket: ws://localhost:$WS_PORT"
        echo "Network ID: 1337"
        echo "Chain ID: 1337"
        echo ""
        echo "Common commands:"
        echo "  eth.blockNumber          - Current block number"
        echo "  eth.accounts             - List accounts"
        echo "  net.peerCount            - Number of peers"
        echo "  admin.peers              - Detailed peer info"
        echo "  clique.getSigners()      - List of signers"
        echo "  miner.start()            - Start mining"
        echo "  miner.stop()             - Stop mining"
        echo "  personal.listAccounts    - List personal accounts"
        ;;
    5)
        echo "Checking status of $CONTAINER_NAME..."
        echo "=================================="
        
        echo "Block Number:"
        docker exec "$CONTAINER_NAME" geth --datadir /root/.ethereum --exec "eth.blockNumber" attach
        
        echo "Peer Count:"
        docker exec "$CONTAINER_NAME" geth --datadir /root/.ethereum --exec "net.peerCount" attach
        
        echo "Mining Status:"
        docker exec "$CONTAINER_NAME" geth --datadir /root/.ethereum --exec "eth.mining" attach
        
        echo "Accounts:"
        docker exec "$CONTAINER_NAME" geth --datadir /root/.ethereum --exec "eth.accounts" attach
        
        echo "Signers:"
        docker exec "$CONTAINER_NAME" geth --datadir /root/.ethereum --exec "clique.getSigners()" attach
        ;;
    6)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac