const Web3 = require('web3');

// Connect to local node
const web3 = new Web3('http://127.0.0.1:8545');

async function manageAccounts() {
    try {
        // Get existing accounts
        const accounts = await web3.eth.getAccounts();
        console.log('📋 Existing accounts:', accounts);
        
        // Check balances
        console.log('\n💰 Account Balances:');
        for (const account of accounts) {
            const balance = await web3.eth.getBalance(account);
            const balanceEth = web3.utils.fromWei(balance, 'ether');
            console.log(`${account}: ${balanceEth} ETH`);
        }
        
        // Create new account (requires personal API enabled)
        console.log('\n🆕 Creating new account...');
        try {
            const newAccount = await web3.eth.personal.newAccount('password123');
            console.log('New account created:', newAccount);
            
            // Transfer funds to new account
            console.log('\n💸 Transferring funds...');
            const fromAccount = accounts[0]; // First account (pre-funded)
            
            // Unlock sender account
            await web3.eth.personal.unlockAccount(fromAccount, 'password123', 300);
            
            // Send transaction
            const tx = await web3.eth.sendTransaction({
                from: fromAccount,
                to: newAccount,
                value: web3.utils.toWei('10', 'ether'),
                gas: 21000
            });
            
            console.log('Transaction hash:', tx.transactionHash);
            
            // Check new balance
            const newBalance = await web3.eth.getBalance(newAccount);
            console.log(`New account balance: ${web3.utils.fromWei(newBalance, 'ether')} ETH`);
            
        } catch (personalError) {
            console.log('⚠️  Personal API not available. Use geth console for account creation.');
        }
        
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// Helper function to convert Wei to Ether
function weiToEther(wei) {
    return web3.utils.fromWei(wei.toString(), 'ether');
}

// Helper function to convert Ether to Wei
function etherToWei(eth) {
    return web3.utils.toWei(eth.toString(), 'ether');
}

// Export functions for use in other scripts
module.exports = {
    manageAccounts,
    weiToEther,
    etherToWei,
    web3
};

// Run if called directly
if (require.main === module) {
    manageAccounts();
}