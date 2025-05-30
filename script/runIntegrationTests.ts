// tests.ts - Main test orchestrator
import { parseAbi, type Address, type Hash } from 'viem';
import { setupClients } from './utils/client-setup.js';
import { buildContracts, deployContract, deployAppGateway, deployOnchain, sendTransaction } from './utils/deployer.js';
import { depositFunds, withdrawFunds } from './utils/fees-manager.js';
import { awaitEvents, fetchForwarderAndOnchainAddress, getTxDetails } from './utils/helpers.js';
import { ContractAddresses, TestFlags, ChainConfig } from './utils/types.js';
import { COLORS, CHAIN_IDS, URLS, AMOUNTS } from './utils/constants.js';

// Global chain configurations
let evmxChain: ChainConfig;
let arbChain: ChainConfig;
let opChain: ChainConfig;

// Initialize chains
function initializeChains(): void {
  const chains = setupClients();
  evmxChain = chains.evmxChain;
  arbChain = chains.arbChain;
  opChain = chains.opChain;
}

// Write tests
async function runWriteTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Running all write tests functions...${COLORS.NC}`);

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
  await awaitEvents(10, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway, evmxChain);

  // 2. Trigger Parallel Write
  await sendTransaction(
    addresses.appGateway,
    'triggerParallelWrite',
    [addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(20, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway, evmxChain);

  // 3. Trigger Alternating Write
  await sendTransaction(
    addresses.appGateway,
    'triggerAltWrite',
    [addresses.opForwarder, addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(30, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway, evmxChain);
}

// Read tests
export async function runReadTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Running all read tests functions...${COLORS.NC}`);

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
  await awaitEvents(10, 'ValueRead(address,uint256,uint256)', addresses.appGateway, evmxChain);

  // 2. Trigger Alternating Read
  await sendTransaction(
    addresses.appGateway,
    'triggerAltRead',
    [addresses.opForwarder, addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(20, 'ValueRead(address,uint256,uint256)', addresses.appGateway, evmxChain);
}

// Trigger AppGateway from onchain tests
async function runTriggerAppGatewayOnchainTests(addresses: ContractAddresses): Promise<void> {
  console.log(`${COLORS.CYAN}Running all trigger the AppGateway from onchain tests functions...${COLORS.NC}`);

  if (!addresses.appGateway || !addresses.arbOnchain || !addresses.opOnchain) {
    throw new Error('Required addresses not found');
  }

  const valueIncrease = BigInt(5);

  // 1. Increase on AppGateway from Arbitrum Sepolia
  console.log(`${COLORS.CYAN}Increase on AppGateway from Arbitrum Sepolia${COLORS.NC}`);

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
  console.log(`${COLORS.CYAN}Update on Optimism Sepolia from AppGateway${COLORS.NC}`);

  await sendTransaction(
    addresses.appGateway,
    'updateOnchain',
    [CHAIN_IDS.OP_SEP],
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
  console.log(`${COLORS.CYAN}Propagate update to Optimism Sepolia to Arbitrum Sepolia from AppGateway${COLORS.NC}`);

  await sendTransaction(
    addresses.opOnchain,
    'propagateToAnother',
    [CHAIN_IDS.ARB_SEP],
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

  console.log(`${COLORS.GREEN}All trigger tests completed successfully!${COLORS.NC}`);
}

// Upload to EVMx tests
async function runUploadTests(
  fileName: string,
  appGateway: Address
): Promise<void> {
  // Deploy counter contract on Arbitrum Sepolia
  const counterAddress = await deployContract(fileName, [], arbChain);

  // Increment counter on Arbitrum Sepolia
  console.log(`${COLORS.CYAN}Increment counter on Arbitrum Sepolia${COLORS.NC}`);
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
  console.log(`${COLORS.CYAN}Upload counter to EVMx${COLORS.NC}`);
  const uploadAbi = parseAbi([
    'function uploadToEVMx(address,uint32) external',
    'function read() external'
  ]);

  await sendTransaction(
    appGateway,
    'uploadToEVMx',
    [counterAddress, CHAIN_IDS.ARB_SEP],
    evmxChain,
    uploadAbi
  );

  // Test read from Counter forwarder address
  console.log(`${COLORS.CYAN}Test read from Counter forwarder address${COLORS.NC}`);
  await sendTransaction(
    appGateway,
    'read',
    [],
    evmxChain,
    uploadAbi
  );

  const { awaitEvents } = await import('./utils/helpers.js');
  await awaitEvents(1, 'ReadOnchain(address,uint256)', appGateway, evmxChain);
}

// Scheduler tests
async function runSchedulerTests(appGateway: Address): Promise<void> {
  console.log(`${COLORS.CYAN}Reading timeouts from the contract:${COLORS.NC}`);
  const abi = parseAbi([
    'function timeoutsInSeconds(uint256) external view returns (uint256)',
    'function triggerTimeouts() external'
  ]);

  let maxTimeout = 0;
  let numberOfTimeouts = 0;

  while (true) {
    try {
      const timeout = await evmxChain.client.readContract({
        address: appGateway,
        abi,
        functionName: 'timeoutsInSeconds',
        args: [numberOfTimeouts]
      }) as number;

      if (timeout === 0) break;

      console.log(`Timeout ${numberOfTimeouts}: ${timeout} seconds`);
      numberOfTimeouts++;

      if (timeout > maxTimeout) {
        maxTimeout = timeout;
      }
    } catch (error) {
      break;
    }
  }

  console.log(`${COLORS.CYAN}Triggering timeouts...${COLORS.NC}`);
  await sendTransaction(
    appGateway,
    'triggerTimeouts',
    [],
    evmxChain,
    abi
  );

  console.log(`${COLORS.CYAN}Fetching TimeoutResolved events...${COLORS.NC}`);

  const { awaitEvents } = await import('./utils/helpers.js');
  await awaitEvents(numberOfTimeouts, 'TimeoutResolved(uint256,uint256,uint256)', appGateway, evmxChain, Number(maxTimeout));

  const logs = await evmxChain.client.getLogs({
    address: appGateway,
    event: parseAbi(['event TimeoutResolved(uint256,uint256,uint256)'])[0],
    fromBlock: 'earliest',
    toBlock: 'latest'
  });

  // Decode and display event data
  logs.forEach((log: any) => {
    if (log.data) {
      const dataHex = log.data.slice(2); // Remove 0x
      const index = BigInt('0x' + dataHex.slice(0, 64));
      const creationTimestamp = BigInt('0x' + dataHex.slice(64, 128));
      const executionTimestamp = BigInt('0x' + dataHex.slice(128, 192));

      console.log(`${COLORS.GREEN}Timeout Resolved:${COLORS.NC}`);
      console.log(`  Index: ${index}`);
      console.log(`  Created at: ${creationTimestamp}`);
      console.log(`  Executed at: ${executionTimestamp}`);
    }
  });
}

// Insufficient fees tests
async function runInsufficientFeesTests(
  contractName: string,
  chainId: number,
  appGateway: Address
): Promise<Address> {
  console.log(`${COLORS.CYAN}Testing fees for '${contractName}' on chain ${chainId}${COLORS.NC}`);

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
    process.stdout.write(`\r${COLORS.YELLOW}Waiting for forwarder:${COLORS.NC} ${percent}%`);

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
    [requestCount, AMOUNTS.DEPLOY_FEES],
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
        console.log(`${COLORS.GREEN}Chain ${chainId}${COLORS.NC}`);
        console.log(`Forwarder: ${forwarder}`);
        return forwarder;
      }
    } catch (error) {
      // Continue waiting
    }

    const percent = Math.floor((attempts * 100) / maxAttempts);
    process.stdout.write(`\r${COLORS.YELLOW}Waiting for forwarder:${COLORS.NC} ${percent}%`);

    await new Promise(resolve => setTimeout(resolve, 5000));
    attempts++;
  }

  process.stdout.write('\n');
  throw new Error(`No valid forwarder after ${maxAttempts * 5} seconds`);
}

