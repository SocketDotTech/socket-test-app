#!/usr/bin/env tsx

import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
  parseAbi,
  type Abi,
  type Hash,
  type Address,
  type PublicClient,
  type WalletClient
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arbitrumSepolia, optimismSepolia } from 'viem/chains';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// ANSI color codes
const colors = {
  YELLOW: '\x1b[1;33m',
  GREEN: '\x1b[0;32m',
  CYAN: '\x1b[0;36m',
  RED: '\x1b[0;31m',
  NC: '\x1b[0m' // No Color
};

// Types
interface ChainConfig {
  client: any; //PublicClient; Does not work for OP Sepolia. There are different tx types apparently
  walletClient: WalletClient;
  chainId: number;
  explorerUrl: string;
}

interface ContractAddresses {
  appGateway?: Address;
  arbForwarder?: Address;
  arbOnchain?: Address;
  opForwarder?: Address;
  opOnchain?: Address;
}

// Global chain configurations
let evmxChain: ChainConfig;
let arbChain: ChainConfig;
let opChain: ChainConfig;

// Constants
const EVMX_CHAIN_ID = 43;
const ARB_SEP_CHAIN_ID = 421614;
const OP_SEP_CHAIN_ID = 11155420;
const DEPLOY_FEES_AMOUNT = parseEther('10'); // 10 ETH
const TEST_USDC_AMOUNT = BigInt('100000000'); // 100 TEST USDC
const GAS_BUFFER = BigInt('100000000'); // 0.1 Gwei
const GAS_LIMIT = BigInt('50000000000'); // Gas limit estimate

// Environment validation
function validateEnvironment() {
  const required = ['EVMX_RPC', 'PRIVATE_KEY', 'ADDRESS_RESOLVER', 'FEES_MANAGER', 'ARBITRUM_SEPOLIA_RPC', 'OPTIMISM_SEPOLIA_RPC'];
  for (const env of required) {
    if (!process.env[env]) {
      throw new Error(`${env} environment variable is required`);
    }
  }
}

// Setup clients
function setupClients(): void {
  validateEnvironment();

  const account = privateKeyToAccount(process.env.PRIVATE_KEY as Hash);

  const evmxClient = createPublicClient({
    transport: http(process.env.EVMX_RPC)
  });

  const evmxWallet = createWalletClient({
    account,
    transport: http(process.env.EVMX_RPC)
  });

  const arbClient = createPublicClient({
    chain: arbitrumSepolia,
    transport: http(process.env.ARBITRUM_SEPOLIA_RPC)
  });

  const arbWallet = createWalletClient({
    account,
    chain: arbitrumSepolia,
    transport: http(process.env.ARBITRUM_SEPOLIA_RPC)
  });

  const opClient = createPublicClient({
    chain: optimismSepolia,
    transport: http(process.env.OPTIMISM_SEPOLIA_RPC)
  });

  const opWallet = createWalletClient({
    account,
    chain: optimismSepolia,
    transport: http(process.env.OPTIMISM_SEPOLIA_RPC)
  });

  // Set global chain configurations
  evmxChain = {
    client: evmxClient,
    walletClient: evmxWallet,
    chainId: EVMX_CHAIN_ID,
    explorerUrl: 'evmx.cloud.blockscout.com'
  };

  arbChain = {
    client: arbClient,
    walletClient: arbWallet,
    chainId: ARB_SEP_CHAIN_ID,
    explorerUrl: 'arbitrum-sepolia.blockscout.com'
  };

  opChain = {
    client: opClient,
    walletClient: opWallet,
    chainId: OP_SEP_CHAIN_ID,
    explorerUrl: 'optimism-sepolia.blockscout.com'
  };
}

// Build contracts using forge
async function buildContracts(): Promise<void> {
  console.log(`${colors.CYAN}Building contracts${colors.NC}`);
  const execAsync = promisify(exec);

  try {
    await execAsync('forge build');
    console.log('Contracts built successfully');
  } catch (error) {
    console.error(`${colors.RED}Error:${colors.NC} forge build failed. Check your contract code.`);
    throw error;
  }
}

