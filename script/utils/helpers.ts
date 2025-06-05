// utils/helpers.ts
import { parseAbi, type Hash, type Address } from 'viem';
import { ChainConfig } from './types.js';
import { COLORS } from './constants.js';

// Get explorer URL helper
export function getExplorerUrl(hash: Hash, chainConfig: ChainConfig): string {
  return `https://${chainConfig.explorerUrl}/tx/${hash}`;
}

export function getExplorerAddressUrl(address: Address, chainConfig: ChainConfig): string {
  return `https://${chainConfig.explorerUrl}/address/${address}`;
}

// Fetch forwarder and onchain addresses
export async function fetchForwarderAndOnchainAddress(
  contractName: string,
  chainId: number,
  appGateway: Address,
  evmxChain: ChainConfig
): Promise<{ forwarder: Address; onchain: Address }> {
  console.log(`${COLORS.CYAN}Fetching forwarder address for contract '${contractName}' on chain ID ${chainId}${COLORS.NC}`);

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
    process.stdout.write(`\r${COLORS.YELLOW}Waiting for forwarder:${COLORS.NC} ${percent}%`);

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

  console.log(`${COLORS.GREEN}Chain ${chainId}${COLORS.NC}`);
  console.log(`Forwarder: ${forwarder}`);
  console.log(`Onchain:   ${onchain}`);

  await new Promise(resolve => setTimeout(resolve, 1000));
  return { forwarder, onchain };
}

// Await events function
export async function awaitEvents(
  expectedNewEvents: bigint,
  _eventSignature: string,
  appGateway: Address,
  evmxChain: ChainConfig,
  timeout: number = 300
): Promise<void> {
  console.log(`${COLORS.CYAN}Waiting logs for ${expectedNewEvents} new events (up to ${timeout} seconds)...${COLORS.NC}`);

  const interval: number = 2000; // 2 seconds
  let elapsed: number = 0;
  let eventCount = 0n;

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

// Fetch transaction status from the API
export async function getTxDetails(endpoint: string, txHash: string): Promise<any> {
  try {
    const res = await fetch(`${endpoint}?txHash=${txHash}`);
    return await res.json();
  } catch (error) {
    console.error(`Failed to fetch tx status: ${error}`);
    return {};
  }
}

// Randomize chain selection
export function selectRandomChains(
  chains: Record<string, ChainConfig>,
  count: number
): ChainConfig[] {
  const { evmxChain, ...rest } = chains;

  const available = Object.values(rest);
  const selected: ChainConfig[] = [];

  for (let i = 0; i < Math.min(count, available.length); i++) {
    const randomIndex = Math.floor(Math.random() * available.length);
    selected.push(available.splice(randomIndex, 1)[0]);
  }

  return selected;
}
