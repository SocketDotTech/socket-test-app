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
  console.log(`${COLORS.CYAN}Reading schedules from the contract:${COLORS.NC}`);
  const abi = parseAbi([
    'function schedulesInSeconds(uint256) external view returns (uint256)',
    'function triggerSchedules() external'
  ]);

  let maxSchedule = 0n;
  let numberOfSchedules = 0n;

  while (true) {
    try {
      const schedule = await evmxChain.client.readContract({
        address: appGateway,
        abi,
        functionName: 'schedulesInSeconds',
        args: [numberOfSchedules]
      });

      if (schedule === 0) break;

      console.log(`Schedule ${numberOfSchedules}: ${schedule} seconds`);
      numberOfSchedules++;

      if (schedule > maxSchedule) {
        maxSchedule = schedule;
      }
    } catch (error) {
      break;
    }
  }

  console.log(`${COLORS.CYAN}Triggering schedules...${COLORS.NC}`);
  await sendTransaction(
    appGateway,
    'triggerSchedules',
    [],
    evmxChain,
    abi
  );

  console.log(`${COLORS.CYAN}Fetching ScheduleResolved events...${COLORS.NC}`);

  await awaitEvents(numberOfSchedules, 'ScheduleResolved(uint256,uint256,uint256)', appGateway, evmxChain, Number(maxSchedule));

  const logs = await evmxChain.client.getLogs({
    address: appGateway,
    event: parseAbi(['event ScheduleResolved(uint256,uint256,uint256)'])[0],
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

      console.log(`${COLORS.GREEN}Schedule Resolved:${COLORS.NC}`);
      console.log(`  Index: ${index}`);
      console.log(`  Created at: ${creationTimestamp}`);
      console.log(`  Executed at: ${executionTimestamp}`);
    }
  });
}

export async function executeSchedulerTests(
  chains: Record<string, ChainConfig>,
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Scheduler Tests ===${COLORS.NC}`);

  const appGateway = await deployAppGateway('ScheduleAppGateway', chains.evmxChain);

  await depositFunds(appGateway, chains.arbMainnetChain, chains.evmxChain);
  await runSchedulerTests(appGateway, chains.evmxChain);
  await withdrawFunds(appGateway, chains.arbMainnetChain, chains.evmxChain);
}