// Deploy contract function
async function deployContract(
  contractName: string,
  constructorArgs: any[] = [],
  chainConfig: ChainConfig = evmxChain
): Promise<Address> {
  console.log(`${colors.CYAN}Deploying ${contractName} contract${colors.NC}`);

  try {
    // Read the compiled contract
    const artifactPath = path.join('out', `${contractName}.sol`, `${contractName}.json`);
    const artifact = JSON.parse(await fs.readFile(artifactPath, 'utf8'));

    const abi = artifact.abi;
    const bytecode = artifact.bytecode.object;

    // Deploy the contract
    const hash = await chainConfig.walletClient.deployContract({
      abi,
      bytecode,
      args: constructorArgs,
      account: chainConfig.walletClient.account!,
      chain: chainConfig.walletClient.chain,
      gasPrice: chainConfig.chainId === EVMX_CHAIN_ID ? 0n : undefined
    });

    await new Promise(resolve => setTimeout(resolve, 2000));
    console.log(`${colors.GREEN}Tx Hash:${colors.NC} ${getExplorerUrl(hash, chainConfig)}`);

    // Get the deployed address
    const receipt = await chainConfig.client.getTransactionReceipt({ hash });

    if (!receipt.contractAddress) {
      throw new Error('Failed to get contract address from deployment');
    }

    const address = receipt.contractAddress;
    console.log(`${colors.GREEN}Contract deployed:${colors.NC} ${getExplorerAddressUrl(address, chainConfig)}`);

    return address;
  } catch (error) {
    console.error(`${colors.RED}Error:${colors.NC} Contract deployment failed.`);
    throw error;
  }
}

// Get explorer URL helper
function getExplorerUrl(hash: Hash, chainConfig: ChainConfig): string {
  return `https://${chainConfig.explorerUrl}/tx/${hash}`;
}

function getExplorerAddressUrl(address: Address, chainConfig: ChainConfig): string {
  return `https://${chainConfig.explorerUrl}/address/${address}`;
}

// Send transaction with consistent error handling
async function sendTransaction(
  to: Address,
  functionName: string,
  args: any[] = [],
  chainConfig: ChainConfig,
  abi: Abi
): Promise<Hash> {
  console.log(`${colors.CYAN}Sending transaction to ${functionName} on ${to}${colors.NC}`);

  try {
    const hash = await chainConfig.walletClient.writeContract({
      address: to,
      abi,
      functionName,
      args,
      account: chainConfig.walletClient.account!,
      chain: chainConfig.walletClient.chain,
      gasPrice: chainConfig.chainId === EVMX_CHAIN_ID ? 0n : undefined
    });

    await new Promise(resolve => setTimeout(resolve, 2000));
    console.log(`${colors.GREEN}Tx Hash:${colors.NC} ${getExplorerUrl(hash, chainConfig)}`);

    return hash;
  } catch (error) {
    console.error(`${colors.RED}Error:${colors.NC} Transaction failed.`);
    throw error;
  }
}

// Deploy AppGateway
async function deployAppGateway(
  filename: string,
  deployFees = DEPLOY_FEES_AMOUNT
): Promise<Address> {
  return deployContract(
    filename,
    [process.env.ADDRESS_RESOLVER, deployFees],
    evmxChain
  );
}

// Deploy onchain contracts
async function deployOnchain(chainId: number, appGateway: Address): Promise<void> {
  console.log(`${colors.CYAN}Deploying onchain contracts for chain id: ${chainId}${colors.NC}`);

  const abi = parseAbi([
    'function deployContracts(uint32 chainId) external'
  ]);

  await sendTransaction(
    appGateway,
    'deployContracts',
    [chainId],
    evmxChain,
    abi
  );
}

