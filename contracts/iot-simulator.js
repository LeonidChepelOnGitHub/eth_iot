const { IoTDeviceSimulator } = require('./interact.js');

/**
 * Advanced IoT Device Simulator for testing the smart contract
 * Simulates multiple devices with realistic sensor patterns
 */
class AdvancedIoTSimulator {
    constructor(networkName = 'local') {
        this.iot = new IoTDeviceSimulator(networkName);
        this.devices = new Map();
        this.isRunning = false;
        
        // Device templates with realistic sensor patterns
        this.deviceTemplates = {
            weatherStation: {
                sensors: ['temperature', 'humidity', 'pressure', 'light'],
                patterns: {
                    temperature: { min: 15, max: 35, change: 0.5 },
                    humidity: { min: 30, max: 80, change: 2 },
                    pressure: { min: 980, max: 1020, change: 1 },
                    light: { min: 0, max: 1000, change: 50 }
                }
            },
            securitySensor: {
                sensors: ['motion', 'door', 'window', 'battery'],
                patterns: {
                    motion: { values: ['detected', 'none'], probability: 0.1 },
                    door: { values: ['open', 'closed'], probability: 0.05 },
                    window: { values: ['open', 'closed'], probability: 0.03 },
                    battery: { min: 0, max: 100, change: -0.1 }
                }
            },
            airQuality: {
                sensors: ['co2', 'pm2_5', 'pm10', 'voc'],
                patterns: {
                    co2: { min: 400, max: 2000, change: 10 },
                    pm2_5: { min: 0, max: 100, change: 2 },
                    pm10: { min: 0, max: 150, change: 3 },
                    voc: { min: 0, max: 500, change: 5 }
                }
            },
            smartMeter: {
                sensors: ['power', 'voltage', 'current', 'energy'],
                patterns: {
                    power: { min: 100, max: 5000, change: 50 },
                    voltage: { min: 220, max: 240, change: 1 },
                    current: { min: 0, max: 25, change: 1 },
                    energy: { min: 0, max: 999999, change: 1 }
                }
            }
        };
    }
    
    async initialize() {
        const accounts = await this.iot.getAccounts();
        this.accounts = accounts;
        
        // Read password from file
        const fs = require('fs');
        const path = require('path');
        let password = '';
        try {
            const passwordPath = path.join(__dirname, '../scripts/password.txt');
            password = fs.readFileSync(passwordPath, 'utf8').trim();
            console.log('Loaded password from password.txt');
        } catch (error) {
            console.log('Could not read password.txt, using empty password');
            password = '';
        }
        
        // Unlock all accounts for transactions
        console.log('Unlocking accounts...');
        for (let i = 0; i < accounts.length; i++) {
            try {
                await this.iot.web3.eth.personal.unlockAccount(accounts[i], password, 0);
                console.log(`Unlocked account ${i}: ${accounts[i]}`);
            } catch (error) {
                // Accounts might already be unlocked or not require unlocking
                console.log(`Account ${i} (${accounts[i]}): ${error.message.includes('already unlocked') ? 'already unlocked' : 'unlock not required'}`);
            }
        }
        
        console.log(`Initialized with ${accounts.length} available accounts`);
    }
    
    createDevice(deviceId, template, location, accountIndex = 0) {
        if (accountIndex >= this.accounts.length) {
            throw new Error(`Account index ${accountIndex} not available`);
        }
        
        const deviceTemplate = this.deviceTemplates[template];
        if (!deviceTemplate) {
            throw new Error(`Device template '${template}' not found`);
        }
        
        const device = {
            id: deviceId,
            template: template,
            location: location,
            account: this.accounts[accountIndex],
            sensors: deviceTemplate.sensors,
            patterns: deviceTemplate.patterns,
            lastValues: {},
            isRegistered: false,
            updateCount: 0
        };
        
        // Initialize last values
        deviceTemplate.sensors.forEach(sensor => {
            const pattern = deviceTemplate.patterns[sensor];
            if (pattern.values) {
                device.lastValues[sensor] = pattern.values[0];
            } else {
                device.lastValues[sensor] = ((pattern.min + pattern.max) / 2).toFixed(2);
            }
        });
        
        this.devices.set(deviceId, device);
        console.log(`Created ${template} device: ${deviceId} at ${location}`);
        return device;
    }
    
