const fs = require('fs');
const path = require('path');
const { Web3 } = require('web3');

// Configuration
const CONFIG = {
    // Network configuration
    networks: {
        local: {
            url: 'http://localhost:8545',
            chainId: 1337
        },
        node2: {
            url: 'http://localhost:8546',
            chainId: 1337
        },
        node3: {
            url: 'http://localhost:8547',
            chainId: 1337
        },
        node4: {
            url: 'http://localhost:8548',
            chainId: 1337
        }
    },
    
    // Gas configuration
    gas: {
        limit: 3000000,
        price: '20000000000' // 20 gwei
    }
};

class ContractDeployer {
    constructor(networkName = 'local') {
        const network = CONFIG.networks[networkName];
        if (!network) {
            throw new Error(`Network ${networkName} not found`);
        }
        
        this.web3 = new Web3(network.url);
        this.networkName = networkName;
        this.chainId = network.chainId;
        
        console.log(`Connected to ${networkName} network: ${network.url}`);
    }
    
    async loadContract() {
        const { SolidityCompiler } = require('./compile.js');
        const compiler = new SolidityCompiler();
        
        try {
            // Load compiled contract
            const compiledContract = compiler.loadCompiledContract('IoTDataTracker');
            console.log('Loading compiled contract...');
            console.log(`ABI entries: ${compiledContract.abi.length}`);
            console.log(`Bytecode size: ${compiledContract.bytecode.length / 2} bytes`);
            
            return {
                abi: compiledContract.abi,
                bytecode: '0x' + compiledContract.bytecode
            };
        } catch (error) {
            console.log('Compiled contract not found, attempting to compile...');
            
            // Try to compile the contract
            const compiledContract = compiler.compile('IoTDataTracker');
            return {
                abi: compiledContract.abi,
                bytecode: '0x' + compiledContract.bytecode
            };
        }
    }
    
    async getAccounts() {
        const accounts = await this.web3.eth.getAccounts();
        console.log(`Found ${accounts.length} accounts`);
        return accounts;
    }
    
    async deployContract(fromAccount) {
        try {
            console.log('Starting contract deployment...');
            
            // Load contract (this would need actual compilation)
            const contract = await this.loadContract();
            
            console.log('Contract loaded successfully');
            console.log(`Deploying from account: ${fromAccount}`);
            
            // Create contract instance
            const contractInstance = new this.web3.eth.Contract(contract.abi);
            
            // Get gas estimate
            const gasEstimate = await contractInstance.deploy({
                data: contract.bytecode
            }).estimateGas();
            
            console.log(`Gas estimate: ${Number(gasEstimate)}`);
            
            // Deploy contract
            const deployTx = contractInstance.deploy({
                data: contract.bytecode
            });
            
            const deployedContract = await deployTx.send({
                from: fromAccount,
                gas: Math.min(Number(gasEstimate) * 2, CONFIG.gas.limit),
                gasPrice: CONFIG.gas.price
            });
            
            console.log('Contract deployed successfully!');
            console.log(`Contract address: ${deployedContract.options.address}`);
            console.log(`Transaction hash: ${deployedContract.transactionHash}`);
            
            // Save deployment info
            const deploymentInfo = {
                network: this.networkName,
                contractAddress: deployedContract.options.address,
                transactionHash: deployedContract.transactionHash,
                deployedBy: fromAccount,
                timestamp: new Date().toISOString(),
                chainId: this.chainId
            };
            
            this.saveDeploymentInfo(deploymentInfo);
            
            return deployedContract;
            
        } catch (error) {
            console.error('Deployment failed:', error.message);
            throw error;
        }
    }
    
    saveDeploymentInfo(info) {
        const deploymentsDir = path.join(__dirname, 'deployments');
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }
        
        const filename = `${info.network}-${Date.now()}.json`;
        const filepath = path.join(deploymentsDir, filename);
        
        fs.writeFileSync(filepath, JSON.stringify(info, null, 2));
        console.log(`Deployment info saved to: ${filepath}`);
        
        // Also save as latest deployment for this network
        const latestPath = path.join(deploymentsDir, `${info.network}-latest.json`);
        fs.writeFileSync(latestPath, JSON.stringify(info, null, 2));
        console.log(`Latest deployment info saved to: ${latestPath}`);
    }
    
    async checkNetwork() {
        try {
            const networkId = await this.web3.eth.net.getId();
            const blockNumber = await this.web3.eth.getBlockNumber();
            const gasPrice = await this.web3.eth.getGasPrice();
            
            console.log(`Network ID: ${Number(networkId)}`);
            console.log(`Current block: ${Number(blockNumber)}`);
            console.log(`Gas price: ${Number(gasPrice)} wei`);
            
            return { networkId, blockNumber, gasPrice };
        } catch (error) {
            console.error('Network check failed:', error.message);
            throw error;
        }
    }
}

// Main deployment function
async function deployIoTContract(networkName = 'local', accountIndex = 0) {
    try {
        console.log('=== IoT Data Tracker Contract Deployment ===');
        console.log(`Network: ${networkName}`);
        console.log(`Account Index: ${accountIndex}`);
        console.log('');
        
        const deployer = new ContractDeployer(networkName);
        
        // Check network status
        await deployer.checkNetwork();
        console.log('');
        
        // Get accounts
        const accounts = await deployer.getAccounts();
        if (accounts.length === 0) {
            throw new Error('No accounts available');
        }
        
        if (accountIndex >= accounts.length) {
            throw new Error(`Account index ${accountIndex} not found. Available: 0-${accounts.length - 1}`);
        }
        
        const deployerAccount = accounts[accountIndex];
        console.log(`Using account: ${deployerAccount}`);
        
        // Check account balance
        const balance = await deployer.web3.eth.getBalance(deployerAccount);
        const balanceEth = deployer.web3.utils.fromWei(balance, 'ether');
        console.log(`Account balance: ${balanceEth} ETH`);
        
        if (parseFloat(balanceEth) < 0.1) {
            console.warn('Warning: Account balance is low. Deployment might fail.');
        }
        
        console.log('');
        
        // Deploy contract
        const contract = await deployer.deployContract(deployerAccount);
        
        console.log('');
        console.log('=== Deployment Complete ===');
        console.log(`Contract Address: ${contract.options.address}`);
        console.log('You can now interact with the contract using the provided scripts.');
        
        return contract;
        
    } catch (error) {
        console.error('Deployment process failed:', error.message);
        process.exit(1);
    }
}

// CLI interface
if (require.main === module) {
    const args = process.argv.slice(2);
    const networkName = args[0] || 'local';
    const accountIndex = parseInt(args[1]) || 0;
    
    console.log('Available networks:', Object.keys(CONFIG.networks).join(', '));
    console.log('');
    
    deployIoTContract(networkName, accountIndex);
}

module.exports = {
    ContractDeployer,
    deployIoTContract,
    CONFIG
};