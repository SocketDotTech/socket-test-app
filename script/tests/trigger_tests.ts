import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { fetchForwarderAndOnchainAddress, selectRandomChains } from '../utils/helpers.js';
import { ContractAddresses, ChainConfig } from '../utils/types.js';
import { COLORS } from '../utils/constants.js';

// Trigger AppGateway from onchain tests
export async function runTriggerAppGatewayOnchainTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig,
  selectedChains: ChainConfig[]
): Promise<void> {
  console.log(`${COLORS.CYAN}Running all trigger the AppGateway from onchain tests functions...${COLORS.NC}`);

  if (!addresses.appGateway || !addresses.chain1Onchain || !addresses.chain2Onchain) {
    throw new Error('Required addresses not found');
  }

  const valueIncrease = BigInt(5);
  const chain1 = selectedChains[0];
  const chain2 = selectedChains[1];

  // 1. Increase on AppGateway from first selected chain
  console.log(`${COLORS.CYAN}Increase on AppGateway from ${chain1.chainId}${COLORS.NC}`);

  const onchainAbi = parseAbi([
    'function increaseOnGateway(uint256) external'
  ]);

  await sendTransaction(
    addresses.chain1Onchain,
    'increaseOnGateway',
    [valueIncrease],
    chain1,
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

  // 2. Update on second selected chain from AppGateway
  console.log(`${COLORS.CYAN}Update on ${chain2.chainId} from AppGateway${COLORS.NC}`);

  await sendTransaction(
    addresses.appGateway,
    'updateOnchain',
    [chain2.chainId],
    evmxChain,
    appGatewayAbi
  );

  // Wait and verify value on second chain
  await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay

  const onchainReadAbi = parseAbi([
    'function value() external view returns (uint256)',
    'function propagateToAnother(uint32) external'
  ]);

  const valueOnChain2 = await chain2.client.readContract({
    address: addresses.chain2Onchain,
    abi: onchainReadAbi,
    functionName: 'value'
  }) as bigint;

  if (valueOnChain2 !== valueOnGateway) {
    throw new Error(`Got ${valueOnChain2} but expected ${valueOnGateway}`);
  }

  // 3. Propagate update from second chain to first chain
  console.log(`${COLORS.CYAN}Propagate update from ${chain2.chainId} to ${chain1.chainId} via AppGateway${COLORS.NC}`);

  await sendTransaction(
    addresses.chain2Onchain,
    'propagateToAnother',
    [chain1.chainId],
    chain2,
    onchainReadAbi
  );

  // Wait and verify value on first chain
  await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay

  const valueOnChain1 = await chain1.client.readContract({
    address: addresses.chain1Onchain,
    abi: onchainReadAbi,
    functionName: 'value'
  }) as bigint;

  if (valueOnChain1 !== valueOnChain2) {
    throw new Error(`Got ${valueOnChain1} but expected ${valueOnChain2}`);
  }

  console.log(`${COLORS.GREEN}All trigger tests completed successfully!${COLORS.NC}`);
}

export async function executeTriggerTests(
  chains: Record<string, ChainConfig>,
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Trigger from onchain Tests ===${COLORS.NC}`);

  const addresses: ContractAddresses = {
    appGateway: await deployAppGateway('OnchainTriggerAppGateway', chains.evmxChain)
  };

  await depositFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);

  // Selects two random chains out of the available ones
  const randomChains = selectRandomChains(chains, 2);

  await deployOnchain(randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  await deployOnchain(randomChains[1].chainId, addresses.appGateway, chains.evmxChain);

  const chain1Addresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.chain1Forwarder = chain1Addresses.forwarder;
  addresses.chain1Onchain = chain1Addresses.onchain;

  const chain2Addresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', randomChains[1].chainId, addresses.appGateway, chains.evmxChain);
  addresses.chain2Forwarder = chain2Addresses.forwarder;
  addresses.chain2Onchain = chain2Addresses.onchain;

  await runTriggerAppGatewayOnchainTests(addresses, chains.evmxChain, randomChains);
  await withdrawFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);
}
