import { parseAbi, type Address } from 'viem';
import { deployAppGateway, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { awaitEvents } from '../utils/helpers.js';
import { ChainConfig } from '../utils/types.js';
import { COLORS } from '../utils/constants.js';

// Scheduler tests
export async function runSchedulerTests(
  appGateway: Address,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Reading timeouts from the contract:${COLORS.NC}`);
  const abi = parseAbi([
    'function timeoutsInSeconds(uint256) external view returns (uint256)',
    'function triggerTimeouts() external'
  ]);

  let maxTimeout = 0;
  let numberOfTimeouts = 0;

  while (true) {
    try {
      const timeout = await evmxChain.client.readContract({
        address: appGateway,
        abi,
        functionName: 'timeoutsInSeconds',
        args: [numberOfTimeouts]
      }) as number;

      if (timeout === 0) break;

      console.log(`Timeout ${numberOfTimeouts}: ${timeout} seconds`);
      numberOfTimeouts++;

      if (timeout > maxTimeout) {
        maxTimeout = timeout;
      }
    } catch (error) {
      break;
    }
  }

  console.log(`${COLORS.CYAN}Triggering timeouts...${COLORS.NC}`);
  await sendTransaction(
    appGateway,
    'triggerTimeouts',
    [],
    evmxChain,
    abi
  );

  console.log(`${COLORS.CYAN}Fetching TimeoutResolved events...${COLORS.NC}`);

  await awaitEvents(numberOfTimeouts, 'TimeoutResolved(uint256,uint256,uint256)', appGateway, evmxChain, Number(maxTimeout));

  const logs = await evmxChain.client.getLogs({
    address: appGateway,
    event: parseAbi(['event TimeoutResolved(uint256,uint256,uint256)'])[0],
    fromBlock: 'earliest',
    toBlock: 'latest'
  });

  // Decode and display event data
  logs.forEach((log: any) => {
    if (log.data) {
      const dataHex = log.data.slice(2); // Remove 0x
      const index = BigInt('0x' + dataHex.slice(0, 64));
      const creationTimestamp = BigInt('0x' + dataHex.slice(64, 128));
      const executionTimestamp = BigInt('0x' + dataHex.slice(128, 192));

      console.log(`${COLORS.GREEN}Timeout Resolved:${COLORS.NC}`);
      console.log(`  Index: ${index}`);
      console.log(`  Created at: ${creationTimestamp}`);
      console.log(`  Executed at: ${executionTimestamp}`);
    }
  });
}

export async function executeSchedulerTests(
  evmxChain: ChainConfig,
  arbChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Scheduler Tests ===${COLORS.NC}`);

  const appGateway = await deployAppGateway('ScheduleAppGateway', evmxChain);

  await depositFunds(appGateway, arbChain, evmxChain);
  await runSchedulerTests(appGateway, evmxChain);
  await withdrawFunds(appGateway, arbChain, evmxChain);
}
