#!/bin/bash

# Connect peers manually if needed
echo "Connecting peers..."

# Get enode of node1
NODE1_ENODE=$(docker exec geth-poi-node1 geth --datadir /root/.ethereum --exec "admin.nodeInfo.enode" attach 2>/dev/null | tr -d '"')

# Connect node2 to node1
docker exec geth-poi-node2 geth --datadir /root/.ethereum --exec "admin.addPeer('$NODE1_ENODE')" attach

# Connect node3 to node1
docker exec geth-poi-node3 geth --datadir /root/.ethereum --exec "admin.addPeer('$NODE1_ENODE')" attach

# Connect node4 to node1
docker exec geth-poi-node4 geth --datadir /root/.ethereum --exec "admin.addPeer('$NODE1_ENODE')" attach

echo "Peers connected successfully!"