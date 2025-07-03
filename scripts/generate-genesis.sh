#!/bin/bash

# Generate genesis.json based on template with new accounts
echo "🔧 Genesis File Generator for Clique Network"
echo "============================================"

# Check if accounts are provided as parameters
if [ $# -eq 3 ]; then
    SIGNER1="$1"
    SIGNER2="$2" 
    SIGNER3="$3"
    echo "📥 Using provided signer accounts:"
    echo "   Signer 1: $SIGNER1"
    echo "   Signer 2: $SIGNER2"
    echo "   Signer 3: $SIGNER3"
else
    echo "📋 No accounts provided, using default genesis accounts..."
    SIGNER1="0x38d7ff8ef1bdda255caa19bb065802455783b2ee"
    SIGNER2="0xb366491ccb18b83b999aa6f9ebbc41e9d0fc6976"
    SIGNER3="0xd71b40374e9d93bf0e1efd38f253d246014d1b60"
fi

# Additional pre-funded accounts
FUNDED_ACCOUNT="0x5e6e9cf7c08c4a345e9284f6edd3e66b071c29f3"

# Remove 0x prefix for extraData (Clique format requirement)
SIGNER1_CLEAN="${SIGNER1#0x}"
SIGNER2_CLEAN="${SIGNER2#0x}"
SIGNER3_CLEAN="${SIGNER3#0x}"

# Construct Clique extraData
# Format: 32 bytes vanity + N*20 bytes signer addresses + 65 bytes signature
VANITY="0000000000000000000000000000000000000000000000000000000000000000"
SIGNERS="${SIGNER1_CLEAN}${SIGNER2_CLEAN}${SIGNER3_CLEAN}"
SIGNATURE="0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
EXTRA_DATA="0x${VANITY}${SIGNERS}${SIGNATURE}"

echo "🔨 Generating genesis configuration..."
echo "   Chain ID: 1337"
echo "   Block Period: 15 seconds"
echo "   Epoch: 30000 blocks"
echo "   Signers: 3 accounts"
echo "   Pre-funded: 4 accounts"

# Create the genesis.json file
cat > genesis.json << EOF
{
  "config": {
    "chainId": 1337,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "clique": {
      "period": 15,
      "epoch": 30000
    }
  },
  "nonce": "0x0",
  "timestamp": "0x5ddf8f3e",
  "extraData": "$EXTRA_DATA",
  "gasLimit": "0x47b760",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "${SIGNER1#0x}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
    "${SIGNER2#0x}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
    "${SIGNER3#0x}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    },
    "${FUNDED_ACCOUNT#0x}": {
      "balance": "0x200000000000000000000000000000000000000000000000000000000000000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
EOF

echo "✅ Genesis file generated: genesis.json"
echo ""
echo "📊 Genesis Summary:"
echo "==================="
echo "🔗 Chain ID: 1337"
echo "⏰ Block Period: 15 seconds"
echo "👥 Clique Signers:"
echo "   1. $SIGNER1"
echo "   2. $SIGNER2" 
echo "   3. $SIGNER3"
echo "💰 Pre-funded Accounts (each with ~9M ETH):"
echo "   • $SIGNER1"
echo "   • $SIGNER2"
echo "   • $SIGNER3"
echo "   • $FUNDED_ACCOUNT"
echo ""
echo "🔧 ExtraData: $EXTRA_DATA"
echo "   Length: ${#EXTRA_DATA} characters (should be even)"
echo ""
echo "💡 Usage:"
echo "   Generate with default accounts: ./generate-genesis.sh"
echo "   Generate with custom accounts: ./generate-genesis.sh 0xADDR1 0xADDR2 0xADDR3"
echo ""
echo "⚠️  After generating, restart the network to apply changes:"
echo "   docker-compose down"
echo "   rm -rf data/"
echo "   docker-compose up -d"