// Fetch forwarder and onchain addresses
async function fetchForwarderAndOnchainAddress(
  contractName: string,
  chainId: number,
  appGateway: Address
): Promise<{ forwarder: Address; onchain: Address }> {
  console.log(`${colors.CYAN}Fetching forwarder address for contract '${contractName}' on chain ID ${chainId}${colors.NC}`);

  const contractAbi = parseAbi([
    `function ${contractName}() external view returns (bytes32)`,
    'function forwarderAddresses(bytes32, uint32) external view returns (address)',
    'function getOnChainAddress(bytes32, uint32) external view returns (address)'
  ]);

  // Get contract ID
  const contractId = await evmxChain.client.readContract({
    address: appGateway,
    abi: contractAbi,
    functionName: contractName
  }) as Hash;

  // Wait for forwarder address with progress bar
  let attempts = 0;
  const maxAttempts = 30;
  let forwarder: Address = '0x0000000000000000000000000000000000000000';

  while (attempts < maxAttempts) {
    forwarder = await evmxChain.client.readContract({
      address: appGateway,
      abi: contractAbi,
      functionName: 'forwarderAddresses',
      args: [contractId, chainId]
    }) as Address;

    if (forwarder !== '0x0000000000000000000000000000000000000000') {
      if (attempts > 0) process.stdout.write('\r\x1b[2K');
      break;
    }

    // Progress bar logic here (simplified)
    const percent = Math.floor((attempts * 100) / maxAttempts);
    process.stdout.write(`\r${colors.YELLOW}Waiting for forwarder:${colors.NC} ${percent}%`);

    await new Promise(resolve => setTimeout(resolve, 1000));
    attempts++;
  }

  if (forwarder === '0x0000000000000000000000000000000000000000') {
    throw new Error(`Forwarder address is still zero after ${maxAttempts} seconds for chain ${chainId}`);
  }

  // Get onchain address
  const onchain = await evmxChain.client.readContract({
    address: appGateway,
    abi: contractAbi,
    functionName: 'getOnChainAddress',
    args: [contractId, chainId]
  }) as Address;

  if (onchain === '0x0000000000000000000000000000000000000000') {
    throw new Error(`Onchain address is zero for chain ${chainId}`);
  }

  console.log(`${colors.GREEN}Chain ${chainId}${colors.NC}`);
  console.log(`Forwarder: ${forwarder}`);
  console.log(`Onchain:   ${onchain}`);

  return { forwarder, onchain };
}

// Check available fees
async function checkAvailableFees(appGateway: Address): Promise<bigint> {
  const maxAttempts = 60;
  let attempt = 0;
  let availableFees = 0n;

  const abi = parseAbi([
    'function getAvailableCredits(address) external view returns (uint256)'
  ]);

  while (attempt < maxAttempts) {
    try {
      availableFees = await evmxChain.client.readContract({
        address: process.env.FEES_MANAGER as Address,
        abi,
        functionName: 'getAvailableCredits',
        args: [appGateway]
      }) as bigint;

      if (availableFees > 0n) {
        console.log(`Funds available: ${availableFees} wei`);
        return availableFees;
      }
    } catch (error) {
      console.error(`${colors.RED}Error:${colors.NC} Failed to retrieve available fees.`);
      throw error;
    }

    // Progress bar logic
    const percent = Math.floor((attempt * 100) / maxAttempts);
    process.stdout.write(`\r${colors.YELLOW}Checking fees:${colors.NC} ${percent}%`);

    await new Promise(resolve => setTimeout(resolve, 1000));
    attempt++;
  }

  throw new Error('No funds available after 60 seconds.');
}

