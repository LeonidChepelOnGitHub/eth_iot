const { Web3 } = require('web3');

async function testConnection() {
    const networks = {
        local: 'http://127.0.0.1:8545',
        node2: 'http://127.0.0.1:8546',
        node3: 'http://127.0.0.1:8547',
        node4: 'http://127.0.0.1:8548'
    };
    
    for (const [name, url] of Object.entries(networks)) {
        try {
            console.log(`\nTesting ${name} (${url})...`);
            
            const web3 = new Web3(url);
            
            // Test basic connectivity
            const networkId = await web3.eth.net.getId();
            console.log(`✓ Network ID: ${networkId}`);
            
            const blockNumber = await web3.eth.getBlockNumber();
            console.log(`✓ Block Number: ${blockNumber}`);
            
            const accounts = await web3.eth.getAccounts();
            console.log(`✓ Accounts: ${accounts.length} found`);
            if (accounts.length > 0) {
                console.log(`  First account: ${accounts[0]}`);
                
                const balance = await web3.eth.getBalance(accounts[0]);
                const balanceEth = web3.utils.fromWei(balance, 'ether');
                console.log(`  Balance: ${balanceEth} ETH`);
            }
            
            const gasPrice = await web3.eth.getGasPrice();
            console.log(`✓ Gas Price: ${gasPrice} wei`);
            
            console.log(`✅ ${name} is working!`);
            
        } catch (error) {
            console.log(`❌ ${name} failed: ${error.message}`);
        }
    }
}

testConnection().catch(console.error);