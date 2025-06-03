import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { awaitEvents, fetchForwarderAndOnchainAddress } from '../utils/helpers.js';
import { ContractAddresses, ChainConfig } from '../utils/types.js';
import { COLORS, CHAIN_IDS } from '../utils/constants.js';

// Read tests
export async function runReadTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Running all read tests functions...${COLORS.NC}`);

  const abi = parseAbi([
    'function numberOfRequests() external view returns (uint256)',
    'function triggerParallelRead(address forwarder) external',
    'function triggerAltRead(address forwarder1, address forwarder2) external'
  ]);

  if (!addresses.appGateway || !addresses.opForwarder || !addresses.arbForwarder) {
    throw new Error('Required addresses not found');
  }

  const numberOfRequests = await evmxChain.client.readContract({
    address: addresses.appGateway,
    abi,
    functionName: 'numberOfRequests',
  });

  // 1. Trigger Parallel Read
  await sendTransaction(
    addresses.appGateway,
    'triggerParallelRead',
    [addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(numberOfRequests, 'ValueRead(address,uint256,uint256)', addresses.appGateway, evmxChain);

  // 2. Trigger Alternating Read
  await sendTransaction(
    addresses.appGateway,
    'triggerAltRead',
    [addresses.opForwarder, addresses.arbForwarder],
    evmxChain,
    abi
  );
  await awaitEvents(numberOfRequests * 2n, 'ValueRead(address,uint256,uint256)', addresses.appGateway, evmxChain);
}

export async function executeReadTests(
  evmxChain: ChainConfig,
  arbChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Read Tests ===${COLORS.NC}`);

  const addresses: ContractAddresses = {
    appGateway: await deployAppGateway('ReadAppGateway', evmxChain)
  };

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
