# Clique Network Quick Reference

## Essential Commands

### Start/Stop Network
```bash
# Start all nodes
docker-compose up -d

# Stop all nodes
docker-compose down

# Restart single node
docker-compose restart geth-node1

# View logs
docker logs geth-node1 -f
```

### Network Status Checks
```bash
# Check all RPC endpoints
for port in 8545 8546 8547 8548; do
  echo "Node on port $port:"
  curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://127.0.0.1:$port | jq .result
done

# Check running containers
docker ps --filter "name=geth-node"
```

### Geth Console Access
```bash
# Connect to any node's console
docker exec -it geth-node1 geth attach /root/.ethereum/geth.ipc

# Quick status commands in console
> eth.blockNumber
> net.peerCount
> eth.mining
> clique.getSigners()
> admin.peers
> eth.accounts
```

### Account Management
```bash
# Create new account (in geth console)
> personal.newAccount("password")

# List accounts
> eth.accounts

# Check balance (replace address)
> eth.getBalance("0x38d7ff8ef1bdda255caa19bb065802455783b2ee")
```

### Clique Operations
```bash
# In geth console:

# Check current signers
> clique.getSigners()

# Get clique status
> clique.status()

# Propose new authority (true=add, false=remove)
> clique.propose("0xnewaddress", true)

# Check pending proposals
> clique.proposals
```

### Transaction Operations
```bash
# Send transaction (in geth console)
> eth.sendTransaction({
    from: eth.accounts[0],
    to: "0xrecipientaddress",
    value: web3.toWei(1, "ether"),
    gas: 21000
  })

# Check transaction receipt
> eth.getTransactionReceipt("0xtxhash")
```

## API Endpoints

### HTTP RPC Endpoints
- Node 1: http://localhost:8545
- Node 2: http://localhost:8546  
- Node 3: http://localhost:8547
- Node 4: http://localhost:8548

### WebSocket Endpoints
- All nodes: ws://localhost:8546 (internal port)

### Common RPC Calls
```bash
# Get latest block
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}' \
  http://localhost:8545

# Get peer count
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545

# Get chain ID
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8545
```

## File Structure
```
eth_iot/
├── docker-compose.yml          # Main network configuration
├── Dockerfile                  # Geth build configuration  
├── genesis.json               # Clique genesis block
├── scripts/
│   └── password.txt           # Default password file
├── data/                      # Persistent blockchain data
│   ├── node1/
│   ├── node2/
│   ├── node3/
│   └── node4/
├── contracts/                 # Smart contract development
└── CLIQUE_NETWORK_SETUP.md   # Full documentation
```

## Troubleshooting Quick Fixes

### Issue: Containers not starting
```bash
# Check logs for errors
docker logs geth-node1

# Common solutions:
# 1. Remove invalid flags from docker-compose.yml
# 2. Check genesis.json extraData length (must be even)
# 3. Ensure no port conflicts
```

### Issue: RPC not accessible
```bash
# Verify HTTP server started
docker logs geth-node1 | grep "HTTP server started"

# Check port binding
docker port geth-node1
```

### Issue: Nodes not syncing
```bash
# Check peer connections
docker exec geth-node1 geth attach --exec "admin.peers" /root/.ethereum/geth.ipc

# Verify same genesis hash
docker exec geth-node1 geth attach --exec "eth.getBlock(0).hash" /root/.ethereum/geth.ipc
```

### Issue: No blocks being mined
```bash
# Check if mining
docker exec geth-node1 geth attach --exec "eth.mining" /root/.ethereum/geth.ipc

# Check signers
docker exec geth-node1 geth attach --exec "clique.getSigners()" /root/.ethereum/geth.ipc

# Ensure minimum 1 signer is mining
```

## Network Parameters
- **Chain ID**: 1337
- **Network ID**: 1337  
- **Block Time**: 15 seconds
- **Consensus**: Clique PoA
- **Initial Authorities**: 3 nodes
- **Total Nodes**: 4 nodes

## Security Notes
- Default accounts have pre-funded balances for testing
- No account unlocking in current configuration (safer)
- All RPC endpoints allow CORS for development
- Use proper security for production deployments