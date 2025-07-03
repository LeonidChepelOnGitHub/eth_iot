// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IoTDataTracker
 * @dev Smart contract for efficient IoT data storage - only stores changed values
 * @author IoT Network
 */
contract IoTDataTracker {
    
    // Events for data changes
    event DataChanged(
        address indexed device,
        string indexed sensor,
        uint256 indexed timestamp,
        bytes32 valueHash,
        string value
    );
    
    event DeviceRegistered(
        address indexed device,
        string deviceId,
        string location,
        uint256 timestamp
    );
    
    // Struct to store device information
    struct Device {
        string deviceId;
        string location;
        uint256 registrationTime;
        bool isActive;
        mapping(string => SensorData) sensors;
        string[] sensorList;
    }
    
    // Struct to store sensor data
    struct SensorData {
        string lastValue;
        uint256 lastTimestamp;
        bytes32 lastValueHash;
        uint256 changeCount;
        bool exists;
    }
    
    // Struct for data change history
    struct DataChange {
        string sensor;
        string value;
        uint256 timestamp;
        address device;
    }
    
    // Mappings
    mapping(address => Device) public devices;
    mapping(bytes32 => DataChange) public dataHistory;
    
    // Arrays for enumeration
    address[] public deviceList;
    bytes32[] public changeHashes;
    
    // Contract owner
    address public owner;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredDevice() {
        require(devices[msg.sender].isActive, "Device not registered or inactive");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Register a new IoT device
     * @param _deviceId Unique identifier for the device
     * @param _location Physical location of the device
     */
    function registerDevice(string memory _deviceId, string memory _location) external {
        require(!devices[msg.sender].isActive, "Device already registered");
        require(bytes(_deviceId).length > 0, "Device ID cannot be empty");
        
        Device storage device = devices[msg.sender];
        device.deviceId = _deviceId;
        device.location = _location;
        device.registrationTime = block.timestamp;
        device.isActive = true;
        
        deviceList.push(msg.sender);
        
        emit DeviceRegistered(msg.sender, _deviceId, _location, block.timestamp);
    }
    
    /**
     * @dev Update sensor data only if it has changed
     * @param _sensor Name of the sensor (e.g., "temperature", "humidity")
     * @param _value New sensor value
     */
    function updateSensorData(string memory _sensor, string memory _value) external onlyRegisteredDevice {
        _updateSensorDataInternal(_sensor, _value);
    }
    
    /**
     * @dev Batch update multiple sensor values
     * @param _sensors Array of sensor names
     * @param _values Array of corresponding values
     */
    function updateMultipleSensors(string[] memory _sensors, string[] memory _values) external onlyRegisteredDevice {
        require(_sensors.length == _values.length, "Arrays length mismatch");
        require(_sensors.length > 0, "Empty arrays not allowed");
        
        for (uint i = 0; i < _sensors.length; i++) {
            _updateSensorDataInternal(_sensors[i], _values[i]);
        }
    }
    
    /**
     * @dev Internal function to update sensor data
     * @param _sensor Name of the sensor
     * @param _value New sensor value
     */
    function _updateSensorDataInternal(string memory _sensor, string memory _value) internal {
        require(bytes(_sensor).length > 0, "Sensor name cannot be empty");
        require(bytes(_value).length > 0, "Value cannot be empty");
        
        bytes32 valueHash = keccak256(abi.encodePacked(_value));
        Device storage device = devices[msg.sender];
        SensorData storage sensorData = device.sensors[_sensor];
        
        // Initialize sensor if it doesn't exist
        if (!sensorData.exists) {
            device.sensorList.push(_sensor);
            sensorData.exists = true;
        }
        
        // Only update if value has changed
        if (sensorData.lastValueHash != valueHash) {
            sensorData.lastValue = _value;
            sensorData.lastTimestamp = block.timestamp;
            sensorData.lastValueHash = valueHash;
            sensorData.changeCount++;
            
            // Store in history
            bytes32 changeHash = keccak256(abi.encodePacked(msg.sender, _sensor, block.timestamp, valueHash));
            dataHistory[changeHash] = DataChange({
                sensor: _sensor,
                value: _value,
                timestamp: block.timestamp,
                device: msg.sender
            });
            
            changeHashes.push(changeHash);
            
            emit DataChanged(msg.sender, _sensor, block.timestamp, valueHash, _value);
        }
    }
    
    /**
     * @dev Get the latest value for a specific sensor of a device
     * @param _device Device address
     * @param _sensor Sensor name
     * @return value Latest sensor value
     * @return timestamp Timestamp of last update
     * @return changeCount Number of times this sensor value changed
     */
    function getSensorData(address _device, string memory _sensor) external view 
        returns (string memory value, uint256 timestamp, uint256 changeCount) {
        require(devices[_device].isActive, "Device not registered");
        
        SensorData storage sensorData = devices[_device].sensors[_sensor];
        require(sensorData.exists, "Sensor not found");
        
        return (sensorData.lastValue, sensorData.lastTimestamp, sensorData.changeCount);
    }
    
    /**
     * @dev Get all sensors for a device
     * @param _device Device address
     * @return sensors Array of sensor names
     */
    function getDeviceSensors(address _device) external view returns (string[] memory sensors) {
        require(devices[_device].isActive, "Device not registered");
        return devices[_device].sensorList;
    }
    
    /**
     * @dev Get device information
     * @param _device Device address
     * @return deviceId Device identifier
     * @return location Device location
     * @return registrationTime Registration timestamp
     * @return isActive Device status
     */
    function getDeviceInfo(address _device) external view 
        returns (string memory deviceId, string memory location, uint256 registrationTime, bool isActive) {
        Device storage device = devices[_device];
        return (device.deviceId, device.location, device.registrationTime, device.isActive);
    }
    
    /**
     * @dev Get total number of registered devices
     */
    function getDeviceCount() external view returns (uint256) {
        return deviceList.length;
    }
    
    /**
     * @dev Get total number of data changes
     */
    function getChangeCount() external view returns (uint256) {
        return changeHashes.length;
    }
    
    /**
     * @dev Get data change by hash
     * @param _changeHash Hash of the data change
     */
    function getDataChange(bytes32 _changeHash) external view 
        returns (string memory sensor, string memory value, uint256 timestamp, address device) {
        DataChange storage change = dataHistory[_changeHash];
        return (change.sensor, change.value, change.timestamp, change.device);
    }
    
    /**
     * @dev Deactivate a device (only owner)
     * @param _device Device address to deactivate
     */
    function deactivateDevice(address _device) external onlyOwner {
        require(devices[_device].isActive, "Device not active");
        devices[_device].isActive = false;
    }
    
    /**
     * @dev Reactivate a device (only owner)
     * @param _device Device address to reactivate
     */
    function reactivateDevice(address _device) external onlyOwner {
        require(!devices[_device].isActive, "Device already active");
        require(bytes(devices[_device].deviceId).length > 0, "Device never registered");
        devices[_device].isActive = true;
    }
    
    /**
     * @dev Get recent changes for a device and sensor
     * @param _device Device address
     * @param _sensor Sensor name
     * @param _limit Maximum number of recent changes to return
     */
    function getRecentChanges(address _device, string memory _sensor, uint256 _limit) 
        external view returns (string[] memory values, uint256[] memory timestamps) {
        
        require(_limit > 0 && _limit <= 100, "Limit must be between 1 and 100");
        
        uint256 matchCount = 0;
        uint256 totalChanges = changeHashes.length;
        
        // Count matching changes
        for (uint256 i = 0; i < totalChanges && matchCount < _limit; i++) {
            uint256 index = totalChanges - 1 - i; // Start from most recent
            DataChange storage change = dataHistory[changeHashes[index]];
            if (change.device == _device && 
                keccak256(abi.encodePacked(change.sensor)) == keccak256(abi.encodePacked(_sensor))) {
                matchCount++;
            }
        }
        
        // Collect matching changes
        values = new string[](matchCount);
        timestamps = new uint256[](matchCount);
        
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < totalChanges && resultIndex < matchCount; i++) {
            uint256 index = totalChanges - 1 - i; // Start from most recent
            DataChange storage change = dataHistory[changeHashes[index]];
            if (change.device == _device && 
                keccak256(abi.encodePacked(change.sensor)) == keccak256(abi.encodePacked(_sensor))) {
                values[resultIndex] = change.value;
                timestamps[resultIndex] = change.timestamp;
                resultIndex++;
            }
        }
        
        return (values, timestamps);
    }
}