// Revert tests
async function runRevertTests(addresses: ContractAddresses): Promise<void> {
  const interval = 1000; // 1 seconds
  const maxAttempts = 60; // 60 seconds
  const maxSeconds = interval * maxAttempts / 1000;
  const endpoint = `${URLS.EVMX_API_BASE}/getDetailsByTxHash`;

  console.log(`${COLORS.CYAN}Testing onchain revert${COLORS.NC}`);

  const abi = parseAbi([
    'function testOnChainRevert(uint32) external',
    'function testCallbackRevertWrongInputArgs(uint32) external'
  ]);

  // Send on-chain revert transaction
  const hash1 = await sendTransaction(
    addresses.appGateway!,
    'testOnChainRevert',
    [CHAIN_IDS.OP_SEP],
    evmxChain,
    abi
  );

  console.log(`${COLORS.CYAN}Waiting for transaction finalization${COLORS.NC}`);
  let attempt = 0;
  let status = '';

  while (true) {
    const response = await getTxDetails(endpoint, hash1);
    status = response?.response?.[0]?.writePayloads?.[0]?.finalizeDetails?.finalizeStatus;

    if (status === 'FINALIZED') {
      if (attempt > 0) process.stdout.write('\r\x1b[2K');
      break;
    }

    if (attempt >= maxAttempts) {
      console.log();
      throw new Error(`Transaction not finalized after ${maxSeconds} seconds. Current status: ${status}`);
    }

    const elapsed = attempt * interval / 1000;
    process.stdout.write(`\r${COLORS.YELLOW}Waiting for finalization:${COLORS.NC} ${elapsed}s / ${maxSeconds}s`);

    await new Promise(resolve => setTimeout(resolve, interval));
    attempt++;
  }

  const execStatus = (await getTxDetails(endpoint, hash1))?.response?.[0]?.writePayloads?.[0]?.executeDetails?.executeStatus;

  if (execStatus === 'EXECUTION_FAILED') {
    console.log(`Execution status is EXECUTION_FAILED as expected`);
  } else {
    throw new Error(`Execution status is not EXECUTION_FAILED, it is: ${execStatus}`);
  }

  // Send callback revert transaction
  console.log(`${COLORS.CYAN}Testing callback revert${COLORS.NC}`);

  const hash2 = await sendTransaction(
    addresses.appGateway!,
    'testCallbackRevertWrongInputArgs',
    [CHAIN_IDS.OP_SEP],
    evmxChain,
    abi
  );

  console.log(`${COLORS.CYAN}Waiting for promise failed resolve${COLORS.NC}`);
  attempt = 0;

  while (true) {
    const response = await getTxDetails(endpoint, hash2);
    status = response?.response?.[0]?.readPayloads?.[0]?.callBackDetails?.callbackStatus;

    if (status === 'PROMISE_RESOLVE_FAILED') {
      if (attempt > 0) console.log();
      break;
    }

    if (attempt >= maxAttempts) {
      console.log();
      throw new Error(`Promise did not fail to resolve after ${maxSeconds} seconds. Current status: ${status}`);
    }

    const elapsed = attempt * interval / 1000;
    process.stdout.write(`\r${COLORS.YELLOW}Waiting for finalization:${COLORS.NC} ${elapsed}s / ${maxSeconds}s`);

    await new Promise(resolve => setTimeout(resolve, interval));
    attempt++;
  }

  console.log(`Callback revert test completed successfully`);
}

