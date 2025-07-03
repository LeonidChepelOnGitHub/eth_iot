const fs = require('fs');
const path = require('path');
const { Web3 } = require('web3');

// IoT Device Simulator and Contract Interaction
class IoTDeviceSimulator {
    constructor(networkName = 'local', contractAddress = null) {
        const networks = {
            local: 'http://localhost:8545',
            node2: 'http://localhost:8546',
            node3: 'http://localhost:8547',
            node4: 'http://localhost:8548'
        };
        
        const networkUrl = networks[networkName];
        if (!networkUrl) {
            throw new Error(`Network ${networkName} not found`);
        }
        
        this.web3 = new Web3(networkUrl);
        this.networkName = networkName;
        this.contractAddress = contractAddress || this.loadLatestContractAddress();
        
        // Load contract ABI (in real deployment, this would be the compiled ABI)
        this.contractABI = this.getContractABI();
        this.contract = new this.web3.eth.Contract(this.contractABI, this.contractAddress);
        
        console.log(`Connected to ${networkName}: ${networkUrl}`);
        console.log(`Contract address: ${this.contractAddress}`);
    }
    
    loadLatestContractAddress() {
        try {
            const latestFile = path.join(__dirname, 'deployments', `${this.networkName}-latest.json`);
            const deploymentInfo = JSON.parse(fs.readFileSync(latestFile, 'utf8'));
            return deploymentInfo.contractAddress;
        } catch (error) {
            throw new Error(`Could not load contract address for ${this.networkName}. Deploy contract first.`);
        }
    }
    
    getContractABI() {
        try {
            // Load the actual compiled ABI
            const { SolidityCompiler } = require('./compile.js');
            const compiler = new SolidityCompiler();
            const compiledContract = compiler.loadCompiledContract('IoTDataTracker');
            return compiledContract.abi;
        } catch (error) {
            console.warn('Could not load compiled ABI, using fallback');
            // Fallback ABI for basic functionality
            return [
                {
                    "inputs": [{"name": "_deviceId", "type": "string"}, {"name": "_location", "type": "string"}],
                    "name": "registerDevice",
                    "outputs": [],
                    "type": "function"
                },
                {
                    "inputs": [{"name": "_sensor", "type": "string"}, {"name": "_value", "type": "string"}],
                    "name": "updateSensorData",
                    "outputs": [],
                    "type": "function"
                },
                {
                    "inputs": [{"name": "_sensors", "type": "string[]"}, {"name": "_values", "type": "string[]"}],
                    "name": "updateMultipleSensors",
                    "outputs": [],
                    "type": "function"
                },
                {
                    "inputs": [{"name": "_device", "type": "address"}, {"name": "_sensor", "type": "string"}],
                    "name": "getSensorData",
                    "outputs": [{"name": "value", "type": "string"}, {"name": "timestamp", "type": "uint256"}, {"name": "changeCount", "type": "uint256"}],
                    "type": "function"
                },
                {
                    "inputs": [{"name": "_device", "type": "address"}],
                    "name": "getDeviceSensors",
                    "outputs": [{"name": "sensors", "type": "string[]"}],
                    "type": "function"
                },
                {
                    "inputs": [{"name": "_device", "type": "address"}],
                    "name": "getDeviceInfo",
                    "outputs": [{"name": "deviceId", "type": "string"}, {"name": "location", "type": "string"}, {"name": "registrationTime", "type": "uint256"}, {"name": "isActive", "type": "bool"}],
                    "type": "function"
                },
                {
                    "inputs": [],
                    "name": "getDeviceCount",
                    "outputs": [{"name": "", "type": "uint256"}],
                    "type": "function"
                },
                {
                    "inputs": [{"name": "_device", "type": "address"}, {"name": "_sensor", "type": "string"}, {"name": "_limit", "type": "uint256"}],
                    "name": "getRecentChanges",
                    "outputs": [{"name": "values", "type": "string[]"}, {"name": "timestamps", "type": "uint256[]"}],
                    "type": "function"
                }
            ];
        }
    }
    
