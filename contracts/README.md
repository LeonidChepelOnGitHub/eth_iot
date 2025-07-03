# IoT Smart Contracts

This folder contains smart contracts and utilities for IoT device data tracking on the Ethereum blockchain. The system is designed to efficiently store only changed sensor data, reducing gas costs and blockchain bloat.

## 🏗️ Architecture

### Smart Contract: `IoTDataTracker.sol`

**Key Features:**
- **Change-Only Storage**: Only stores sensor data when values actually change
- **Multi-Sensor Support**: Devices can have multiple sensors (temperature, humidity, etc.)
- **Batch Updates**: Update multiple sensors in a single transaction
- **History Tracking**: Maintains change history with timestamps
- **Device Management**: Register, activate, and deactivate IoT devices
- **Gas Efficient**: Optimized for minimal gas consumption

**Core Functions:**
- `registerDevice(deviceId, location)` - Register a new IoT device
- `updateSensorData(sensor, value)` - Update single sensor (only if changed)
- `updateMultipleSensors(sensors[], values[])` - Batch update multiple sensors
- `getSensorData(device, sensor)` - Get latest sensor data and metadata
- `getRecentChanges(device, sensor, limit)` - Get change history

## 📁 File Structure

```
contracts/
├── src/
│   └── IoTDataTracker.sol      # Main smart contract
├── build/                      # Compiled contracts (auto-generated)
├── deployments/               # Deployment records (auto-generated)
├── compile.js                 # Solidity compiler utility
├── deploy.js                  # Contract deployment script
├── interact.js                # Contract interaction utilities
├── iot-simulator.js           # Advanced IoT device simulator
├── package.json              # Node.js dependencies
└── README.md                 # This file
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd contracts
npm install
```

### 2. Compile Contracts

```bash
# Compile all contracts
npm run compile

# Or compile specific contract
node compile.js compile IoTDataTracker
```

### 3. Deploy Contract

```bash
# Deploy to local node (port 8545)
npm run deploy

# Deploy to specific node
npm run deploy:node2    # port 8546
npm run deploy:node3    # port 8547
npm run deploy:node4    # port 8548
```

### 4. Interact with Contract

```bash
# Check contract status
npm run status

# Register a device and update sensors
node interact.js register local "Weather-Station-01" "Rooftop"
node interact.js update local temperature "23.5"

# Run IoT device simulation
npm run simulate
```

## 🎯 IoT Device Simulation

### Quick Simulations

```bash
# Smart home scenario (2 minutes)
node iot-simulator.js smart-home local

# Industrial IoT scenario (3 minutes)  
node iot-simulator.js industrial local

# Custom simulation
node iot-simulator.js custom local
```

### Device Templates

**Weather Station:**
- Sensors: temperature, humidity, pressure, light
- Realistic gradual changes with environmental patterns

**Security Sensor:**
- Sensors: motion, door, window, battery
- Event-based changes (motion detection, door opening)

**Air Quality Monitor:**
- Sensors: CO2, PM2.5, PM10, VOC
- Pollution level variations with daily patterns

**Smart Meter:**
- Sensors: power, voltage, current, energy
- Power consumption patterns with cumulative energy

### Example Device Creation

```javascript
const simulator = new AdvancedIoTSimulator('local');
await simulator.initialize();

// Create devices
simulator.createDevice('office-weather', 'weatherStation', 'Office Floor 3', 0);
simulator.createDevice('security-main', 'securitySensor', 'Main Entrance', 1);

// Start simulation
await simulator.startSimulation({
    duration: 120000,  // 2 minutes
    interval: 5000,    // 5 seconds
    devices: ['office-weather', 'security-main']
});
```

## 🛠️ Development Tools

### Compilation

```bash
# Compile all contracts
node compile.js compile-all

# Compile specific contract
node compile.js compile IoTDataTracker

# Check contract size
node compile.js size IoTDataTracker

# Clean build directory
node compile.js clean
```

### Deployment

```bash
# Deploy with specific account
node deploy.js local 0    # Use account index 0
node deploy.js node2 1    # Use account index 1

# Check deployment info
cat deployments/local-latest.json
```

### Contract Interaction

```bash
# Basic interaction
node interact.js help
node interact.js status local
node interact.js register local "Device-123" "Lab Room"
node interact.js update local "temperature" "25.0"

# Device status
node interact.js device-status local 0x123...
```

## 📊 Smart Contract Efficiency

### Gas Optimization Features

1. **Change Detection**: Uses keccak256 hash comparison to detect actual changes
2. **Batch Operations**: `updateMultipleSensors()` for efficient multi-sensor updates
3. **Optimized Storage**: Minimal storage footprint with efficient data structures
4. **Event Logging**: Comprehensive events for off-chain indexing

### Typical Gas Costs

- Device Registration: ~150,000 gas
- First Sensor Update: ~80,000 gas
- Subsequent Updates (if changed): ~45,000 gas
- Unchanged Values: 0 gas (transaction reverts early)
- Batch Update (3 sensors): ~120,000 gas

## 🔗 Integration Examples

### Web3.js Integration

```javascript
const { IoTDeviceSimulator } = require('./interact.js');

const iot = new IoTDeviceSimulator('local');
const accounts = await iot.getAccounts();

// Register device
await iot.registerDevice(accounts[0], 'Sensor-001', 'Greenhouse A');

// Update sensor data
await iot.updateSensorData(accounts[0], 'temperature', '22.5');
await iot.updateSensorData(accounts[0], 'humidity', '65.0');

// Get sensor data
const data = await iot.getSensorData(accounts[0], 'temperature');
console.log(`Temperature: ${data.value} (changed ${data.changeCount} times)`);
```

### REST API Integration

The smart contract can be easily integrated into REST APIs:

```javascript
// Express.js example
app.post('/api/devices/:deviceId/sensors', async (req, res) => {
    const { sensor, value } = req.body;
    const deviceAccount = getDeviceAccount(req.params.deviceId);
    
    try {
        const tx = await iot.updateSensorData(deviceAccount, sensor, value);
        res.json({ success: true, transactionHash: tx.transactionHash });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});
```

## 🔒 Security Features

- **Device Authorization**: Only registered devices can update their sensor data
- **Owner Controls**: Contract owner can activate/deactivate devices
- **Input Validation**: Comprehensive validation of all inputs
- **Event Transparency**: All changes logged via events for auditability

## 📈 Monitoring and Analytics

### Event Monitoring

```javascript
// Listen for data changes
contract.events.DataChanged({
    filter: { device: deviceAddress },
    fromBlock: 'latest'
})
.on('data', event => {
    console.log(`${event.returnValues.sensor}: ${event.returnValues.value}`);
});
```

### Analytics Queries

```javascript
// Get recent changes for analysis
const changes = await iot.getRecentChanges(deviceAddress, 'temperature', 100);
const values = changes.values.map(v => parseFloat(v));
const average = values.reduce((a, b) => a + b) / values.length;
```

## 🧪 Testing

The contracts include comprehensive testing scenarios:

- Device registration and management
- Sensor data updates with change detection
- Batch operations
- Error handling and validation
- Gas consumption optimization
- Event emission verification

## 📚 Additional Resources

- [Solidity Documentation](https://docs.soliditylang.org/)
- [Web3.js Documentation](https://web3js.readthedocs.io/)
- [Ethereum Gas Optimization](https://ethereum.org/en/developers/docs/gas/)
- [IoT Blockchain Integration Patterns](https://ethereum.org/en/use-cases/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.