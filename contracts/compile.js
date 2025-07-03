const solc = require('solc');
const fs = require('fs');
const path = require('path');

class SolidityCompiler {
    constructor() {
        this.contractsDir = path.join(__dirname, 'src');
        this.buildDir = path.join(__dirname, 'build');
        
        // Ensure build directory exists
        if (!fs.existsSync(this.buildDir)) {
            fs.mkdirSync(this.buildDir, { recursive: true });
        }
    }
    
    loadContract(contractName) {
        const contractPath = path.join(this.contractsDir, `${contractName}.sol`);
        if (!fs.existsSync(contractPath)) {
            throw new Error(`Contract file not found: ${contractPath}`);
        }
        
        return fs.readFileSync(contractPath, 'utf8');
    }
    
    createSolcInput(contractName, contractSource) {
        return {
            language: 'Solidity',
            sources: {
                [`${contractName}.sol`]: {
                    content: contractSource
                }
            },
            settings: {
                outputSelection: {
                    '*': {
                        '*': ['abi', 'evm.bytecode', 'evm.deployedBytecode', 'evm.gasEstimates']
                    }
                },
                optimizer: {
                    enabled: true,
                    runs: 200
                },
                evmVersion: 'london'
            }
        };
    }
    
    compile(contractName) {
        try {
            console.log(`Compiling contract: ${contractName}`);
            
            // Load contract source
            const contractSource = this.loadContract(contractName);
            
            // Create solc input
            const input = this.createSolcInput(contractName, contractSource);
            
            // Compile
            const output = JSON.parse(solc.compile(JSON.stringify(input)));
            
            // Check for errors
            if (output.errors) {
                const errors = output.errors.filter(error => error.severity === 'error');
                if (errors.length > 0) {
                    console.error('Compilation errors:');
                    errors.forEach(error => console.error(error.formattedMessage));
                    throw new Error('Compilation failed');
                }
                
                // Show warnings
                const warnings = output.errors.filter(error => error.severity === 'warning');
                if (warnings.length > 0) {
                    console.warn('Compilation warnings:');
                    warnings.forEach(warning => console.warn(warning.formattedMessage));
                }
            }
            
            // Extract compiled contract
            const contractOutput = output.contracts[`${contractName}.sol`][contractName];
            
            if (!contractOutput) {
                throw new Error(`Contract ${contractName} not found in compilation output`);
            }
            
            const compiled = {
                abi: contractOutput.abi,
                bytecode: contractOutput.evm.bytecode.object,
                deployedBytecode: contractOutput.evm.deployedBytecode.object,
                gasEstimates: contractOutput.evm.gasEstimates,
                metadata: {
                    contractName,
                    compiler: solc.version(),
                    compiledAt: new Date().toISOString()
                }
            };
            
            // Save compiled contract
            this.saveCompiledContract(contractName, compiled);
            
            console.log(`✓ Contract ${contractName} compiled successfully`);
            console.log(`  ABI entries: ${compiled.abi.length}`);
            console.log(`  Bytecode size: ${compiled.bytecode.length / 2} bytes`);
            
            return compiled;
            
        } catch (error) {
            console.error(`Failed to compile ${contractName}:`, error.message);
            throw error;
        }
    }
    
    saveCompiledContract(contractName, compiled) {
        // Save full compilation output
        const outputPath = path.join(this.buildDir, `${contractName}.json`);
        fs.writeFileSync(outputPath, JSON.stringify(compiled, null, 2));
        
        // Save ABI separately for easier access
        const abiPath = path.join(this.buildDir, `${contractName}.abi.json`);
        fs.writeFileSync(abiPath, JSON.stringify(compiled.abi, null, 2));
        
        // Save bytecode separately
        const bytecodePath = path.join(this.buildDir, `${contractName}.bin`);
        fs.writeFileSync(bytecodePath, compiled.bytecode);
        
        console.log(`Compilation artifacts saved to ${this.buildDir}/`);
    }
    
    loadCompiledContract(contractName) {
        const outputPath = path.join(this.buildDir, `${contractName}.json`);
        if (!fs.existsSync(outputPath)) {
            throw new Error(`Compiled contract not found: ${outputPath}. Run compilation first.`);
        }
        
        return JSON.parse(fs.readFileSync(outputPath, 'utf8'));
    }
    