// Help function
function showHelp(): void {
  console.log('Usage: npx tsx tests.ts [OPTIONS]');
  console.log('Options:');
  console.log('  -w    Run write tests');
  console.log('  -r    Run read tests');
  console.log('  -t    Run trigger tests');
  console.log('  -u    Run upload tests');
  console.log('  -s    Run scheduler tests');
  console.log('  -i    Run insufficient fees tests');
  console.log('  -v    Run revert tests');
  console.log('  -a    Run all tests');
  console.log('  -?    Show this help message');
  console.log('If no options are provided, this help message is displayed.');
}

// Parse command line flags
function parseFlags(args: string[]): TestFlags {
  return {
    write: args.includes('-w') || args.includes('-a'),
    read: args.includes('-r') || args.includes('-a'),
    trigger: args.includes('-t') || args.includes('-a'),
    upload: args.includes('-u') || args.includes('-a'),
    scheduler: args.includes('-s') || args.includes('-a'),
    insufficient: args.includes('-i') || args.includes('-a'),
    revert: args.includes('-v') || args.includes('-a'),
    all: args.includes('-a')
  };
}

// Main function
async function main(): Promise<void> {
  try {
    await buildContracts();
    initializeChains();

    // Parse command line arguments
    const args = process.argv.slice(2);
    if (args.length === 0 || args.includes('-?')) {
      showHelp();
      return;
    }

    const flags = parseFlags(args);
    let addresses: ContractAddresses = { appGateway: '0x0000000000000000000000000000000000000000' as Address };

    // Write Tests
    if (flags.write) {
      console.log(`${COLORS.GREEN}=== Running Write Tests ===${COLORS.NC}`);
      addresses.appGateway = await deployAppGateway('WriteAppGateway', evmxChain);
      await depositFunds(addresses.appGateway, arbChain, evmxChain);
      await deployOnchain(CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
      await deployOnchain(CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);

      const arbAddresses = await fetchForwarderAndOnchainAddress('multichain', CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
      addresses.arbForwarder = arbAddresses.forwarder;
      addresses.arbOnchain = arbAddresses.onchain;

      const opAddresses = await fetchForwarderAndOnchainAddress('multichain', CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);
      addresses.opForwarder = opAddresses.forwarder;
      addresses.opOnchain = opAddresses.onchain;

      await runWriteTests(addresses, evmxChain);
      await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
    }

    // Read Tests
    if (flags.read) {
      console.log(`${COLORS.GREEN}=== Running Read Tests ===${COLORS.NC}`);
      addresses.appGateway = await deployAppGateway('ReadAppGateway', evmxChain);
      await depositFunds(addresses.appGateway, arbChain, evmxChain);
      await deployOnchain(CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
      await deployOnchain(CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);

      const arbAddresses = await fetchForwarderAndOnchainAddress('multichain', CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
      addresses.arbForwarder = arbAddresses.forwarder;
      addresses.arbOnchain = arbAddresses.onchain;

      const opAddresses = await fetchForwarderAndOnchainAddress('multichain', CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);
      addresses.opForwarder = opAddresses.forwarder;
      addresses.opOnchain = opAddresses.onchain;

      await runReadTests(addresses, evmxChain);
      await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
    }

    // Trigger from onchain Tests
    if (flags.trigger) {
      console.log(`${COLORS.GREEN}=== Running Trigger from onchain Tests ===${COLORS.NC}`);
      addresses.appGateway = await deployAppGateway('OnchainTriggerAppGateway', evmxChain);
      await depositFunds(addresses.appGateway, arbChain, evmxChain);
      await deployOnchain(CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
      await deployOnchain(CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);

      const arbAddresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
      addresses.arbForwarder = arbAddresses.forwarder;
      addresses.arbOnchain = arbAddresses.onchain;

      const opAddresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);
      addresses.opForwarder = opAddresses.forwarder;
      addresses.opOnchain = opAddresses.onchain;

      await runTriggerAppGatewayOnchainTests(addresses);
      await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
    }

    // Upload to EVMx Tests
    if (flags.upload) {
      console.log(`${COLORS.GREEN}=== Running Upload to EVMx Tests ===${COLORS.NC}`);
      addresses.appGateway = await deployAppGateway('UploadAppGateway', evmxChain);
      await depositFunds(addresses.appGateway, arbChain, evmxChain);
      await runUploadTests("Counter", addresses.appGateway);
      await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
    }

    // Schedule EVMx events Tests
    if (flags.scheduler) {
      console.log(`${COLORS.GREEN}=== Running Scheduler Tests ===${COLORS.NC}`);
      addresses.appGateway = await deployAppGateway('ScheduleAppGateway', evmxChain);
      await depositFunds(addresses.appGateway, arbChain, evmxChain);
      await runSchedulerTests(addresses.appGateway);
      await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
    }

    // Insufficient Fees Tests
    if (flags.insufficient) {
      console.log(`${COLORS.GREEN}=== Running Insufficient fees Tests ===${COLORS.NC}`);
      addresses.appGateway = await deployAppGateway('ReadAppGateway', evmxChain, 0n);
      await depositFunds(addresses.appGateway, arbChain, evmxChain);
      await deployOnchain(CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);
      await runInsufficientFeesTests('multichain', CHAIN_IDS.OP_SEP, addresses.appGateway);
      await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
    }

    // Revert Tests
    if (flags.revert) {
      console.log(`${COLORS.GREEN}=== Running Revert Tests ===${COLORS.NC}`);
      addresses.appGateway = await deployAppGateway('RevertAppGateway', evmxChain);
      await depositFunds(addresses.appGateway, arbChain, evmxChain);
      await deployOnchain(CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);

      const opAddresses = await fetchForwarderAndOnchainAddress('counter', CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);
      addresses.opForwarder = opAddresses.forwarder;
      addresses.opOnchain = opAddresses.onchain;

      await runRevertTests(addresses);
      await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
    }

    console.log(`${COLORS.GREEN}All selected tests completed successfully!${COLORS.NC}`);

  } catch (error) {
    console.error(`${COLORS.RED}Error:${COLORS.NC}`, error);
    process.exit(1);
  }
}

// Export the setup for external use
export {
  initializeChains,
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
