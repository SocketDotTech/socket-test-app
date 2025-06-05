import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { fetchForwarderAndOnchainAddress, getTxDetails, selectRandomChains } from '../utils/helpers.js';
import { ContractAddresses, ChainConfig } from '../utils/types.js';
import { COLORS, URLS } from '../utils/constants.js';

// Revert tests
export async function runRevertTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig,
  randomChainId: number
): Promise<void> {
  const interval = 1000; // 1 seconds
  const maxAttempts = 60; // 60 seconds
  const maxSeconds = interval * maxAttempts / 1000;
  const endpoint = `${URLS.EVMX_API_BASE}/getDetailsByTxHash`;

  console.log(`${COLORS.CYAN}Testing onchain revert${COLORS.NC}`);

  const abi = parseAbi([
    'function testOnChainRevert(uint32) external',
    'function testCallbackRevertWrongInputArgs(uint32) external'
  ]);

  if (!addresses.appGateway) {
    throw new Error('AppGateway address not found');
  }

  // Send on-chain revert transaction
  const hash1 = await sendTransaction(
    addresses.appGateway,
    'testOnChainRevert',
    [randomChainId],
    evmxChain,
    abi
  );

  console.log(`${COLORS.CYAN}Waiting for transaction proof${COLORS.NC}`);
  let attempt = 0;
  let status = '';

  let execStatus;
  while (true) {
    const response = await getTxDetails(endpoint, hash1);
    status = response?.response?.[0]?.writePayloads?.[0]?.proofUploadDetails?.proofUploadStatus;

    if (status === 'PROOF_UPLOADED') {
      execStatus = response?.response?.[0]?.writePayloads?.[0]?.executeDetails?.executeStatus;
      if (execStatus === 'EXECUTION_FAILED') {
        console.log(`Execution status is EXECUTION_FAILED as expected`);
        if (attempt > 0) process.stdout.write('\r\x1b[2K');
        break;
      }
    }

    if (attempt >= maxAttempts) {
      console.log();
      throw new Error(`Could not validate failed execution after ${maxSeconds} seconds. Current status: ${status}`);
    }

    const elapsed = attempt * interval / 1000;
    process.stdout.write(`\r${COLORS.YELLOW}Waiting for failed execution:${COLORS.NC} ${elapsed}s / ${maxSeconds}s`);

    await new Promise(resolve => setTimeout(resolve, interval));
    attempt++;
  }

  // Send callback revert transaction
  console.log(`${COLORS.CYAN}Testing callback revert${COLORS.NC}`);

  const hash2 = await sendTransaction(
    addresses.appGateway,
    'testCallbackRevertWrongInputArgs',
    [randomChainId],
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

export async function executeRevertTests(
  chains: Record<string, ChainConfig>,
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Revert Tests ===${COLORS.NC}`);

  const addresses: ContractAddresses = {
    appGateway: await deployAppGateway('RevertAppGateway', chains.evmxChain)
  };

  await depositFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);

  // Select one random chain for revert tests
  const randomChains = selectRandomChains(chains, 1);
  const selectedChain = randomChains[0];

  await deployOnchain(selectedChain.chainId, addresses.appGateway, chains.evmxChain);

  const chainAddresses = await fetchForwarderAndOnchainAddress('counter', selectedChain.chainId, addresses.appGateway, chains.evmxChain);
  addresses.chain2Forwarder = chainAddresses.forwarder;
  addresses.chain2Onchain = chainAddresses.onchain;

  await runRevertTests(addresses, chains.evmxChain, selectedChain.chainId);
  await withdrawFunds(addresses.appGateway, chains.arbMainnetChain, chains.evmxChain);
}