// Deposit funds
async function depositFunds(appGateway: Address): Promise<void> {
  console.log(`${colors.CYAN}Depositing funds${colors.NC}`);

  const erc20Abi = parseAbi([
    'function mint(address to, uint256 amount) external',
    'function approve(address spender, uint256 amount) external returns (bool)'
  ]);

  const feesPlugAbi = parseAbi([
    'function depositToFeeAndNative(address token, address appGateway, uint256 amount) external'
  ]);

  const walletAddress = arbChain.walletClient.account?.address;
  if (!walletAddress) throw new Error('Wallet address not found');

  // Mint test USDC
  await sendTransaction(
    process.env.ARBITRUM_TEST_USDC as Address,
    'mint',
    [walletAddress, TEST_USDC_AMOUNT],
    arbChain,
    erc20Abi
  );

  // Approve USDC for FeesPlug
  await sendTransaction(
    process.env.ARBITRUM_TEST_USDC as Address,
    'approve',
    [process.env.ARBITRUM_FEES_PLUG as Address, TEST_USDC_AMOUNT],
    arbChain,
    erc20Abi
  );

  // Deposit funds
  await sendTransaction(
    process.env.ARBITRUM_FEES_PLUG as Address,
    'depositToFeeAndNative',
    [process.env.ARBITRUM_TEST_USDC as Address, appGateway, TEST_USDC_AMOUNT],
    arbChain,
    feesPlugAbi
  );

  await checkAvailableFees(appGateway);
}

// Withdraw funds
async function withdrawFunds(appGateway: Address): Promise<void> {
  console.log(`${colors.CYAN}Withdrawing funds${colors.NC}`);

  const availableFees = await checkAvailableFees(appGateway);

  if (availableFees === 0n) {
    console.log('No available fees to withdraw.');
    return;
  }

  // Get gas price and calculate withdrawal amount
  const gasPrice = await arbChain.client.getGasPrice();
  const estimatedGasCost = GAS_LIMIT * (gasPrice + GAS_BUFFER);

  let amountToWithdraw = 0n;
  if (availableFees > estimatedGasCost) {
    amountToWithdraw = availableFees - estimatedGasCost;
  }

  console.log(`Withdrawing ${amountToWithdraw} wei`);

  if (amountToWithdraw > 0n) {
    const abi = parseAbi([
      'function withdrawFeeTokens(uint32 chainId, address token, uint256 amount, address to) external'
    ]);

    await sendTransaction(
      appGateway,
      'withdrawFeeTokens',
      [ARB_SEP_CHAIN_ID, process.env.ARBITRUM_TEST_USDC, amountToWithdraw, arbChain.walletClient.account?.address],
      evmxChain,
      abi
    );
  } else {
    console.log('No funds available for withdrawal after gas cost estimation.');
  }
}

// Await events function
async function awaitEvents(
  expectedNewEvents: number,
  _eventSignature: string,
  appGateway: Address,
  timeout: number = 180
): Promise<void> {
  console.log(`${colors.CYAN}Waiting logs for ${expectedNewEvents} new events (up to ${timeout} seconds)...${colors.NC}`);

  const interval: number = 2000; // 2 seconds
  let elapsed: number = 0;
  let eventCount: number = 0;

  while (elapsed <= timeout * 1000) {
    try {
      const logs = await evmxChain.client.getLogs({
        address: appGateway,
        fromBlock: 'earliest',
        toBlock: 'latest'
      });

      eventCount = logs.length;

      if (eventCount >= expectedNewEvents) {
        process.stdout.write(`\r`);
        console.log(`\nTotal events on EVMx: ${eventCount} reached (expected ${expectedNewEvents})`);
        break;
      }

      process.stdout.write(`\rWaiting for ${expectedNewEvents} logs on EVMx: ${eventCount}/${expectedNewEvents} (Elapsed: ${elapsed / 1000}/${timeout} sec)`);

      await new Promise(resolve => setTimeout(resolve, interval));
      elapsed += interval;
    } catch (error) {
      console.error('Error fetching logs:', error);
      await new Promise(resolve => setTimeout(resolve, interval));
      elapsed += interval;
    }
  }

  if (eventCount < expectedNewEvents) {
    throw new Error(`\nTimed out after ${timeout} seconds. Expected ${expectedNewEvents} logs, found ${eventCount}.`);
  }
}

