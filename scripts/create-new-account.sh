#\!/bin/bash

echo "🔐 Creating new Ethereum account with geth"
echo "=========================================="

# Set password
PASSWORD="password123"
echo "$PASSWORD" > scripts/password.txt


echo "📁 Creating new account..."

# Create new account using geth in container
ACCOUNT_OUTPUT=$(docker run --rm -v $(pwd)/data/node1:/root/.ethereum -v $(pwd)/scripts:/root/scripts eth_iot-geth-node1 sh -c "
echo '$PASSWORD'  < /dev/null |  geth account new --datadir /root/.ethereum --password /dev/stdin
")

echo "Account creation output:"
echo "$ACCOUNT_OUTPUT"

# Extract address from output
ACCOUNT_ADDRESS=$(echo "$ACCOUNT_OUTPUT" | grep "Public address of the key:" | awk '{print $NF}')

if [ -z "$ACCOUNT_ADDRESS" ]; then
    echo "❌ Failed to create account"
    exit 1
fi

echo "✅ Account created successfully\!"
echo "Address: $ACCOUNT_ADDRESS"
echo "Password: $PASSWORD"

# Get the keystore file path
KEYSTORE_FILE=$(ls -t data/node1/keystore/* 2>/dev/null | head -1)
echo "Keystore file: $KEYSTORE_FILE"

# Save account info
cat > scripts/account-info.txt << EOL
# Ethereum Account Information
# Generated: $(date)

ADDRESS=$ACCOUNT_ADDRESS
PASSWORD=$PASSWORD
KEYSTORE_FILE=$KEYSTORE_FILE

# Use this address in genesis.json extraData for Clique consensus
# Use this address for contract deployment
EOL

echo ""
echo "📝 Account information saved to scripts/account-info.txt"
echo ""
echo "🚀 Next steps:"
echo "1. Update genesis.json with this address as Clique signer"
echo "2. Update docker-compose.yml to unlock this account"
echo "3. Restart the network"
echo ""
echo "Account Address: $ACCOUNT_ADDRESS"
echo "Password: $PASSWORD"
