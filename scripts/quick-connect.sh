#!/bin/bash

# Quick connection scripts for each node
# These are convenience wrappers for immediate access

# Quick connect to node 1 (interactive console)
connect_node1() {
    echo "Connecting to Node 1 (Interactive Console)..."
    docker exec -it geth-node1 geth --datadir /root/.ethereum attach
}

# Quick connect to node 2 (interactive console)
connect_node2() {
    echo "Connecting to Node 2 (Interactive Console)..."
    docker exec -it geth-node2 geth --datadir /root/.ethereum attach
}

# Quick connect to node 3 (interactive console)
connect_node3() {
    echo "Connecting to Node 3 (Interactive Console)..."
    docker exec -it geth-node3 geth --datadir /root/.ethereum attach
}

# Quick connect to node 4 (interactive console)
connect_node4() {
    echo "Connecting to Node 4 (Interactive Console)..."
    docker exec -it geth-node4 geth --datadir /root/.ethereum attach
}

# Show network status
show_network_status() {
    echo "=== Network Status ==="
    echo ""
    
    for i in {1..4}; do
        container="geth-node$i"
        if docker ps | grep -q "$container"; then
            echo "Node $i ($container): RUNNING"
            block_num=$(docker exec "$container" geth --datadir /root/.ethereum --exec "eth.blockNumber" attach 2>/dev/null || echo "Error")
            peer_count=$(docker exec "$container" geth --datadir /root/.ethereum --exec "net.peerCount" attach 2>/dev/null || echo "Error")
            mining=$(docker exec "$container" geth --datadir /root/.ethereum --exec "eth.mining" attach 2>/dev/null || echo "Error")
            
            echo "  Block Number: $block_num"
            echo "  Peer Count: $peer_count"
            echo "  Mining: $mining"
            echo ""
        else
            echo "Node $i ($container): NOT RUNNING"
            echo ""
        fi
    done
}

# Main script logic
case "${1:-menu}" in
    "1"|"node1")
        connect_node1
        ;;
    "2"|"node2")
        connect_node2
        ;;
    "3"|"node3")
        connect_node3
        ;;
    "4"|"node4")
        connect_node4
        ;;
    "status")
        show_network_status
        ;;
    "menu"|*)
        echo "=== Quick Connect to Geth Nodes ==="
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  1 or node1    - Connect to Node 1 (Signer)"
        echo "  2 or node2    - Connect to Node 2 (Signer)"
        echo "  3 or node3    - Connect to Node 3 (Signer)"
        echo "  4 or node4    - Connect to Node 4 (Non-signer)"
        echo "  status        - Show network status"
        echo ""
        echo "Examples:"
        echo "  $0 1          # Connect to node 1"
        echo "  $0 node2      # Connect to node 2"
        echo "  $0 status     # Show network status"
        echo ""
        echo "For more advanced options, use: ./connect-geth.sh"
        ;;
esac