#!/bin/bash

# Setup Edgeshark for network monitoring
echo "Setting up Edgeshark for network monitoring..."

# First, make sure the Ethereum network is running
echo "Make sure your Ethereum network is running first:"
echo "docker-compose up -d"
echo ""

# Deploy Edgeshark using the official method
echo "Deploying Edgeshark using official method..."
echo "This will download and run the official Edgeshark deployment:"
echo ""

# Create a separate directory for Edgeshark to avoid conflicts
mkdir -p edgeshark
cd edgeshark

# Download and run the official Edgeshark deployment
echo "Downloading and starting Edgeshark..."
wget -q --no-cache -O - \
https://github.com/siemens/edgeshark/raw/main/deployments/wget/docker-compose.yaml \
| DOCKER_DEFAULT_PLATFORM= docker compose -f - up -d

cd ..

echo ""
echo "Edgeshark setup completed!"
echo "Edgeshark will be available at: http://localhost:5001"
echo ""
echo "To use with Wireshark:"
echo "1. Download the csharg extcap plugin for your OS from:"
echo "   https://github.com/siemens/cshargextcap"
echo "2. Install it in Wireshark"
echo "3. Connect to Edgeshark from Wireshark interface"
echo ""
echo "Note: Wireshark 4.4.0 is not supported. Use 4.4.1 or later."
echo ""
echo "To stop Edgeshark:"
echo "cd edgeshark && docker compose down"