    async getAccounts() {
        return await this.web3.eth.getAccounts();
    }
    
    async registerDevice(deviceAccount, deviceId, location) {
        try {
            console.log(`Registering device: ${deviceId} at ${location}`);
            
            const tx = await this.contract.methods.registerDevice(deviceId, location).send({
                from: deviceAccount,
                gas: 500000
            });
            
            console.log(`Device registered! Transaction: ${tx.transactionHash}`);
            return tx;
        } catch (error) {
            console.error('Device registration failed:', error.message);
            throw error;
        }
    }
    
    async updateSensorData(deviceAccount, sensor, value) {
        try {
            console.log(`Updating ${sensor}: ${value}`);
            
            const tx = await this.contract.methods.updateSensorData(sensor, value).send({
                from: deviceAccount,
                gas: 300000
            });
            
            console.log(`Sensor updated! Transaction: ${tx.transactionHash}`);
            return tx;
        } catch (error) {
            console.error('Sensor update failed:', error.message);
            throw error;
        }
    }
    
    async updateMultipleSensors(deviceAccount, sensors, values) {
        try {
            console.log(`Updating multiple sensors:`, sensors.map((s, i) => `${s}: ${values[i]}`).join(', '));
            
            const tx = await this.contract.methods.updateMultipleSensors(sensors, values).send({
                from: deviceAccount,
                gas: 800000
            });
            
            console.log(`Multiple sensors updated! Transaction: ${tx.transactionHash}`);
            return tx;
        } catch (error) {
            console.error('Multiple sensor update failed:', error.message);
            throw error;
        }
    }
    
    async getSensorData(deviceAddress, sensor) {
        try {
            const result = await this.contract.methods.getSensorData(deviceAddress, sensor).call();
            return {
                value: result.value,
                timestamp: parseInt(result.timestamp),
                changeCount: parseInt(result.changeCount)
            };
        } catch (error) {
            console.error('Failed to get sensor data:', error.message);
            throw error;
        }
    }
    
    async getDeviceInfo(deviceAddress) {
        try {
            const result = await this.contract.methods.getDeviceInfo(deviceAddress).call();
            return {
                deviceId: result.deviceId,
                location: result.location,
                registrationTime: parseInt(result.registrationTime),
                isActive: result.isActive
            };
        } catch (error) {
            console.error('Failed to get device info:', error.message);
            throw error;
        }
    }
    
    async getDeviceSensors(deviceAddress) {
        try {
            return await this.contract.methods.getDeviceSensors(deviceAddress).call();
        } catch (error) {
            console.error('Failed to get device sensors:', error.message);
            throw error;
        }
    }
    
    async getRecentChanges(deviceAddress, sensor, limit = 10) {
        try {
            const result = await this.contract.methods.getRecentChanges(deviceAddress, sensor, limit).call();
            return {
                values: result.values,
                timestamps: result.timestamps.map(t => parseInt(t))
            };
        } catch (error) {
            console.error('Failed to get recent changes:', error.message);
            throw error;
        }
    }
    
    async getDeviceCount() {
        try {
            const count = await this.contract.methods.getDeviceCount().call();
            return parseInt(count);
        } catch (error) {
            console.error('Failed to get device count:', error.message);
            throw error;
        }
    }
    
    // Simulation methods
    generateRandomSensorData() {
        const sensors = {
            temperature: () => (20 + Math.random() * 15).toFixed(1), // 20-35°C
            humidity: () => (40 + Math.random() * 40).toFixed(1),    // 40-80%
            pressure: () => (980 + Math.random() * 40).toFixed(1),   // 980-1020 hPa
            light: () => Math.floor(Math.random() * 1000),           // 0-1000 lux
            motion: () => Math.random() > 0.8 ? 'detected' : 'none', // Occasional motion
            battery: () => (100 - Math.random() * 100).toFixed(1)    // 0-100%
        };
        
        const sensorType = Object.keys(sensors)[Math.floor(Math.random() * Object.keys(sensors).length)];
        return {
            sensor: sensorType,
            value: sensors[sensorType]().toString()
        };
    }
    