    compileAll() {
        console.log('Compiling all contracts...');
        
        const contractFiles = fs.readdirSync(this.contractsDir)
            .filter(file => file.endsWith('.sol'))
            .map(file => path.basename(file, '.sol'));
        
        const results = {};
        
        for (const contractName of contractFiles) {
            try {
                results[contractName] = this.compile(contractName);
            } catch (error) {
                console.error(`Failed to compile ${contractName}`);
                results[contractName] = { error: error.message };
            }
        }
        
        console.log('Compilation summary:');
        Object.entries(results).forEach(([name, result]) => {
            if (result.error) {
                console.log(`  ✗ ${name}: ${result.error}`);
            } else {
                console.log(`  ✓ ${name}: Success`);
            }
        });
        
        return results;
    }
    
    clean() {
        console.log('Cleaning build directory...');
        if (fs.existsSync(this.buildDir)) {
            fs.rmSync(this.buildDir, { recursive: true, force: true });
        }
        fs.mkdirSync(this.buildDir, { recursive: true });
        console.log('Build directory cleaned');
    }
    
    getContractSize(contractName) {
        try {
            const compiled = this.loadCompiledContract(contractName);
            const bytecodeSize = compiled.bytecode.length / 2;
            const deployedSize = compiled.deployedBytecode.length / 2;
            
            console.log(`Contract size for ${contractName}:`);
            console.log(`  Bytecode: ${bytecodeSize} bytes`);
            console.log(`  Deployed: ${deployedSize} bytes`);
            console.log(`  Max size: 24576 bytes (EIP-170 limit)`);
            
            if (deployedSize > 24576) {
                console.warn(`⚠️  Contract exceeds size limit by ${deployedSize - 24576} bytes`);
            } else {
                console.log(`✓ Contract size is within limits (${24576 - deployedSize} bytes remaining)`);
            }
            
            return { bytecodeSize, deployedSize };
        } catch (error) {
            console.error('Failed to get contract size:', error.message);
            throw error;
        }
    }
}

// CLI interface
async function main() {
    const args = process.argv.slice(2);
    const command = args[0] || 'help';
    
    const compiler = new SolidityCompiler();
    
    switch (command) {
        case 'help':
            console.log('Solidity Compiler Tool');
            console.log('');
            console.log('Usage: node compile.js <command> [args...]');
            console.log('');
            console.log('Commands:');
            console.log('  help                    - Show this help');
            console.log('  compile <contract>      - Compile specific contract');
            console.log('  compile-all             - Compile all contracts');
            console.log('  clean                   - Clean build directory');
            console.log('  size <contract>         - Show contract size info');
            console.log('  list                    - List available contracts');
            console.log('');
            console.log('Examples:');
            console.log('  node compile.js compile IoTDataTracker');
            console.log('  node compile.js compile-all');
            console.log('  node compile.js size IoTDataTracker');
            break;
            
        case 'compile':
            const contractName = args[1];
            if (!contractName) {
                console.error('Contract name required');
                process.exit(1);
            }
            compiler.compile(contractName);
            break;
            
        case 'compile-all':
            compiler.compileAll();
            break;
            
        case 'clean':
            compiler.clean();
            break;
            
        case 'size':
            const sizeContractName = args[1];
            if (!sizeContractName) {
                console.error('Contract name required');
                process.exit(1);
            }
            compiler.getContractSize(sizeContractName);
            break;
            
        case 'list':
            const contractsDir = path.join(__dirname, 'src');
            const contracts = fs.readdirSync(contractsDir)
                .filter(file => file.endsWith('.sol'))
                .map(file => path.basename(file, '.sol'));
            
            console.log('Available contracts:');
            contracts.forEach(contract => console.log(`  - ${contract}`));
            break;
            
        default:
            console.log(`Unknown command: ${command}`);
            console.log('Use "help" for available commands');
            process.exit(1);
    }
}

if (require.main === module) {
    main().catch(error => {
        console.error('Error:', error.message);
        process.exit(1);
    });
}

module.exports = { SolidityCompiler };