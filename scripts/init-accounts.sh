#!/bin/bash

# Create accounts for each node
echo "Creating accounts for the nodes..."

# Node 1 (Signer)
docker exec geth-node1 geth --datadir /root/.ethereum account new --password /root/scripts/password.txt

# Node 2 (Signer)
docker exec geth-node2 geth --datadir /root/.ethereum account new --password /root/scripts/password.txt

# Node 3 (Signer)
docker exec geth-node3 geth --datadir /root/.ethereum account new --password /root/scripts/password.txt

# Node 4 (Non-signer)
docker exec geth-node4 geth --datadir /root/.ethereum account new --password /root/scripts/password.txt

echo "Accounts created successfully!"
echo "Remember to update the genesis.json file with the actual account addresses"