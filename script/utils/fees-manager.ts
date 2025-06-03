// fees/manager.ts
import { parseAbi, formatEther, type Address } from 'viem';
import { ChainConfig } from './types.js';
import { COLORS, AMOUNTS, CHAIN_IDS } from './constants.js';
import { sendTransaction } from './deployer.js';

// Check available fees
export async function checkAvailableFees(
  appGateway: Address,
  evmxChain: ChainConfig
): Promise<bigint> {
  const maxAttempts = 60;
  let attempt = 0;
  let availableFees = 0n;

  const abi = parseAbi([
    'function getAvailableCredits(address) external view returns (uint256)'
  ]);

  while (attempt < maxAttempts) {
    try {
      availableFees = await evmxChain.client.readContract({
        address: process.env.FEES_MANAGER as Address,
        abi,
        functionName: 'getAvailableCredits',
        args: [appGateway]
      }) as bigint;

      if (availableFees > 0n) {
        console.log(`Funds available: ${formatEther(availableFees)} Credits - ${availableFees} wei`);
        return availableFees;
      }
    } catch (error) {
      console.error(`${COLORS.RED}Error:${COLORS.NC} Failed to retrieve available fees.`);
      throw error;
    }

    // Progress bar logic
    const percent = Math.floor((attempt * 100) / maxAttempts);
    process.stdout.write(`\r${COLORS.YELLOW}Checking fees:${COLORS.NC} ${percent}%`);

    await new Promise(resolve => setTimeout(resolve, 1000));
    attempt++;
  }

  throw new Error('No funds available after 60 seconds.');
}

// Deposit funds
export async function depositFunds(
  appGateway: Address,
  arbChain: ChainConfig,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Depositing funds${COLORS.NC}`);
  // TODO: Check balance on FeesPlug and then EVMx
  // if not 100 credits : mint missing credits
  // if 100 or more transfer to new appgateway

  const erc20Abi = parseAbi([
    'function mint(address to, uint256 amount) external',
    'function approve(address spender, uint256 amount) external returns (bool)'
  ]);

  const feesPlugAbi = parseAbi([
    'function depositCreditAndNative(address token, address appGateway, uint256 amount) external'
  ]);

  const walletAddress = arbChain.walletClient.account?.address;
  if (!walletAddress) throw new Error('Wallet address not found');

  // Mint test USDC
  await sendTransaction(
    process.env.ARBITRUM_TEST_USDC as Address,
    'mint',
    [walletAddress, AMOUNTS.TEST_USDC],
    arbChain,
    erc20Abi
  );

  // Approve USDC for FeesPlug
  await sendTransaction(
    process.env.ARBITRUM_TEST_USDC as Address,
    'approve',
    [process.env.ARBITRUM_FEES_PLUG as Address, AMOUNTS.TEST_USDC],
    arbChain,
    erc20Abi
  );

  // Deposit funds
  await sendTransaction(
    process.env.ARBITRUM_FEES_PLUG as Address,
    'depositCreditAndNative',
    [process.env.ARBITRUM_TEST_USDC as Address, appGateway, AMOUNTS.TEST_USDC],
    arbChain,
    feesPlugAbi
  );

  await checkAvailableFees(appGateway, evmxChain);
}

// Withdraw funds
export async function withdrawFunds(
  appGateway: Address,
  arbChain: ChainConfig,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Withdrawing funds${COLORS.NC}`);

  let availableFees = await checkAvailableFees(appGateway, evmxChain);

  if (availableFees === 0n) {
    console.log('No available fees to withdraw.');
    return;
  }

  const abi = parseAbi([
    'function maxFees() external returns (uint256)',
    'function withdrawCredits(uint32 chainId, address token, uint256 amount, address to) external',
    'function transferCredits(address to_, uint256 amount_) external'
  ]);

  const maxFees = await evmxChain.client.readContract({
    address: appGateway,
    abi,
    functionName: 'maxFees',
  });
  console.log(`Max fees ${formatEther(maxFees)} Credits - ${maxFees} wei`);

  let amountToWithdraw = availableFees - AMOUNTS.DEPLOY_FEES;

  console.log(`Withdrawing ${formatEther(amountToWithdraw)} Credits - ${amountToWithdraw} wei`);

  if (amountToWithdraw > 0n) {
    await sendTransaction(
      appGateway,
      'withdrawCredits',
      [CHAIN_IDS.ARB_SEP, process.env.ARBITRUM_TEST_USDC, amountToWithdraw, arbChain.walletClient.account?.address],
      evmxChain,
      abi
    );
  } else {
    console.log('No funds available for withdrawal after gas cost estimation.');
  }

  // transfer the rest to the EOA
  availableFees = await checkAvailableFees(appGateway, evmxChain);

  await sendTransaction(
    appGateway,
    'transferCredits',
    [evmxChain.walletClient.account?.address, availableFees],
    evmxChain,
    abi
  );
}
