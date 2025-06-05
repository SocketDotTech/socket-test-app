import { parseAbi, type Address, type Hash } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { selectRandomChains } from '../utils/helpers.js';
import { ChainConfig } from '../utils/types.js';
import { COLORS, AMOUNTS } from '../utils/constants.js';

// Insufficient fees tests
export async function runInsufficientFeesTests(
  contractName: string,
  chainId: number,
  appGateway: Address,
  evmxChain: ChainConfig
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

export async function executeInsufficientFeesTests(
  chains: Record<string, ChainConfig>,
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Insufficient fees Tests ===${COLORS.NC}`);

  const appGateway = await deployAppGateway('ReadAppGateway', chains.evmxChain, 0n);

  await depositFunds(appGateway, chains.arbMainnetChain, chains.evmxChain);

  // Select one random chain for insufficient fees tests
  const randomChains = selectRandomChains(chains, 1);
  const selectedChain = randomChains[0];

  await deployOnchain(selectedChain.chainId, appGateway, chains.evmxChain);
  await runInsufficientFeesTests('multichain', selectedChain.chainId, appGateway, chains.evmxChain);
  await withdrawFunds(appGateway, chains.arbMainnetChain, chains.evmxChain);
}