    async registerDevice(deviceId) {
        const device = this.devices.get(deviceId);
        if (!device) {
            throw new Error(`Device ${deviceId} not found`);
        }
        
        if (device.isRegistered) {
            console.log(`Device ${deviceId} already registered`);
            return;
        }
        
        // Check if device is already registered on the blockchain
        try {
            const deviceInfo = await this.iot.getDeviceInfo(device.account);
            if (deviceInfo.isActive) {
                console.log(`Device ${deviceId} (${device.account}) already registered on blockchain: ${deviceInfo.deviceId}`);
                device.isRegistered = true;
                return;
            }
        } catch (error) {
            // Device not registered on blockchain, continue with registration
        }
        
        await this.iot.registerDevice(device.account, device.id, device.location);
        device.isRegistered = true;
        console.log(`Registered device: ${deviceId}`);
    }
    
    generateSensorValue(device, sensor) {
        const pattern = device.patterns[sensor];
        let newValue;
        
        if (pattern.values) {
            // Discrete values (e.g., motion: detected/none)
            if (Math.random() < pattern.probability) {
                const otherValues = pattern.values.filter(v => v !== device.lastValues[sensor]);
                newValue = otherValues[Math.floor(Math.random() * otherValues.length)];
            } else {
                newValue = device.lastValues[sensor];
            }
        } else {
            // Continuous values with drift
            const currentValue = parseFloat(device.lastValues[sensor]);
            const change = (Math.random() - 0.5) * 2 * pattern.change;
            newValue = Math.max(pattern.min, Math.min(pattern.max, currentValue + change));
            
            // Special handling for energy meter (always increasing)
            if (sensor === 'energy') {
                newValue = currentValue + Math.abs(change);
            }
            
            newValue = newValue.toFixed(2);
        }
        
        return newValue;
    }
    
    async updateDeviceSensors(deviceId) {
        const device = this.devices.get(deviceId);
        if (!device || !device.isRegistered) {
            return;
        }
        
        const sensorsToUpdate = [];
        const valuesToUpdate = [];
        let hasChanges = false;
        
        for (const sensor of device.sensors) {
            const newValue = this.generateSensorValue(device, sensor);
            
            // Only update if value changed (simulating the smart contract's efficiency)
            if (newValue !== device.lastValues[sensor]) {
                sensorsToUpdate.push(sensor);
                valuesToUpdate.push(newValue);
                device.lastValues[sensor] = newValue;
                hasChanges = true;
            }
        }
        
        if (hasChanges) {
            try {
                if (sensorsToUpdate.length === 1) {
                    await this.iot.updateSensorData(device.account, sensorsToUpdate[0], valuesToUpdate[0]);
                } else {
                    await this.iot.updateMultipleSensors(device.account, sensorsToUpdate, valuesToUpdate);
                }
                
                device.updateCount++;
                console.log(`${deviceId}: Updated ${sensorsToUpdate.length} sensors (${sensorsToUpdate.join(', ')})`);
                
            } catch (error) {
                console.error(`Failed to update ${deviceId}:`, error.message);
            }
        }
    }
    
    async startSimulation(options = {}) {
        const {
            duration = 60000,     // 1 minute default
            interval = 5000,      // 5 seconds default
            devices = []          // specific devices to simulate, empty = all
        } = options;
        
        if (this.isRunning) {
            console.log('Simulation already running');
            return;
        }
        
        this.isRunning = true;
        const devicesToSimulate = devices.length > 0 ? devices : Array.from(this.devices.keys());
        
        console.log(`Starting simulation for ${devicesToSimulate.length} devices`);
        console.log(`Duration: ${duration}ms, Interval: ${interval}ms`);
        
        // Register all devices first
        for (const deviceId of devicesToSimulate) {
            try {
                await this.registerDevice(deviceId);
            } catch (error) {
                console.error(`Failed to register ${deviceId}:`, error.message);
            }
        }
        
        const startTime = Date.now();
        
        const simulationTimer = setInterval(async () => {
            if (!this.isRunning) {
                clearInterval(simulationTimer);
                return;
            }
            
            // Update all devices in parallel
            const updatePromises = devicesToSimulate.map(deviceId => 
                this.updateDeviceSensors(deviceId)
            );
            
            try {
                await Promise.all(updatePromises);
            } catch (error) {
                console.error('Simulation error:', error.message);
            }
            
            // Check if simulation duration is reached
            if (Date.now() - startTime >= duration) {
                this.stopSimulation();
                clearInterval(simulationTimer);
            }
        }, interval);
        
        return simulationTimer;
    }
    
