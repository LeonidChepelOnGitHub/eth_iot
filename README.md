# Go-Ethereum Clique Network with Edgeshark Monitoring

This setup creates a 4-node Ethereum network using the Clique consensus mechanism with Edgeshark monitoring for Wireshark connectivity.

## Network Architecture

- **4 Ethereum nodes** (3 signers + 1 non-signer)
- **Clique consensus** with 15-second block time
- **Edgeshark monitoring** for network packet analysis
- **Docker containerized** environment

## Prerequisites

- Docker and Docker Compose
- Wireshark (for packet analysis via Edgeshark)

## Quick Start

1. **Build and start the Ethereum network:**
   ```bash
   docker-compose up -d
   ```

2. **Initialize accounts (if needed):**
   ```bash
   chmod +x scripts/*.sh
   ./scripts/init-accounts.sh
   ```

3. **Connect peers (if needed):**
   ```bash
   ./scripts/connect-peers.sh
   ```

4. **Setup and deploy IoT smart contracts:**
   ```bash
   cd contracts
   npm install
   node compile.js compile IoTDataTracker
   node deploy.js
   ```

5. **Run IoT device simulation:**
   ```bash
   # Smart home scenario
   node iot-simulator.js smart-home local
   
   # Industrial IoT scenario
   node iot-simulator.js industrial local
   ```

6. **Setup Edgeshark monitoring:**
   ```bash
   ./scripts/setup-edgeshark.sh
   ```

7. **Access Edgeshark monitoring:**
   - Open browser to `http://localhost:5001`
   - Install Wireshark plugin and connect to analyze network traffic

## Node Configuration

### Node 1 (Signer)
- **RPC Port:** 8545
- **P2P Port:** 30303
- **Role:** Signer/Sealer
- **Mining:** Enabled

### Node 2 (Signer)
- **RPC Port:** 8546
- **P2P Port:** 30304
- **Role:** Signer/Sealer
- **Mining:** Enabled

### Node 3 (Signer)
- **RPC Port:** 8547
- **P2P Port:** 30305
- **Role:** Signer/Sealer
- **Mining:** Enabled

### Node 4 (Non-signer)
- **RPC Port:** 8548
- **P2P Port:** 30306
- **Role:** Non-signer
- **Mining:** Disabled

## Clique Configuration

- **Chain ID:** 1337
- **Block Period:** 15 seconds
- **Epoch:** 30000 blocks
- **Signers:** 3 out of 4 nodes

## Monitoring with Edgeshark

Edgeshark provides real-time network packet capture and analysis:

1. **Access the web interface** at `http://localhost:5001`
2. **Select the eth-network interface** for monitoring
3. **Download the csharg extcap plugin** for your OS from the Edgeshark GitHub
4. **Install the plugin in Wireshark**
5. **Connect to Wireshark** for detailed packet analysis
6. **Monitor inter-node communication** and consensus messages

**Note:** Wireshark 4.4.0 is not supported. Use Wireshark 4.4.1 or later.

### Edgeshark Setup Details

The `setup-edgeshark.sh` script uses the official Edgeshark deployment method. It:

1. Creates a separate `edgeshark/` directory to avoid conflicts
2. Downloads the official Edgeshark Docker Compose configuration
3. Deploys Edgeshark in a separate container stack
4. Provides access to monitor all Docker networks including your Ethereum network

**Manual Setup Alternative:**
```bash
mkdir -p edgeshark && cd edgeshark
wget -q --no-cache -O - \
https://github.com/siemens/edgeshark/raw/main/deployments/wget/docker-compose.yaml \
| DOCKER_DEFAULT_PLATFORM= docker compose -f - up -d
```

**Required for Wireshark Integration:**
- Download the csharg extcap plugin from: https://github.com/siemens/cshargextcap
- Install the plugin in your Wireshark installation

## Connecting to Geth Nodes

### Quick Connection Scripts

