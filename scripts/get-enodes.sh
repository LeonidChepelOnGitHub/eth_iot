#!/bin/bash

# Get enode information for each node
echo "Getting enode information for all nodes..."

echo "Node 1 enode:"
docker exec geth-node1 geth --datadir /root/.ethereum --exec "admin.nodeInfo.enode" attach

echo "Node 2 enode:"
docker exec geth-node2 geth --datadir /root/.ethereum --exec "admin.nodeInfo.enode" attach

echo "Node 3 enode:"
docker exec geth-node3 geth --datadir /root/.ethereum --exec "admin.nodeInfo.enode" attach

echo "Node 4 enode:"
docker exec geth-node4 geth --datadir /root/.ethereum --exec "admin.nodeInfo.enode" attach