    stopSimulation() {
        this.isRunning = false;
        console.log('Simulation stopped');
        this.printSimulationSummary();
    }
    
    printSimulationSummary() {
        console.log('\n=== Simulation Summary ===');
        
        for (const [deviceId, device] of this.devices.entries()) {
            if (device.isRegistered) {
                console.log(`${deviceId} (${device.template}):`);
                console.log(`  Location: ${device.location}`);
                console.log(`  Account: ${device.account}`);
                console.log(`  Updates: ${device.updateCount}`);
                console.log(`  Current values:`);
                
                for (const sensor of device.sensors) {
                    console.log(`    ${sensor}: ${device.lastValues[sensor]}`);
                }
                console.log('');
            }
        }
    }
    
    async displayNetworkStatus() {
        console.log('\n=== Network Status ===');
        
        const deviceCount = await this.iot.getDeviceCount();
        console.log(`Total devices on network: ${deviceCount}`);
        
        for (const [deviceId, device] of this.devices.entries()) {
            if (device.isRegistered) {
                await this.iot.displayDeviceStatus(device.account);
            }
        }
    }
    
    // Predefined simulation scenarios
    async runSmartHomeScenario() {
        console.log('Running Smart Home scenario...');
        
        this.createDevice('living-room-weather', 'weatherStation', 'Living Room', 0);
        this.createDevice('bedroom-weather', 'weatherStation', 'Bedroom', 1);
        this.createDevice('security-system', 'securitySensor', 'Main Entrance', 2);
        this.createDevice('air-quality-monitor', 'airQuality', 'Kitchen', 2);
        
        await this.startSimulation({
            duration: 120000,  // 2 minutes
            interval: 8000     // 8 seconds
        });
    }
    
    async runIndustrialScenario() {
        console.log('Running Industrial IoT scenario...');
        
        this.createDevice('factory-weather', 'weatherStation', 'Factory Floor', 0);
        this.createDevice('machine-1-power', 'smartMeter', 'Machine 1', 1);
        this.createDevice('machine-2-power', 'smartMeter', 'Machine 2', 2);
        this.createDevice('air-quality-factory', 'airQuality', 'Production Area', 0);
        this.createDevice('security-factory', 'securitySensor', 'Factory Entrance', 1);
        
        await this.startSimulation({
            duration: 180000,  // 3 minutes
            interval: 6000     // 6 seconds
        });
    }
}

// CLI interface
async function main() {
    const args = process.argv.slice(2);
    const command = args[0] || 'help';
    const networkName = args[1] || 'local';
    
    if (command === 'help') {
        console.log('Advanced IoT Simulator');
        console.log('');
        console.log('Usage: node iot-simulator.js <command> [network] [args...]');
        console.log('');
        console.log('Commands:');
        console.log('  help                     - Show this help');
        console.log('  smart-home [network]     - Run smart home scenario');
        console.log('  industrial [network]     - Run industrial IoT scenario');
        console.log('  custom [network]         - Custom simulation setup');
        console.log('  status [network]         - Show network status');
        console.log('');
        console.log('Networks: local, node2, node3, node4');
        console.log('');
        console.log('Device Templates:');
        console.log('  weatherStation  - Temperature, humidity, pressure, light');
        console.log('  securitySensor  - Motion, door, window, battery');
        console.log('  airQuality      - CO2, PM2.5, PM10, VOC');
        console.log('  smartMeter      - Power, voltage, current, energy');
        return;
    }
    
    try {
        const simulator = new AdvancedIoTSimulator(networkName);
        await simulator.initialize();
        
        switch (command) {
            case 'smart-home':
                await simulator.runSmartHomeScenario();
                break;
                
            case 'industrial':
                await simulator.runIndustrialScenario();
                break;
                
            case 'custom':
                console.log('Custom simulation setup:');
                simulator.createDevice('custom-device-1', 'weatherStation', 'Test Location', 0);
                simulator.createDevice('custom-device-2', 'securitySensor', 'Test Security', 1);
                
                await simulator.startSimulation({
                    duration: 60000,
                    interval: 5000
                });
                break;
                
            case 'status':
                await simulator.displayNetworkStatus();
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

module.exports = { AdvancedIoTSimulator };