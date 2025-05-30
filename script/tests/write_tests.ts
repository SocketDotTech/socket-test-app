import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { awaitEvents, fetchForwarderAndOnchainAddress } from '../utils/helpers.js';
import { ContractAddresses, ChainConfig } from '../utils/types.js';
import { COLORS, CHAIN_IDS } from '../utils/constants.js';

// Write tests
export async function runWriteTests(
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

export async function executeWriteTests(
  evmxChain: ChainConfig,
  arbChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Write Tests ===${COLORS.NC}`);

  const addresses: ContractAddresses = {
    appGateway: await deployAppGateway('WriteAppGateway', evmxChain)
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

  await runWriteTests(addresses, evmxChain);
  await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
}