// Write tests
async function runWriteTests(addresses: ContractAddresses): Promise<void> {
  console.log(`${colors.CYAN}Running all write tests functions...${colors.NC}`);

  const abi = parseAbi([
    'function triggerSequentialWrite(address forwarder) external',
    'function triggerParallelWrite(address forwarder) external',
    'function triggerAltWrite(address forwarder1, address forwarder2) external'
  ]);

  if (!addresses.appGateway || !addresses.opForwarder || !addresses.arbForwarder) {
    throw new Error('Required addresses not found');
  }

  // 1. Trigger Sequential Write
  await sendTransaction(
    addresses.appGateway,
    'triggerSequentialWrite',
    [addresses.opForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(10, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway);

  // 2. Trigger Parallel Write
  await sendTransaction(
    addresses.appGateway,
    'triggerParallelWrite',
    [addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(20, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway);

  // 3. Trigger Alternating Write
  await sendTransaction(
    addresses.appGateway,
    'triggerAltWrite',
    [addresses.opForwarder, addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(30, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway);
}

// Read tests
async function runReadTests(addresses: ContractAddresses): Promise<void> {
  console.log(`${colors.CYAN}Running all read tests functions...${colors.NC}`);

  const abi = parseAbi([
    'function triggerParallelRead(address forwarder) external',
    'function triggerAltRead(address forwarder1, address forwarder2) external'
  ]);

  if (!addresses.appGateway || !addresses.opForwarder || !addresses.arbForwarder) {
    throw new Error('Required addresses not found');
  }

  // 1. Trigger Parallel Read
  await sendTransaction(
    addresses.appGateway,
    'triggerParallelRead',
    [addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(10, 'ValueRead(address,uint256,uint256)', addresses.appGateway);

  // 2. Trigger Alternating Read
  await sendTransaction(
    addresses.appGateway,
    'triggerAltRead',
    [addresses.opForwarder, addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(20, 'ValueRead(address,uint256,uint256)', addresses.appGateway);
}

// Trigger AppGateway from onchain tests
async function runTriggerAppGatewayOnchainTests(addresses: ContractAddresses): Promise<void> {
  console.log(`${colors.CYAN}Running all trigger the AppGateway from onchain tests functions...${colors.NC}`);

  if (!addresses.appGateway || !addresses.arbOnchain || !addresses.opOnchain) {
    throw new Error('Required addresses not found');
  }

  const valueIncrease = BigInt(5);

  // 1. Increase on AppGateway from Arbitrum Sepolia
  console.log(`${colors.CYAN}Increase on AppGateway from Arbitrum Sepolia${colors.NC}`);

  const onchainAbi = parseAbi([
    'function increaseOnGateway(uint256) external'
  ]);

  await sendTransaction(
    addresses.arbOnchain,
    'increaseOnGateway',
    [valueIncrease],
    arbChain,
    onchainAbi
  );

  // Wait and verify value on AppGateway
  await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay

  const appGatewayAbi = parseAbi([
    'function valueOnGateway() external view returns (uint256)',
    'function updateOnchain(uint32) external'
  ]);

  const valueOnGateway = await evmxChain.client.readContract({
    address: addresses.appGateway,
    abi: appGatewayAbi,
    functionName: 'valueOnGateway'
  }) as bigint;

  if (valueOnGateway < valueIncrease) {
    throw new Error(`Got ${valueOnGateway} but expected at least ${valueIncrease}`);
  }

  // 2. Update on Optimism Sepolia from AppGateway
  console.log(`${colors.CYAN}Update on Optimism Sepolia from AppGateway${colors.NC}`);

  await sendTransaction(
    addresses.appGateway,
    'updateOnchain',
    [OP_SEP_CHAIN_ID],
    evmxChain,
    appGatewayAbi
  );

  // Wait and verify value on Optimism
  await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay

  const onchainReadAbi = parseAbi([
    'function value() external view returns (uint256)',
    'function propagateToAnother(uint32) external'
  ]);

  const valueOnOp = await opChain.client.readContract({
    address: addresses.opOnchain,
    abi: onchainReadAbi,
    functionName: 'value'
  }) as bigint;

  if (valueOnOp !== valueOnGateway) {
    throw new Error(`Got ${valueOnOp} but expected ${valueOnGateway}`);
  }

  // 3. Propagate update from Optimism Sepolia to Arbitrum Sepolia
  console.log(`${colors.CYAN}Propagate update to Optimism Sepolia to Arbitrum Sepolia from AppGateway${colors.NC}`);

  await sendTransaction(
    addresses.opOnchain,
    'propagateToAnother',
    [ARB_SEP_CHAIN_ID],
    opChain,
    onchainReadAbi
  );

  // Wait and verify value on Arbitrum
  await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay

  const valueOnArb = await arbChain.client.readContract({
    address: addresses.arbOnchain,
    abi: onchainReadAbi,
    functionName: 'value'
  }) as bigint;

  if (valueOnArb !== valueOnOp) {
    throw new Error(`Got ${valueOnArb} but expected ${valueOnOp}`);
  }

  console.log(`${colors.GREEN}All trigger tests completed successfully!${colors.NC}`);
}

// Upload to EVMx tests
async function runUploadTests(
  fileName: string,
  appGateway: Address
): Promise<void> {
  console.log(`${colors.CYAN}Deploying ${fileName} contract${colors.NC}`);

  // Deploy counter contract on Arbitrum Sepolia
  const counterAddress = await deployContract(fileName, [], arbChain);

  // Increment counter on Arbitrum Sepolia
  console.log(`${colors.CYAN}Increment counter on Arbitrum Sepolia${colors.NC}`);
  const counterAbi = parseAbi([
    'function increment() external'
  ]);

  await sendTransaction(
    counterAddress,
    'increment',
    [],
    arbChain,
    counterAbi
  );

  // Upload counter to EVMx
  console.log(`${colors.CYAN}Upload counter to EVMx${colors.NC}`);
  const uploadAbi = parseAbi([
    'function uploadToEVMx(address,uint32) external',
    'function read() external'
  ]);

  await sendTransaction(
    appGateway,
    'uploadToEVMx',
    [counterAddress, ARB_SEP_CHAIN_ID],
    evmxChain,
    uploadAbi
  );

  // Test read from Counter forwarder address
  console.log(`${colors.CYAN}Test read from Counter forwarder address${colors.NC}`);
  await sendTransaction(
    appGateway,
    'read',
    [],
    evmxChain,
    uploadAbi
  );

  await awaitEvents(1, 'ReadOnchain(address,uint256)', appGateway);
}

// Insufficient fees tests
async function runInsufficientFeesTests(
  contractName: string,
  chainId: number,
  appGateway: Address
): Promise<Address> {
  console.log(`${colors.CYAN}Testing fees for '${contractName}' on chain ${chainId}${colors.NC}`);

  // Get contract ID
  const contractAbi = parseAbi([
    `function ${contractName}() external view returns (bytes32)`,
    'function forwarderAddresses(bytes32, uint32) external view returns (address)',
    'function increaseFees(uint40, uint256) external'
  ]);

  const contractId = await evmxChain.client.readContract({
    address: appGateway,
    abi: contractAbi,
    functionName: contractName
  }) as Hash;

  // Wait for forwarder address (should fail initially)
  let attempts = 0;
  const maxAttempts = 15;
  let forwarder: Address = '0x0000000000000000000000000000000000000000';

  while (attempts < maxAttempts) {
    try {
      forwarder = await evmxChain.client.readContract({
        address: appGateway,
        abi: contractAbi,
        functionName: 'forwarderAddresses',
        args: [contractId, chainId]
      }) as Address;

      if (forwarder !== '0x0000000000000000000000000000000000000000') {
        console.log(forwarder);
        return forwarder;
      }
    } catch (error) {
      // Continue waiting
    }

    const percent = Math.floor((attempts * 100) / maxAttempts);
    process.stdout.write(`\r${colors.YELLOW}Waiting for forwarder:${colors.NC} ${percent}%`);

    await new Promise(resolve => setTimeout(resolve, 1000));
    attempts++;
  }

  process.stdout.write('\n');
  console.log(`No valid forwarder after ${maxAttempts} seconds`);

  // Get the last transaction hash from the deployment and parse request count
  // This would need to be passed from the deployment function
  // For now, we'll use a placeholder
  const requestCount = BigInt(1); // This should be parsed from the actual deployment transaction

  // Set fees
  await sendTransaction(
    appGateway,
    'increaseFees',
    [requestCount, DEPLOY_FEES_AMOUNT],
    evmxChain,
    contractAbi
  );

  // Verify forwarder after fees
  attempts = 0;
  while (attempts < maxAttempts) {
    try {
      forwarder = await evmxChain.client.readContract({
        address: appGateway,
        abi: contractAbi,
        functionName: 'forwarderAddresses',
        args: [contractId, chainId]
      }) as Address;

      if (forwarder !== '0x0000000000000000000000000000000000000000') {
        console.log(`${colors.GREEN}Chain ${chainId}${colors.NC}`);
        console.log(`Forwarder: ${forwarder}`);
        return forwarder;
      }
    } catch (error) {
      // Continue waiting
    }

    const percent = Math.floor((attempts * 100) / maxAttempts);
    process.stdout.write(`\r${colors.YELLOW}Waiting for forwarder:${colors.NC} ${percent}%`);

    await new Promise(resolve => setTimeout(resolve, 5000));
    attempts++;
  }

  process.stdout.write('\n');
  throw new Error(`No valid forwarder after ${maxAttempts * 5} seconds`);
}


// Help function
function showHelp(): void {
  console.log('Usage: tsx evmx-test-script.ts [OPTIONS]');
  console.log('Options:');
  console.log('  -w    Run write tests');
  console.log('  -r    Run read tests');
  console.log('  -t    Run trigger tests');
  console.log('  -u    Run upload tests');
  console.log('  -s    Run scheduler tests');
  console.log('  -a    Run all tests');
  console.log('  -?    Show this help message');
  console.log('If no options are provided, this help message is displayed.');
}

// Main function
async function main(): Promise<void> {
  try {
    await buildContracts();
    setupClients();

    // Parse command line arguments
    const args = process.argv.slice(2);
    if (args.length === 0 || args.includes('-?')) {
      showHelp();
      return;
    }

    const flags = {
      write: args.includes('-w') || args.includes('-a'),
      read: args.includes('-r') || args.includes('-a'),
      trigger: args.includes('-t') || args.includes('-a'),
      upload: args.includes('-u') || args.includes('-a'),
      scheduler: args.includes('-s') || args.includes('-a'),
      insufficient: args.includes('-i') || args.includes('-a'),
      all: args.includes('-a')
    };

    let addresses: ContractAddresses = {};

    // Write Tests
    if (flags.write) {
      console.log(`${colors.GREEN}=== Running Write Tests ===${colors.NC}`);
      addresses.appGateway = await deployAppGateway('WriteAppGateway');
      await depositFunds(addresses.appGateway);
      await deployOnchain(ARB_SEP_CHAIN_ID, addresses.appGateway);
      await deployOnchain(OP_SEP_CHAIN_ID, addresses.appGateway);

      const arbAddresses = await fetchForwarderAndOnchainAddress('multichain', ARB_SEP_CHAIN_ID, addresses.appGateway);
      addresses.arbForwarder = arbAddresses.forwarder;
      addresses.arbOnchain = arbAddresses.onchain;

      const opAddresses = await fetchForwarderAndOnchainAddress('multichain', OP_SEP_CHAIN_ID, addresses.appGateway);
      addresses.opForwarder = opAddresses.forwarder;
      addresses.opOnchain = opAddresses.onchain;

      await runWriteTests(addresses);
      await withdrawFunds(addresses.appGateway);
    }

    // Read Tests
    if (flags.read) {
      console.log(`${colors.GREEN}=== Running Read Tests ===${colors.NC}`);
      addresses.appGateway = await deployAppGateway('ReadAppGateway');
      await depositFunds(addresses.appGateway);
      await deployOnchain(ARB_SEP_CHAIN_ID, addresses.appGateway);
      await deployOnchain(OP_SEP_CHAIN_ID, addresses.appGateway);

      const arbAddresses = await fetchForwarderAndOnchainAddress('multichain', ARB_SEP_CHAIN_ID, addresses.appGateway);
      addresses.arbForwarder = arbAddresses.forwarder;
      addresses.arbOnchain = arbAddresses.onchain;

      const opAddresses = await fetchForwarderAndOnchainAddress('multichain', OP_SEP_CHAIN_ID, addresses.appGateway);
      addresses.opForwarder = opAddresses.forwarder;
      addresses.opOnchain = opAddresses.onchain;

      await runReadTests(addresses);
      await withdrawFunds(addresses.appGateway);
    }

    // Trigger from onchain Tests
    if (flags.trigger) {
      console.log(`${colors.GREEN}=== Running Trigger from onchain Tests ===${colors.NC}`);
      addresses.appGateway = await deployAppGateway('OnchainTriggerAppGateway');
      await depositFunds(addresses.appGateway);
      await deployOnchain(ARB_SEP_CHAIN_ID, addresses.appGateway);
      await deployOnchain(OP_SEP_CHAIN_ID, addresses.appGateway);

      const arbAddresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', ARB_SEP_CHAIN_ID, addresses.appGateway);
      addresses.arbForwarder = arbAddresses.forwarder;
      addresses.arbOnchain = arbAddresses.onchain;

      const opAddresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', OP_SEP_CHAIN_ID, addresses.appGateway);
      addresses.opForwarder = opAddresses.forwarder;
      addresses.opOnchain = opAddresses.onchain;

      await runTriggerAppGatewayOnchainTests(addresses);
      await withdrawFunds(addresses.appGateway);
    }

    // Upload to EVMx Tests
    if (flags.upload) {
      console.log(`${colors.GREEN}=== Running Upload to EVMx Tests ===${colors.NC}`);
      addresses.appGateway = await deployAppGateway('UploadAppGateway');
      await depositFunds(addresses.appGateway);
      await runUploadTests("Counter", addresses.appGateway);
      await withdrawFunds(addresses.appGateway);
    }

    // Insufficient Fees Tests
    if (flags.insufficient) {
      console.log(`${colors.GREEN}=== Running Insufficient fees Tests ===${colors.NC}`);
      addresses.appGateway = await deployAppGateway('ReadAppGateway', 0n);
      await depositFunds(addresses.appGateway);
      await deployOnchain(OP_SEP_CHAIN_ID, addresses.appGateway);
      await runInsufficientFeesTests('multichain', OP_SEP_CHAIN_ID, addresses.appGateway);
      await withdrawFunds(addresses.appGateway);
    }

    console.log(`${colors.GREEN}All selected tests completed successfully!${colors.NC}`);

  } catch (error) {
    console.error(`${colors.RED}Error:${colors.NC}`, error);
    process.exit(1);
  }
}

// Export the setup for external use
export {
  setupClients,
  deployContract,
  sendTransaction,
  buildContracts,
  colors,
  evmxChain,
  arbChain,
  opChain
};

// Run main if this is the main module
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error('Unhandled error in main:', error);
    process.exit(1);
  });
}