**Interactive Console Access:**
```bash
# Quick connect to any node
./scripts/quick-connect.sh 1    # Connect to node 1
./scripts/quick-connect.sh 2    # Connect to node 2
./scripts/quick-connect.sh 3    # Connect to node 3
./scripts/quick-connect.sh 4    # Connect to node 4

# Show network status
./scripts/quick-connect.sh status
```

**Advanced Connection Options:**
```bash
# Full-featured connection script with menu
./scripts/connect-geth.sh 1

# Direct connection methods:
# - Interactive console (IPC)
# - Single command execution
# - HTTP RPC calls
# - Connection info display
# - Node status check
```

**RPC Examples:**
```bash
# Run RPC examples for any node
./scripts/rpc-examples.sh 1     # Examples for node 1
./scripts/rpc-examples.sh 2     # Examples for node 2

# Includes examples for:
# - Block information
# - Account management
# - Network status
# - Clique consensus
# - Custom RPC calls
```

## Useful Commands

### Direct Docker Commands:

**Check node status:**
```bash
docker exec geth-node1 geth --datadir /root/.ethereum --exec "eth.blockNumber" attach
```

**Get peer information:**
```bash
docker exec geth-node1 geth --datadir /root/.ethereum --exec "admin.peers" attach
```

**Check signers:**
```bash
docker exec geth-node1 geth --datadir /root/.ethereum --exec "clique.getSigners()" attach
```

**View node accounts:**
```bash
docker exec geth-node1 geth --datadir /root/.ethereum --exec "eth.accounts" attach
```

### HTTP RPC Examples:

**Get block number:**
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545
```

**Get network peers:**
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545
```

## File Structure

```
.
├── docker-compose.yml    # Main orchestration file
├── Dockerfile           # Go-Ethereum build configuration
├── genesis.json         # Network genesis configuration
├── contracts/           # Smart contracts for IoT data tracking
│   ├── src/             # Solidity contract source code
│   │   └── IoTDataTracker.sol # Main IoT data contract
│   ├── build/           # Compiled contracts (auto-generated)
│   ├── deployments/     # Deployment records
│   ├── compile.js       # Contract compilation utility
│   ├── deploy.js        # Contract deployment script
│   ├── interact.js      # Contract interaction utilities
│   ├── iot-simulator.js # IoT device simulator
│   ├── package.json     # Node.js dependencies
│   └── README.md        # Contract documentation
├── scripts/             # Utility scripts
│   ├── password.txt     # Account password
│   ├── init-accounts.sh # Account initialization
│   ├── get-enodes.sh    # Enode information retrieval
│   ├── connect-peers.sh # Manual peer connection
│   ├── setup-edgeshark.sh # Edgeshark monitoring setup
│   ├── connect-geth.sh  # Advanced Geth connection script
│   ├── quick-connect.sh # Quick node connection
│   └── rpc-examples.sh  # RPC call examples
├── data/               # Node data directories (auto-created)
│   ├── node1/
│   ├── node2/
│   ├── node3/
│   └── node4/
└── go-ethereum/        # Go-Ethereum source code
```

## Troubleshooting

### Nodes not connecting:
1. Check if all containers are running: `docker-compose ps`
2. Run the peer connection script: `./scripts/connect-peers.sh`
3. Check logs: `docker-compose logs geth-node1`

### Mining not working:
1. Check if the node is a designated signer in genesis.json extraData
2. Verify the clique configuration and block production
3. Ensure minimum 1 signer node is running (needs 1 out of 3 signers active)
4. Note: Account unlocking is not required in current configuration

### Edgeshark not capturing:
1. Ensure Edgeshark has proper permissions
2. Check if the network interface is correctly specified
3. Restart the edgeshark container: `docker-compose restart edgeshark`

## Security Notes

- This setup is configured for development and testing purposes
- Pre-funded accounts are defined in genesis.json for testing
- Account unlocking is currently disabled for security
- In production, use proper key management and secure access controls
- Consider using proper secrets management for production deployments

## Additional Documentation

- **`CLIQUE_NETWORK_SETUP.md`** - Comprehensive setup and configuration guide
- **`QUICK_REFERENCE.md`** - Essential commands and quick reference guide