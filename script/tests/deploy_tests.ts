import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { fetchForwarderAndOnchainAddress, getTxDetails, selectRandomChains } from '../utils/helpers.js';
import { ContractAddresses, ChainConfig } from '../utils/types.js';
import { COLORS, URLS } from '../utils/constants.js';

// Deploy AppGateway from onchain tests
export async function runDeployAppGatewayTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig,
  selectedChains: ChainConfig[]
): Promise<void> {
  console.log(`${COLORS.CYAN}Running all AppGateway onchain deployment tests...${COLORS.NC}`);

  if (!addresses.appGateway) {
    throw new Error('Required addresses not found');
  }

  console.log(`${COLORS.CYAN}Validate all deployments from AppGateway${COLORS.NC}`);

  const appGatewayAbi = parseAbi([
    'function contractValidation(uint32 chainSlug_) external'
  ]);

  const hash = await sendTransaction(
    addresses.appGateway,
    'contractValidation',
    [selectedChains[0].chainId],
    evmxChain,
    appGatewayAbi
  );

  // Waiting for transaction finalized
  console.log(`${COLORS.CYAN}Waiting for transaction finalized${COLORS.NC}`);
  let attempt = 0;
  let status = '';
  const interval = 1000; // 1 seconds
  const maxAttempts = 60; // 60 seconds
  const maxSeconds = interval * maxAttempts / 1000;
  const endpoint = `${URLS.EVMX_API_BASE}/getDetailsByTxHash`;

  while (true) {
    const response = await getTxDetails(endpoint, hash);
    status = response?.response?.[0]?.status;

    if (status === 'COMPLETED') {
      console.log(`Transaction completed as expected.`);
      if (attempt > 0) process.stdout.write('\r\x1b[2K');
      break;
    }

    if (attempt >= maxAttempts) {
      console.log();
      throw new Error(`Could not validate transaction completion after ${maxSeconds} seconds. Current status: ${status}`);
    }

    const elapsed = attempt * interval / 1000;
    process.stdout.write(`\r${COLORS.YELLOW}Waiting for transaction completion:${COLORS.NC} ${elapsed}s / ${maxSeconds}s`);

    await new Promise(resolve => setTimeout(resolve, interval));
    attempt++;
  }

  console.log(`${COLORS.GREEN}All trigger tests completed successfully!${COLORS.NC}`);
}

export async function executeDeployTests(
  chains: Record<string, ChainConfig>,
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Deployment Tests ===${COLORS.NC}`);

  const addresses: ContractAddresses = {
    appGateway: await deployAppGateway('DeploymentAppGateway', chains.evmxChain),
    deployForwarders: [] as Address[],
    deployOnchain: [] as Address[],
  };

  await depositFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);

  // Selects two random chains out of the available ones
  const randomChains = selectRandomChains(chains, 1);

  await deployOnchain(randomChains[0].chainId, addresses.appGateway, chains.evmxChain);

  let chainAddresses = await fetchForwarderAndOnchainAddress('noPlugNoInititialize', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.deployForwarders!.push(chainAddresses.forwarder);
  addresses.deployOnchain!.push(chainAddresses.onchain);

  chainAddresses = await fetchForwarderAndOnchainAddress('noPlugInitialize', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.deployForwarders!.push(chainAddresses.forwarder);
  addresses.deployOnchain!.push(chainAddresses.onchain);

  chainAddresses = await fetchForwarderAndOnchainAddress('plugNoInitialize', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.deployForwarders!.push(chainAddresses.forwarder);
  addresses.deployOnchain!.push(chainAddresses.onchain);

  chainAddresses = await fetchForwarderAndOnchainAddress('plugInitialize', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.deployForwarders!.push(chainAddresses.forwarder);
  addresses.deployOnchain!.push(chainAddresses.onchain);

  chainAddresses = await fetchForwarderAndOnchainAddress('plugInitializeTwice', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.deployForwarders!.push(chainAddresses.forwarder);
  addresses.deployOnchain!.push(chainAddresses.onchain);

  chainAddresses = await fetchForwarderAndOnchainAddress('plugNoInitInitialize', randomChains[0].chainId, addresses.appGateway, chains.evmxChain);
  addresses.deployForwarders!.push(chainAddresses.forwarder);
  addresses.deployOnchain!.push(chainAddresses.onchain);

  await runDeployAppGatewayTests(addresses, chains.evmxChain, randomChains);
  await withdrawFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);
}