    async simulateDevice(deviceAccount, deviceId, location, duration = 60000, interval = 5000) {
        console.log(`Starting simulation for device: ${deviceId}`);
        console.log(`Duration: ${duration}ms, Interval: ${interval}ms`);
        
        // Register device
        await this.registerDevice(deviceAccount, deviceId, location);
        
        const startTime = Date.now();
        const simulationTimer = setInterval(async () => {
            try {
                const sensorData = this.generateRandomSensorData();
                await this.updateSensorData(deviceAccount, sensorData.sensor, sensorData.value);
                
                if (Date.now() - startTime >= duration) {
                    clearInterval(simulationTimer);
                    console.log(`Simulation completed for device: ${deviceId}`);
                }
            } catch (error) {
                console.error('Simulation error:', error.message);
            }
        }, interval);
        
        return simulationTimer;
    }
    
    async displayDeviceStatus(deviceAddress) {
        try {
            console.log('\n=== Device Status ===');
            
            const deviceInfo = await this.getDeviceInfo(deviceAddress);
            console.log(`Device ID: ${deviceInfo.deviceId}`);
            console.log(`Location: ${deviceInfo.location}`);
            console.log(`Registration: ${new Date(deviceInfo.registrationTime * 1000).toLocaleString()}`);
            console.log(`Active: ${deviceInfo.isActive}`);
            
            const sensors = await this.getDeviceSensors(deviceAddress);
            console.log(`Sensors: ${sensors.length}`);
            
            for (const sensor of sensors) {
                const sensorData = await this.getSensorData(deviceAddress, sensor);
                console.log(`  ${sensor}: ${sensorData.value} (changed ${sensorData.changeCount} times, last: ${new Date(sensorData.timestamp * 1000).toLocaleString()})`);
            }
            
        } catch (error) {
            console.error('Failed to display device status:', error.message);
        }
    }
}

// CLI interface
async function main() {
    const args = process.argv.slice(2);
    const command = args[0] || 'help';
    const networkName = args[1] || 'local';
    
    if (command === 'help') {
        console.log('IoT Contract Interaction Tool');
        console.log('');
        console.log('Usage: node interact.js <command> [network] [args...]');
        console.log('');
        console.log('Commands:');
        console.log('  help                     - Show this help');
        console.log('  status [network]         - Show contract status');
        console.log('  register [network] [deviceId] [location] - Register a device');
        console.log('  update [network] [sensor] [value] - Update sensor data');
        console.log('  simulate [network] [deviceId] [location] - Simulate device data');
        console.log('  device-status [network] [address] - Show device status');
        console.log('');
        console.log('Networks: local, node2, node3, node4');
        return;
    }
    
    try {
        const iot = new IoTDeviceSimulator(networkName);
        const accounts = await iot.getAccounts();
        
        switch (command) {
            case 'status':
                const deviceCount = await iot.getDeviceCount();
                console.log(`Contract Status:`);
                console.log(`Network: ${networkName}`);
                console.log(`Contract Address: ${iot.contractAddress}`);
                console.log(`Total Devices: ${deviceCount}`);
                break;
                
            case 'register':
                const deviceId = args[2] || 'IoT-Device-' + Date.now();
                const location = args[3] || 'Unknown Location';
                await iot.registerDevice(accounts[0], deviceId, location);
                break;
                
            case 'update':
                const sensor = args[2] || 'temperature';
                const value = args[3] || '25.0';
                await iot.updateSensorData(accounts[0], sensor, value);
                break;
                
            case 'simulate':
                const simDeviceId = args[2] || 'Sim-Device-' + Date.now();
                const simLocation = args[3] || 'Simulation Lab';
                await iot.simulateDevice(accounts[0], simDeviceId, simLocation, 30000, 3000);
                break;
                
            case 'device-status':
                const deviceAddress = args[2] || accounts[0];
                await iot.displayDeviceStatus(deviceAddress);
                break;
                
            default:
                console.log(`Unknown command: ${command}`);
                console.log('Use "help" for available commands');
        }
        
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = { IoTDeviceSimulator };