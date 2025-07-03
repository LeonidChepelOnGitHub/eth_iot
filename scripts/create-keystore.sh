#!/bin/bash

# Create keystore files for mining accounts
echo "🔑 Creating keystore files for Clique signers"
echo "=============================================="

# Private keys for the accounts defined in genesis.json
PRIVATE_KEY1="829e924fdf021ba3dbbc4225edfece9aca04b929d6e75613329ca6f1d31c0bb4"
PRIVATE_KEY2="b0057716d5917badaf911b193b12b910811c1497b5bada8d7711f758981c3773"
PRIVATE_KEY3="77c5495fbb039eed474fc940f29955ed0531693cc9212911efd35dff0373153f"

# Create temporary files for private keys
echo "$PRIVATE_KEY1" > /tmp/key1.txt
echo "$PRIVATE_KEY2" > /tmp/key2.txt  
echo "$PRIVATE_KEY3" > /tmp/key3.txt

# Create password file
echo "password123" > /tmp/password.txt

# Build the image first
echo "🏗️  Building geth image..."
docker-compose build geth-node1 >/dev/null 2>&1

# Import accounts to each node
echo "📥 Importing accounts..."

# Node 1
echo "Creating account for node 1..."
docker run --rm -v "$(pwd)/data/node1:/root/.ethereum" -v "/tmp:/tmp" eth_iot-geth-node1 \
    geth account import --datadir /root/.ethereum --password /tmp/password.txt /tmp/key1.txt

# Node 2  
echo "Creating account for node 2..."
docker run --rm -v "$(pwd)/data/node2:/root/.ethereum" -v "/tmp:/tmp" eth_iot-geth-node2 \
    geth account import --datadir /root/.ethereum --password /tmp/password.txt /tmp/key2.txt

# Node 3
echo "Creating account for node 3..."
docker run --rm -v "$(pwd)/data/node3:/root/.ethereum" -v "/tmp:/tmp" eth_iot-geth-node3 \
    geth account import --datadir /root/.ethereum --password /tmp/password.txt /tmp/key3.txt

# Clean up temporary files
rm /tmp/key1.txt /tmp/key2.txt /tmp/key3.txt /tmp/password.txt

echo "✅ Keystore creation complete!"
echo ""
echo "📂 Checking created keystores..."
ls -la data/node1/keystore/ 2>/dev/null || echo "No keystore files in node1"
ls -la data/node2/keystore/ 2>/dev/null || echo "No keystore files in node2" 
ls -la data/node3/keystore/ 2>/dev/null || echo "No keystore files in node3"