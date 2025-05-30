import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployContract, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { awaitEvents } from '../utils/helpers.js';
import { ChainConfig } from '../utils/types.js';
import { COLORS, CHAIN_IDS } from '../utils/constants.js';

// Upload to EVMx tests
export async function runUploadTests(
  fileName: string,
  appGateway: Address,
  evmxChain: ChainConfig,
  arbChain: ChainConfig
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

  await awaitEvents(1, 'ReadOnchain(address,uint256)', appGateway, evmxChain);
}

export async function executeUploadTests(
  evmxChain: ChainConfig,
  arbChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Upload to EVMx Tests ===${COLORS.NC}`);

  const appGateway = await deployAppGateway('UploadAppGateway', evmxChain);

  await depositFunds(appGateway, arbChain, evmxChain);
  await runUploadTests("Counter", appGateway, evmxChain, arbChain);
  await withdrawFunds(appGateway, arbChain, evmxChain);
}
