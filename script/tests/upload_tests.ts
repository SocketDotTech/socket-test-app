import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployContract, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { awaitEvents, selectRandomChains } from '../utils/helpers.js';
import { ChainConfig } from '../utils/types.js';
import { COLORS } from '../utils/constants.js';

// Upload to EVMx tests
export async function runUploadTests(
  fileName: string,
  appGateway: Address,
  evmxChain: ChainConfig,
  selectedChain: ChainConfig
): Promise<void> {
  // Deploy counter contract on selected chain
  const counterAddress = await deployContract(fileName, [], selectedChain);

  // Increment counter on selected chain
  console.log(`${COLORS.CYAN}Increment counter on ${selectedChain.chainId}${COLORS.NC}`);
  const counterAbi = parseAbi([
    'function increment() external'
  ]);

  await sendTransaction(
    counterAddress,
    'increment',
    [],
    selectedChain,
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
    [counterAddress, selectedChain.chainId],
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

  await awaitEvents(1n, 'ReadOnchain(address,uint256)', appGateway, evmxChain);
}

export async function executeUploadTests(
  chains: Record<string, ChainConfig>,
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Upload to EVMx Tests ===${COLORS.NC}`);

  const appGateway = await deployAppGateway('UploadAppGateway', chains.evmxChain);

  await depositFunds(appGateway, chains.arbMainnetChain, chains.evmxChain);

  // Select one random chain for upload tests
  const randomChains = selectRandomChains(chains, 1);
  const selectedChain = randomChains[0];

  await runUploadTests("Counter", appGateway, chains.evmxChain, selectedChain);
  await withdrawFunds(appGateway, chains.arbMainnetChain, chains.evmxChain);
}
