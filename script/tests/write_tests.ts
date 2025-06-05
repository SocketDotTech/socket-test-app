import { parseAbi } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { awaitEvents, fetchForwarderAndOnchainAddress, selectRandomChains } from '../utils/helpers.js';
import { ContractAddresses, ChainConfig } from '../utils/types.js';
import { COLORS } from '../utils/constants.js';

// Write tests
export async function runWriteTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Running all write tests functions...${COLORS.NC}`);

  const abi = parseAbi([
    'function numberOfRequests() external view returns (uint256)',
    'function triggerSequentialWrite(address forwarder) external',
    'function triggerParallelWrite(address forwarder) external',
    'function triggerAltWrite(address forwarder1, address forwarder2) external'
  ]);

  if (!addresses.appGateway || !addresses.chain2Forwarder || !addresses.chain1Forwarder) {
    throw new Error('Required addresses not found');
  }

  const numberOfRequests = await evmxChain.client.readContract({
    address: addresses.appGateway,
    abi,
    functionName: 'numberOfRequests',
  });


  // 1. Trigger Sequential Write
  await sendTransaction(
    addresses.appGateway,
    'triggerSequentialWrite',
    [addresses.chain2Forwarder],
    evmxChain,
    abi
  );
  await awaitEvents(numberOfRequests, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway, evmxChain);

  // 2. Trigger Parallel Write
  await sendTransaction(
    addresses.appGateway,
    'triggerParallelWrite',
    [addresses.chain1Forwarder],
    evmxChain,
    abi
  );
  await awaitEvents(numberOfRequests * 2n, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway, evmxChain);

  // 3. Trigger Alternating Write
  await sendTransaction(
    addresses.appGateway,
    'triggerAltWrite',
    [addresses.chain2Forwarder, addresses.chain1Forwarder],
    evmxChain,
    abi
  );
  await awaitEvents(numberOfRequests * 3n, 'CounterIncreased(address,uint256,uint256)', addresses.appGateway, evmxChain);
}

export async function executeWriteTests(
  chains: Record<string, ChainConfig>,
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Write Tests ===${COLORS.NC}`);

  const addresses: ContractAddresses = {
    appGateway: await deployAppGateway('WriteAppGateway', chains.evmxChain)
  };

  await depositFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);

  // Selects two random chains out of the available ones
  const randomChains = selectRandomChains(chains, 2);

  await deployOnchain(randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  await deployOnchain(randomChains[1].chainId, addresses.appGateway, chains.evmxChain);

  const chain1Addresses = await fetchForwarderAndOnchainAddress('multichain', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.chain1Forwarder = chain1Addresses.forwarder;
  addresses.chain1Onchain = chain1Addresses.onchain;

  const chain2Addresses = await fetchForwarderAndOnchainAddress('multichain', randomChains[1].chainId, addresses.appGateway, chains.evmxChain);
  addresses.chain2Forwarder = chain2Addresses.forwarder;
  addresses.chain2Onchain = chain2Addresses.onchain;

  await runWriteTests(addresses, chains.evmxChain);
  await withdrawFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);
}
