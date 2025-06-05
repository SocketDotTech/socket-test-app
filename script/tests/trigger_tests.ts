import { parseAbi, type Address } from 'viem';
import { deployAppGateway, deployOnchain, sendTransaction } from '../utils/deployer.js';
import { depositFunds, withdrawFunds } from '../utils/fees-manager.js';
import { fetchForwarderAndOnchainAddress } from '../utils/helpers.js';
import { ContractAddresses, ChainConfig } from '../utils/types.js';
import { COLORS, CHAIN_IDS } from '../utils/constants.js';

// Trigger AppGateway from onchain tests
export async function runTriggerAppGatewayOnchainTests(
  addresses: ContractAddresses,
  evmxChain: ChainConfig,
  arbChain: ChainConfig,
  opChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Running all trigger the AppGateway from onchain tests functions...${COLORS.NC}`);

  if (!addresses.appGateway || !addresses.chain1Onchain || !addresses.chain2Onchain) {
    throw new Error('Required addresses not found');
  }

  const valueIncrease = BigInt(5);

  // 1. Increase on AppGateway from Arbitrum Sepolia
  console.log(`${COLORS.CYAN}Increase on AppGateway from Arbitrum Sepolia${COLORS.NC}`);

  const onchainAbi = parseAbi([
    'function increaseOnGateway(uint256) external'
  ]);

  await sendTransaction(
    addresses.chain1Onchain,
    'increaseOnGateway',
    [valueIncrease],
    arbChain,
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

  // 2. Update on Optimism Sepolia from AppGateway
  console.log(`${COLORS.CYAN}Update on Optimism Sepolia from AppGateway${COLORS.NC}`);

  await sendTransaction(
    addresses.appGateway,
    'updateOnchain',
    [CHAIN_IDS.OP_SEP],
    evmxChain,
    appGatewayAbi
  );

  // Wait and verify value on Optimism
  await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay

  const onchainReadAbi = parseAbi([
    'function value() external view returns (uint256)',
    'function propagateToAnother(uint32) external'
  ]);

  const valueOnOp = await opChain.client.readContract({
    address: addresses.chain2Onchain,
    abi: onchainReadAbi,
    functionName: 'value'
  }) as bigint;

  if (valueOnOp !== valueOnGateway) {
    throw new Error(`Got ${valueOnOp} but expected ${valueOnGateway}`);
  }

  // 3. Propagate update from Optimism Sepolia to Arbitrum Sepolia
  console.log(`${COLORS.CYAN}Propagate update to Optimism Sepolia to Arbitrum Sepolia from AppGateway${COLORS.NC}`);

  await sendTransaction(
    addresses.chain2Onchain,
    'propagateToAnother',
    [CHAIN_IDS.ARB_SEP],
    opChain,
    onchainReadAbi
  );

  // Wait and verify value on Arbitrum
  await new Promise(resolve => setTimeout(resolve, 10000)); // 10 second delay

  const valueOnArb = await arbChain.client.readContract({
    address: addresses.chain1Onchain,
    abi: onchainReadAbi,
    functionName: 'value'
  }) as bigint;

  if (valueOnArb !== valueOnOp) {
    throw new Error(`Got ${valueOnArb} but expected ${valueOnOp}`);
  }

  console.log(`${COLORS.GREEN}All trigger tests completed successfully!${COLORS.NC}`);
}

export async function executeTriggerTests(
  evmxChain: ChainConfig,
  arbChain: ChainConfig,
  opChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.GREEN}=== Running Trigger from onchain Tests ===${COLORS.NC}`);

  const addresses: ContractAddresses = {
    appGateway: await deployAppGateway('OnchainTriggerAppGateway', evmxChain)
  };

  await depositFunds(addresses.appGateway, arbChain, evmxChain);
  await deployOnchain(CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
  await deployOnchain(CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);

  const chain1Addresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', CHAIN_IDS.ARB_SEP, addresses.appGateway, evmxChain);
  addresses.chain1Forwarder = chain1Addresses.forwarder;
  addresses.chain1Onchain = chain1Addresses.onchain;

  const chain2Addresses = await fetchForwarderAndOnchainAddress('onchainToEVMx', CHAIN_IDS.OP_SEP, addresses.appGateway, evmxChain);
  addresses.chain2Forwarder = chain2Addresses.forwarder;
  addresses.chain2Onchain = chain2Addresses.onchain;

  await runTriggerAppGatewayOnchainTests(addresses, evmxChain, arbChain, opChain);
  await withdrawFunds(addresses.appGateway, arbChain, evmxChain);
}
